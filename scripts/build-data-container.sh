#!/bin/bash

# Set these environment variables
#DOCKER_USER // dockerhub credentials. If unset, will not deploy
#DOCKER_AUTH
#ORG // optional

set -e

ORG=${ORG:-hsldevcom}
DOCKER_IMAGE=pelias-data-container
WORKDIR=/mnt

BUILDER_TYPE=${BUILDER_TYPE:-dev}

#which tag is used for pushing images
if  [ "$BUILDER_TYPE" = prod ]; then
    DOCKER_TAG=prod
else
    DOCKER_TAG=latest
fi

API_IMAGE=$ORG/pelias-api:$DOCKER_TAG
DATA_CONTAINER_IMAGE=$ORG/$DOCKER_IMAGE:$DOCKER_TAG
BASE_IMAGE=$ORG/pelias-data-container-base:$DOCKER_TAG

#Threshold value for regression testing, as %
THRESHOLD=${THRESHOLD:-2}
#how often data is built (default once a day)
BUILD_INTERVAL=${BUILD_INTERVAL:-1}
#Substract one day, because first wait hours are computed before each build
BUILD_INTERVAL_SECONDS=$((($BUILD_INTERVAL - 1)*24*3600))
#start build at this time (GMT):
BUILD_TIME=${BUILD_TIME:-23:00:00}

cd $WORKDIR
export PELIAS_CONFIG=$WORKDIR/pelias.json

set +e

function build {
    set -e
    echo 1 >/tmp/build_ok
    #make sure latest base  image is used
    docker pull $BASE_IMAGE

    BUILD_IMAGE=$1
    echo "Building $BUILD_IMAGE"
    docker build --no-cache --build-arg BUILDER_TYPE --build-arg MMLAPIKEY --build-arg GTFS_AUTH --build-arg OSM_VENUE_FILTERS --build-arg OSM_ADDRESS_FILTERS --build-arg DOCKER_TAG=$DOCKER_TAG -t="$BUILD_IMAGE" -f Dockerfile.loader .
    echo 0 >/tmp/build_ok
}

function deploy {
    set -e
    echo 1 >/tmp/deploy_ok
    BUILD_IMAGE=$1
    docker login -u $DOCKER_USER -p $DOCKER_AUTH
    docker push $BUILD_IMAGE

    echo "Deploying image"
    docker tag $BUILD_IMAGE $DATA_CONTAINER_IMAGE
    docker push $DATA_CONTAINER_IMAGE

    docker rmi $DATA_CONTAINER_IMAGE
    echo 0 >/tmp/deploy_ok
}

function test_container {
    set -e

    #assume failure until success is realized.
    TESTS_PASSED=1
    echo 1 >/tmp/tests_passed

    BUILD_IMAGE=$1
    echo -e "\n##### Testing $BUILD_IMAGE #####\n"

    DATACONT=pelias-test-"$BUILDER_TYPE"-data-container
    API=pelias-test-"$BUILDER_TYPE"-api
    docker run --name $DATACONT --rm $BUILD_IMAGE &
    docker pull $API_IMAGE
    sleep 60
    docker run --name $API -p 3100:8080 --link $DATACONT:pelias-data-container --rm $API_IMAGE &
    sleep 60

    MAX_WAIT=2
    ITERATIONS=$(($MAX_WAIT * 3))
    echo "Waiting service for max $MAX_WAIT minutes..."

    set +e

    #find api's current IP
    HOST=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' $API)
    ENDPOINT='    "endpoints": { "local": "http://'$HOST':8080/v1/" }'
    sed -i "/endpoints/c $ENDPOINT" $PELIAS_CONFIG

    # run the full fuzzy testbench
    for (( c=1; c<=$ITERATIONS; c++ ));do
        STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$HOST:8080/v1)

        if [ $STATUS_CODE = 200 ]; then
            echo "Pelias API started"
            cd $WORKDIR/pelias-fuzzy-tests

            # run tests with a given  % regression threshold
            SILENT_TEST_LOG=1 ./run_tests.sh local $THRESHOLD
            TESTS_PASSED=$?

            if [ $TESTS_PASSED -ne 0 ]; then
                echo -e "\nERROR: Fuzzy tests did not pass"
            else
                echo -e "\nFuzzy tests passed\n"
            fi
            break
        else
            echo "waiting for service ..."
            sleep 20
        fi
    done

    echo "Test reverse geocoding"
    STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$HOST:8080/v1/reverse?point.lat=60.212358&point.lon=24.981812")
    if [ $STATUS_CODE = 200 ]; then
        echo "Reverse geocoding OK"
    else
        TESTS_PASSED=1
        echo "Reverse geocoding failed"
    fi

    echo "Test autocomplete"
    STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$HOST:8080/v1/autocomplete?text=helsi")
    if [ $STATUS_CODE = 200 ]; then
        echo "Autocomplete OK"
    else
        TESTS_PASSED=1
        echo "Autocomplete failed"
    fi

    echo "Test place endpoint"
    STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$HOST:8080/v1/place?ids=openstreetmap%3Avenue%3Anode%3A5995720648")
    if [ $STATUS_CODE = 200 ]; then
        echo "Place endpoint OK"
    else
        TESTS_PASSED=1
        echo "Place endpoint failed"
    fi

    if [ $TESTS_PASSED = 0 ]; then
        echo 0 >/tmp/tests_passed #success!
    fi

    echo "Shutting down the test services..."
    docker stop $API
    docker stop $DATACONT
    docker rmi $API_IMAGE > /dev/null 2>&1
    return $TESTS_PASSED
}

