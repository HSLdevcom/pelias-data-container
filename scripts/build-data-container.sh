#!/bin/bash

# Set these environment variables
#DOCKER_USER // dockerhub credentials
#DOCKER_AUTH

set -e
set -x

ORG=${ORG:-hsldevcom}
DOCKER_IMAGE=pelias-data-container
DOCKER_TAG=$(date +%s)
DOCKER_TAGGED_IMAGE=$ORG/$DOCKER_IMAGE:$DOCKER_TAG
TEST_PORT=3101
WORKDIR=/mnt

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

apt-get update
echo 'APT::Acquire::Retries "20";' >> /etc/apt/apt.conf
apt-get install -y --no-install-recommends git
rm -rf /var/lib/apt/lists/*

curl -sL https://deb.nodesource.com/setup_4.x | bash -
apt-get install -y --no-install-recommends nodejs

# Install test tools
install_node_project HSLdevcom fuzzy-tester
install_node_project HSLdevcom pelias-fuzzy-tests
npm link pelias-fuzzy-tester

cd $WORKDIR

# Build image
docker build -t="$DOCKER_TAGGED_IMAGE" -f Dockerfile.loader

function deploy() {
    docker login -u $DOCKER_USER -p $DOCKER_AUTH
    docker push $ORG/$DOCKER_IMAGE:$DOCKER_TAG
    docker tag -f $ORG/$DOCKER_IMAGE:$DOCKER_TAG $ORG/$DOCKER_IMAGE:latest
    docker push $ORG/$DOCKER_IMAGE:latest
    docker tag -f $ORG/$DOCKER_IMAGE:$DOCKER_TAG $ORG/$DOCKER_IMAGE:prod
    docker push $ORG/$DOCKER_IMAGE:prod
}

function shutdown() {
    docker stop pelias-data
    docker stop pelias-api
    docker rm pelias-data
    docker rm pelias-api
    echo shutting down
}


# Test
echo -e "\n##### Testing $DOCKER_TAGGED_IMAGE #####\n"

docker run --name pelias-data $DOCKER_TAGGED_IMAGE &
sleep 30
docker run --name pelias-api -p $TEST_PORT:3100 --link pelias-data:pelias-data $ORG/pelias-api:prod &

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
            echo "ERROR: Tests did not pass, aborting the build"
            shutdown
            exit 1
        else
            echo -e "\nTests passed\n"
            shutdown
            deploy
            exit 0
        fi
    else
        echo "waiting for service ..."
        sleep 10
    fi
done
shutdown

exit 1

