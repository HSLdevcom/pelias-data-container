#!/bin/bash
set -e

COMMIT_HASH=$(git rev-parse --short "$GITHUB_SHA")
ORG=hsldevcom

function imagedeploy {
    DOCKER_IMAGE=$ORG/$1
    DOCKER_TAG=${DOCKER_BASE_TAG:-latest}

    COMMIT_HASH=$(git rev-parse --short "$GITHUB_SHA")

    DOCKER_TAG_LONG=$DOCKER_TAG-$(date +"%Y-%m-%dT%H.%M.%S")-$COMMIT_HASH
    DOCKER_IMAGE_TAG=$DOCKER_IMAGE:$DOCKER_TAG
    DOCKER_IMAGE_TAG_LONG=$DOCKER_IMAGE:$DOCKER_TAG_LONG

    # Build image
    echo "Building $1"
    docker build --tag=$DOCKER_IMAGE_TAG_LONG -f Dockerfile.$1 .

    echo "Pushing $DOCKER_TAG image"
    docker push $DOCKER_IMAGE_TAG_LONG
    docker tag $DOCKER_IMAGE_TAG_LONG $DOCKER_IMAGE_TAG
    docker push $DOCKER_IMAGE_TAG
}

docker login -u $DOCKER_USER -p $DOCKER_AUTH

imagedeploy "pelias-data-container-base"
imagedeploy "pelias-data-container-builder"

echo Build completed