echo "Launching geocoding data builder service" | tee log.txt

#build errors should not stop the continuous build loop
set +e

# run data build loop forever, unless build interval is set to zero
while true; do
    if [[ "$BUILD_INTERVAL" -gt 0 ]]; then
        SLEEP=$(($(date -u -d $BUILD_TIME +%s) - $(date -u +%s) + 1))
        if [[ "$SLEEP" -le 0 ]]; then
            #today's build time is gone, start counting from tomorrow
            SLEEP=$(($SLEEP + 24*3600))
        fi
        SLEEP=$(($SLEEP + $BUILD_INTERVAL_SECONDS))

        echo "Sleeping $SLEEP seconds until the next build ..."
        sleep $SLEEP
    fi

    BUILD_TAG=$DOCKER_TAG-$(date +"%Y-%m-%dT%H.%M.%S")
    BUILD_IMAGE=$ORG/$DOCKER_IMAGE:$BUILD_TAG

    # rotate log
    mv log.txt _log.txt

    SUCCESS=0
    echo "Building new container..."
    if [ -v SLACK_WEBHOOK_URL ]; then
        curl -X POST -H 'Content-type: application/json' \
             --data '{"username":"Pelias data builder '$BUILDER_TYPE'","text":"Geocoding data build started\n"}' $SLACK_WEBHOOK_URL
    fi

    ( build $BUILD_IMAGE 2>&1 | tee log.txt )
    read BUILD_OK </tmp/build_ok

    if [ $BUILD_OK = 0 ]; then
        echo "New container built. Testing next... "
        ( test_container $BUILD_IMAGE 2>&1 | tee -a log.txt )
        read TESTS_PASSED </tmp/tests_passed #get test return val

        if [ $TESTS_PASSED = 0 ]; then
            echo "Container passed tests"
            if [[ -v DOCKER_USER && -v DOCKER_AUTH ]]; then
                echo "Deploying ..."

                ( deploy $BUILD_IMAGE 2>&1 | tee -a log.txt )
                read DEPLOY_OK </tmp/deploy_ok

                if [ $DEPLOY_OK = 0 ]; then
                    echo "Container deployed"
                    SUCCESS=1
                else
                    echo "Deployment failed"
                fi
            else
                SUCCESS=1
            fi
        else
            echo "Test failed"
        fi
    fi

    docker rmi $BUILD_IMAGE
    docker rmi $BASE_IMAGE

    if [ $SUCCESS = 0 ]; then
        echo "ERROR: Build failed"
        if [ -v SLACK_WEBHOOK_URL ]; then
            #extract log end which most likely contains info about failure
            { echo -e "Geocoding data build failed :boom: \n..."; tail -n 20 log.txt; } | jq -R -s '{"username":"Pelias data builder '$BUILDER_TYPE'",text: .}' | \
                curl -X POST -H 'Content-type: application/json' -d@- $SLACK_WEBHOOK_URL
        fi
    else
        echo "Build finished successfully"
        if [ -v SLACK_WEBHOOK_URL ]; then
            curl -X POST -H 'Content-type: application/json' \
                 --data '{"username":"Pelias data builder '$BUILDER_TYPE'","text":"Geocoding data build finished\n"}' $SLACK_WEBHOOK_URL
        fi
    fi

    if [[ "$BUILD_INTERVAL" -le 0 ]]; then
        #run only once
        if [ $SUCCESS = 1 ]; then
            exit 0
        else
            exit 1
        fi
    fi
done
