#!/bin/bash

# Set these environment variables
#DOCKER_USER // dockerhub credentials. If unset, will not deploy
#DOCKER_AUTH
#ORG // optional

set -e

# Waits for basic outbound DNS/network connectivity to become available,
# polling a canary host a bounded number of times. This works around a
# transient DNS failure seen on AKS: the nested dockerd (docker:dind) rewrites
# iptables rules on startup, which can race with the pod's CNI-managed DNS
# routing. See HSLdevcom/OpenTripPlanner-data-container's waitForNetwork.
CANARY_HOST=${CANARY_HOST:-slack.com}
MAX_NETWORK_ATTEMPTS=12
NETWORK_RETRY_DELAY=5

function wait_for_network {
    local attempt=1
    while [ $attempt -le $MAX_NETWORK_ATTEMPTS ]; do
        if node -e "require('dns').lookup('$CANARY_HOST', err => process.exit(err ? 1 : 0))"; then
            return 0
        fi
        echo "Network not ready yet (attempt $attempt/$MAX_NETWORK_ATTEMPTS)"
        attempt=$((attempt + 1))
        if [ $attempt -le $MAX_NETWORK_ATTEMPTS ]; then
            sleep $NETWORK_RETRY_DELAY
        fi
    done
    echo "ERROR: Network did not become ready in time. Exiting so Kubernetes can restart the pod."
    exit 1
}

wait_for_network

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

cd $WORKDIR
export PELIAS_CONFIG=$WORKDIR/pelias.json

set +e

# Polls a readiness check command instead of a fixed sleep, so callers
# proceed as soon as a container is ready and only wait the full timeout
# when something is actually wrong.
# param1: container name, only used for log output
# param2: max attempts
# param3: delay between attempts, in seconds
# param4: shell command string to run; success (exit 0) means "ready"
function wait_for_container_cmd {
    local name=$1
    local max_attempts=$2
    local delay=$3
    local check_cmd=$4
    local attempt=1

    until eval "$check_cmd" >/dev/null 2>&1; do
        if [ $attempt -ge $max_attempts ]; then
            echo "WARNING: $name did not become ready in time, continuing anyway"
            docker logs $name
            return 0
        fi
        echo "Waiting for $name to start (attempt $attempt/$max_attempts)..."
        attempt=$((attempt + 1))
        sleep $delay
    done
    echo "$name is up"
}

function build {
    set -e
    echo 1 >/tmp/build_ok
    #make sure latest base  image is used
    docker pull $BASE_IMAGE

    BUILD_IMAGE=$1
    echo "Building $BUILD_IMAGE"
    docker build --no-cache --build-arg BUILDER_TYPE --build-arg API_SUBSCRIPTION_QUERY_PARAMETER_NAME --build-arg API_SUBSCRIPTION_TOKEN --build-arg MMLAPIKEY --build-arg OSM_VENUE_FILTERS --build-arg OSM_ADDRESS_FILTERS --build-arg EXTRA_SRC --build-arg DOCKER_TAG=$DOCKER_TAG -t="$BUILD_IMAGE" -f Dockerfile.loader .
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

    # Ensure both test containers are always stopped, even if this function
    # aborts early (e.g. a failing command under 'set -e'), so failed runs
    # don't leak running containers.
    trap 'docker stop $DATACONT $API >/dev/null 2>&1' EXIT

    docker run --name $DATACONT --rm $BUILD_IMAGE &
    docker pull $API_IMAGE

    # Poll instead of a fixed sleep: wait for the data container's
    # Elasticsearch to answer before starting the API container, which
    # depends on it (via --link) and may not recover if ES isn't up yet.
    wait_for_container_cmd "$DATACONT" 30 5 "docker exec $DATACONT curl -sS -o /dev/null localhost:9200"

    docker run --name $API -p 3100:8080 --link $DATACONT:pelias-data-container --rm $API_IMAGE &

    # Wait for the API container process itself to be up; its HTTP endpoint
    # readiness is polled separately below.
    wait_for_container_cmd "$API" 30 2 "[ \"\$(docker inspect --format '{{.State.Running}}' $API 2>/dev/null)\" = true ]"

    MAX_WAIT=2
    ITERATIONS=$(($MAX_WAIT * 3))
    echo "Waiting service for max $MAX_WAIT minutes..."

    set +e

    #find api's current IP
    # note: newer Docker versions removed the legacy top-level
    # .NetworkSettings.IPAddress field; the IP now only lives under
    # .NetworkSettings.Networks.<network-name>. Ranging over Networks
    # works regardless of which network name is in use.
    HOST=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $API)
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

    if [ $TESTS_PASSED = 0 ]; then
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

