#!/bin/bash

# Set these environment variables
#DOCKER_USER // dockerhub credentials
#DOCKER_AUTH
#ORG // optional

set -e

ORG=${ORG:-hsldevcom}
DOCKER_IMAGE=pelias-data-container
WORKDIR=/mnt

#Threshold value for regression testing, as %
THRESHOLD=${THRESHOLD:-2}
#how often data is built (default every 7 days)
BUILD_INTERVAL=${BUILD_INTERVAL:-7}
#Substract one day, because first wait hours are computer before each build
BUILD_INTERVAL_SECONDS=$((($BUILD_INTERVAL - 1)*24*3600))
#start build at this time (GMT):
BUILD_TIME=${BUILD_TIME:-23:59:59}

cd $WORKDIR
export PELIAS_CONFIG=$WORKDIR/pelias.json

# param1: organization name
# param2: git project name
# param3: optional git commit id
# note: changes cd to new project dir
function install_node_project {
    cd $WORKDIR
    git clone --single-branch https://github.com/$1/$2
    cd $2
    if [ -n "$3" ]; then
        git checkout $3
    fi
    npm install

    #make the package locally available
    npm link
}

apk update && apk add nodejs

# Install test tools
install_node_project HSLdevcom fuzzy-tester
install_node_project HSLdevcom pelias-fuzzy-tests
npm link pelias-fuzzy-tester

cd $WORKDIR

set +e

function build {
    set -e
    #make sure latest base  image is used
    docker pull $ORG/pelias-data-container-base:latest

    DOCKER_TAGGED_IMAGE=$1
    echo "Building $DOCKER_TAGGED_IMAGE"
    docker build -t="$DOCKER_TAGGED_IMAGE" -f Dockerfile.loader .
}

function deploy {
    set -e
    DOCKER_TAGGED_IMAGE=$1
    docker login -u $DOCKER_USER -p $DOCKER_AUTH
    docker push $DOCKER_TAGGED_IMAGE
    docker tag $DOCKER_TAGGED_IMAGE $ORG/$DOCKER_IMAGE:latest
    docker push $ORG/$DOCKER_IMAGE:latest
    docker tag $DOCKER_TAGGED_IMAGE $ORG/$DOCKER_IMAGE:prod
    #docker push $ORG/$DOCKER_IMAGE:prod
}

function shutdown {
    echo "Shutting down the test services..."
    docker stop pelias-data-container
    docker stop pelias-api
    echo shutting down
}

function test_container {
    set -e
    DOCKER_TAGGED_IMAGE=$1
    echo -e "\n##### Testing $DOCKER_TAGGED_IMAGE #####\n"

    docker run --name pelias-data-container --rm $DOCKER_TAGGED_IMAGE &
    docker pull $ORG/pelias-api:prod
    sleep 30
    docker run --name pelias-api -p 3100:8080 --link pelias-data-container:pelias-data-container --rm $ORG/pelias-api:prod &
    sleep 30

    MAX_WAIT=3
    ITERATIONS=$(($MAX_WAIT * 6))
    echo "Waiting service for max $MAX_WAIT minutes..."

    set +e

    #find api's current IP
    HOST=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' pelias-api)
    ENDPOINT='    "endpoints": { "local": "http://'$HOST':8080/v1/" }'
    sed -i "/endpoints/c $ENDPOINT" $PELIAS_CONFIG

    RESULT=1

    for (( c=1; c<=$ITERATIONS; c++ ));do
        STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$HOST:8080/v1)

        if [ $STATUS_CODE = 200 ]; then
            echo "Pelias API started"
            cd $WORKDIR/pelias-fuzzy-tests

            # run tests with a given  % regression threshold
            ./run_tests.sh local $THRESHOLD
            RESULT=$?

            if [ $RESULT -ne 0 ]; then
                echo "ERROR: Tests did not pass"
            else
                echo -e "\nTests passed\n"
            fi
            break
        else
            echo "waiting for service ..."
            sleep 10
        fi
    done

    shutdown

    return $RESULT
}

echo "Launching geocoding data builder service" | tee log.txt

#build errors should not stop the continuous build loop
set +e

# run data build loop forever
while true; do
    SLEEP=$(($(date -u -d $BUILD_TIME +%s) - $(date -u +%s) + 1))
    if [[ "$SLEEP" -le 0 ]]; then
        #today's build time is gone, start counting from tomorrow
        SLEEP=$(($SLEEP + 24*3600))
    fi
    SLEEP=$(($SLEEP + $BUILD_INTERVAL_SECONDS))

    echo "Sleeping $SLEEP seconds until the next build ..."
    sleep $SLEEP

    DOCKER_TAG=$(date +%s)
    DOCKER_TAGGED_IMAGE=$ORG/$DOCKER_IMAGE:$DOCKER_TAG

    # rotate log
    mv log.txt _log.txt

    SUCCESS=0
    echo "Building new container..."
    ( build $DOCKER_TAGGED_IMAGE 2>&1 |tee log.txt )
    if [ $? -eq 0 ]; then
        echo "New container built. Testing next... "
        ( test_container $DOCKER_TAGGED_IMAGE 2>&1 | tee -a log.txt )
        RESULT=$?

        if [ $RESULT -eq 0 ]; then
            echo "Container passed tests. Deploying ..."
            ( deploy $DOCKER_TAGGED_IMAGE 2>&1 | tee -a log.txt )
            if [ $? -eq 0 ]; then
                echo "Container deployed"
                SUCCESS=1
            else
                echo "Deployment failed"
            fi
        else
            echo "Test failed"
        fi
    fi

    if [ $SUCCESS -eq 0 ]; then
        echo "ERROR: Build failed"
        #extract log end which most likely contains info about failure
        { echo -e "Geocoding data build failed:\n..."; tail -n 20 log.txt; } | jq -R -s '{text: .}' | curl -X POST -H 'Content-type: application/json' -d@- \
              $SLACK_WEBHOOK_URL
    else
        echo "Build for $DOCKER_TAGGED_IMAGE finished successfully"
    fi
done
