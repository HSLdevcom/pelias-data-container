#!/bin/bash

# Set these environment variables
#DOCKER_USER // dockerhub credentials
#DOCKER_AUTH
#DOCKER_TAG // build id
#ORG // optional

set -e

ORG=${ORG:-hsldevcom}
DOCKER_IMAGE=pelias-data-container-base
DOCKER_TAG=${DOCKER_TAG:-$TRAVIS_BUILD_ID}
DOCKER_TAGGED_IMAGE=$ORG/$DOCKER_IMAGE:$DOCKER_TAG

# Build image
docker build -t="$DOCKER_TAGGED_IMAGE" -f Dockerfile.base

docker login -u $DOCKER_USER -p $DOCKER_AUTH
docker push $ORG/$DOCKER_IMAGE:$DOCKER_TAG
docker tag -f $ORG/$DOCKER_IMAGE:$DOCKER_TAG $ORG/$DOCKER_IMAGE:latest
docker push $ORG/$DOCKER_IMAGE:latest

echo "$DOCKER_IMAGE built and deployed"