set +e

BUILD_TAG=$DOCKER_TAG-$(date +"%Y-%m-%dT%H.%M.%S")
BUILD_IMAGE=$ORG/$DOCKER_IMAGE:$BUILD_TAG

SUCCESS=0
echo "Building new container..."

if [ -n "${SLACK_CHANNEL_ID}" ]; then
    MSG='{"channel": "'$SLACK_CHANNEL_ID'","text":"Geocoding data build started", "username": "Pelias data builder '$BUILDER_TYPE'"}'
    TIMESTAMP=$(curl -X POST -H 'Content-Type: application/json' -H "Authorization: Bearer $SLACK_ACCESS_TOKEN" -H 'Accept: */*' \
	  -d "$MSG" 'https://slack.com/api/chat.postMessage' | jq -r .ts)
fi

( build $BUILD_IMAGE 2>&1 | tee log.txt )
read BUILD_OK </tmp/build_ok

if [ $BUILD_OK = 0 ]; then
    echo "New container built. Testing next... "
    ( test_container $BUILD_IMAGE 2>&1 | tee -a log.txt )
    read TESTS_PASSED </tmp/tests_passed #get test return val

    if [ $TESTS_PASSED = 0 ]; then
        echo "Container passed tests"
        if [ -n "$DOCKER_USER" ] && [ -n "$DOCKER_AUTH" ]; then
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
    if [ -n "${SLACK_CHANNEL_ID}" ]; then
        #extract log end which most likely contains info about failure
	MSG=$({ echo -e "Dataloading log: \n"; tail -n 10 log.txt; } | jq -R -s '{"channel": "'$SLACK_CHANNEL_ID'", "username": "Pelias data builder '$BUILDER_TYPE'", "thread_ts": "'$TIMESTAMP'", "text": .}')
	curl -X POST -H 'Content-Type: application/json' -H "Authorization: Bearer $SLACK_ACCESS_TOKEN" -H 'Accept: */*' -d "$MSG" 'https://slack.com/api/chat.postMessage'

	FINISH_TIME=$(TZ='Europe/Helsinki' date +"%H:%M:%S %Z")
	MSG='{"channel": "'$SLACK_CHANNEL_ID'","text": "('$FINISH_TIME') :boom: Geocoding data build failed", "username": "Pelias data builder '$BUILDER_TYPE'", "ts": "'$TIMESTAMP'"}'
	curl -X POST -H 'Content-Type: application/json' -H "Authorization: Bearer $SLACK_ACCESS_TOKEN" -H 'Accept: */*' -d "$MSG" 'https://slack.com/api/chat.update'
	fi
else
    echo "Build finished successfully"
    if [ -n "${SLACK_CHANNEL_ID}" ]; then
	FINISH_TIME=$(TZ='Europe/Helsinki' date +"%H:%M:%S %Z")
	MSG='{"channel": "'$SLACK_CHANNEL_ID'","text": "('$FINISH_TIME') :white_check_mark: Geocoding data build finished", "username": "Pelias data builder '$BUILDER_TYPE'", "ts": "'$TIMESTAMP'"}';
	curl -X POST -H 'Content-Type: application/json' -H "Authorization: Bearer $SLACK_ACCESS_TOKEN" -H 'Accept: */*' -d "$MSG" 'https://slack.com/api/chat.update'
    fi
fi

if [ $SUCCESS = 1 ]; then
    exit 0
else
    exit 1
fi
