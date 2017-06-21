#!/bin/bash

# Set these environment variables
#DOCKER_USER // dockerhub credentials
#DOCKER_AUTH
#ORG // optional

set -e
set -x

ORG=${ORG:-hsldevcom}
BUILD_INTERVAL=${BUILD_INTERVAL:-7}
DOCKER_IMAGE=pelias-data-container
TEST_PORT=3101
WORKDIR=/mnt

#to seconds
BUILD_INTERVAL=$(echo "$BUILD_INTERVAL*24*3600" | bc -l)

cd $WORKDIR

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


function build() {
    DOCKER_TAGGED_IMAGE=$1
    echo "Building $DOCKER_TAGGED_IMAGE"
    docker build -t="$DOCKER_TAGGED_IMAGE" -f Dockerfile.loader .
}

function deploy() {
    DOCKER_TAGGED_IMAGE=$1
    docker login -u $DOCKER_USER -p $DOCKER_AUTH
    docker push $DOCKER_TAGGED_IMAGE
    docker tag -f $DOCKER_TAGGED_IMAGE $ORG/$DOCKER_IMAGE:latest
    docker push $ORG/$DOCKER_IMAGE:latest
    docker tag -f $DOCKER_TAGGED_IMAGE $ORG/$DOCKER_IMAGE:prod
    docker push $ORG/$DOCKER_IMAGE:prod
}

function shutdown() {
    docker stop pelias-data
    docker stop pelias-api
    docker rm pelias-data
    docker rm pelias-api
    echo shutting down
}

function test() {
    DOCKER_TAGGED_IMAGE=$1
    echo -e "\n##### Testing $DOCKER_TAGGED_IMAGE #####\n"

    docker run --name pelias-data $DOCKER_TAGGED_IMAGE &
    docker pull $ORG/pelias-api:prod
    sleep 30
    docker run --name pelias-api -p $TEST_PORT:8080 --link pelias-data:pelias-data $ORG/pelias-api:prod &
    sleep 60

    MAX_WAIT=3
    ITERATIONS=$(($MAX_WAIT * 6))
    echo "max wait (minutes): $MAX_WAIT"

    for (( c=1; c<=$ITERATIONS; c++ ));do
        STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$TEST_PORT/v1/search?text=helsinki)

        if [ $STATUS_CODE = 200 ]; then
            echo "Pelias API started"
            cd $WORKDIR/tests
            set +e
            # run tests with 5% regression threshold
            export PELIAS_CONFIG=$WORKDIR/pelias.json
            ./run_tests.sh local 5
            RESULT=$?
            set -e
            if [ $RESULT -ne 0 ]; then
                echo "ERROR: Tests did not pass"
                return 1
            else
                echo -e "\nTests passed\n"
                deploy
                return 0
            fi
        else
            echo "waiting for service ..."
            sleep 10
        fi
    done

    return 1
}

# run data build loop forever
while true; do
    DOCKER_TAG=$(date +%s)
    DOCKER_TAGGED_IMAGE=$ORG/$DOCKER_IMAGE:$DOCKER_TAG

    build $DOCKER_TAGGED_IMAGE
    test $DOCKER_TAGGED_IMAGE
    shutdown

    if [ $? -eq 0 ]; then
        deploy $DOCKER_TAGGED_IMAGE
    fi

    sleep $BUILD_INTERVAL
done

