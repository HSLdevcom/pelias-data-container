#!/bin/bash

# Set these environment variables
#DOCKER_USER // dockerhub credentials
#DOCKER_AUTH
#DOCKER_TAG // build id
#ORG // optional

set -e

ORG=${ORG:-hsldevcom}
DOCKER_IMAGE=pelias-data-container-builder
DOCKER_TAG=${DOCKER_TAG:-$TRAVIS_BUILD_ID}
DOCKER_TAGGED_IMAGE=$ORG/$DOCKER_IMAGE:$DOCKER_TAG

# Build image
docker build -t="$DOCKER_TAGGED_IMAGE" -f Dockerfile.builder .

docker login -u $DOCKER_USER -p $DOCKER_AUTH
docker push $ORG/$DOCKER_IMAGE:$DOCKER_TAG
docker tag $ORG/$DOCKER_IMAGE:$DOCKER_TAG $ORG/$DOCKER_IMAGE:latest
docker push $ORG/$DOCKER_IMAGE:latest

echo "$DOCKER_IMAGE built and deployed"
