#!/bin/bash

# Set these environment variables
#DOCKER_USER // dockerhub credentials
#DOCKER_AUTH
#ORG // optional

set -e

ORG=${ORG:-hsldevcom}
DOCKER_IMAGE=$ORG/pelias-data-container-base
DOCKER_TAG="latest"

if [ "$TRAVIS_TAG" ]; then
  DOCKER_TAG="prod"
elif [ "$TRAVIS_BRANCH" != "master" ]; then
  DOCKER_TAG=$TRAVIS_BRANCH
fi

DOCKER_TAG_LONG=$DOCKER_TAG-$(date +"%Y-%m-%dT%H.%M.%S")-${TRAVIS_COMMIT:0:7}
DOCKER_IMAGE_LATEST=$DOCKER_IMAGE:latest
DOCKER_IMAGE_TAG=$DOCKER_IMAGE:$DOCKER_TAG
DOCKER_IMAGE_TAG_LONG=$DOCKER_IMAGE:$DOCKER_TAG_LONG

docker login -u $DOCKER_USER -p $DOCKER_AUTH

if [ -z $TRAVIS_TAG ]; then
  # Build image
  docker build --tag="$DOCKER_IMAGE_TAG_LONG" -f Dockerfile.base .
fi

if [ "${TRAVIS_PULL_REQUEST}" == "false" ]; then
  if [ "$TRAVIS_TAG" ];then
    echo "processing release $TRAVIS_TAG"
    docker pull $DOCKER_IMAGE_LATEST
    docker tag $DOCKER_IMAGE_LATEST $DOCKER_IMAGE_TAG
    docker tag $DOCKER_IMAGE_LATEST $DOCKER_IMAGE_TAG_LONG
    docker push $DOCKER_IMAGE_TAG
    docker push $DOCKER_IMAGE_TAG_LONG
  else
    echo "Pushing $DOCKER_TAG image"
    docker push $DOCKER_IMAGE_TAG_LONG
    docker tag $DOCKER_IMAGE_TAG_LONG $DOCKER_IMAGE_TAG
    docker push $DOCKER_IMAGE_TAG
  fi
fi

echo Build completed
