#!/bin/bash

# Set these environment variables
#DOCKER_USER // dockerhub credentials
#DOCKER_AUTH
#ORG // optional

set -e

ORG=${ORG:-hsldevcom}
DOCKER_IMAGE=pelias-data-container-base
BUILD_TAG=$TRAVIS_BUILD_ID
DOCKER_TAGGED_IMAGE=$ORG/$DOCKER_IMAGE:$BUILD_TAG

# Build image
docker build -t="$DOCKER_TAGGED_IMAGE" -f Dockerfile.base .

if [ "${TRAVIS_PULL_REQUEST}" == "false" ]; then
    docker login -u $DOCKER_USER -p $DOCKER_AUTH
    docker push $ORG/$DOCKER_IMAGE:$BUILD_TAG
    docker tag $ORG/$DOCKER_IMAGE:$BUILD_TAG $ORG/$DOCKER_IMAGE:latest
    docker push $ORG/$DOCKER_IMAGE:latest
fi

echo "$DOCKER_IMAGE built and deployed"
