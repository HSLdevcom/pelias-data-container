'# pelias-data-container

[![Build](https://api.travis-ci.org/HSLdevcom/pelias-data-container.svg?branch=master)](https://travis-ci.org/HSLdevcom/pelias-data-container)

Geocoding data build tools

## Travis build

Creates and pushes to dockerhub/hsldevcom two docker containers:

- pelias-data-container-base
- pelias-data-container-builder

pelias-data-container-base is the base image for the running geocoding data service. It is based on Elasticsearch and also
contains all tools for loading and adding address data into the ES index.

pelias-data-container-builder is the data builder application, which builds the final geocoding data container using the base image.
It tests built containers thoroughly using hsldevcom/pelias-fuzzy-tests project and a defined regression threshold (currently 2%).
If the tests pass, the new container is deployed to dockerhub.


## Data builder application

Data builder obeys the following environment variables, which can pe passed to the container using docker run -e option:

 * DOCKER_USER - mandatory dockerhub credentials for image deployment
 * DOCKER_AUTH
 * ORG - optional, default 'hsldevcom'
 * BUILD_INTERVAL - optional, as days, defaults to 7
 * THRESHOLD - optional regression limit, as %, defaults to 2%
 * PROD_DEPLOY - optional switch to prevent production deployment, default = 1 (deploys to prod)

Data builder needs an access to host environment's docker service. The following example call to launch the builder container
shows how to accomplish this:

```bash
docker run -v /var/run/docker.sock:/var/run/docker.sock -e DOCKER_USER=hsldevcom -e DOCKER_AUTH=<secret> hsldevcom/pelias-data-container-builder
```


## Usage in a local system

Builder app can be run locally to get the data-container image:

```bash
#leave dockerhub credentials unset to skip deployment
#runs immediately and once if BUILD_INTERVAL=0
docker run -v /var/run/docker.sock:/var/run/docker.sock -e BUILD_INTERVAL=0 hsldevcom/pelias-data-container-builder
```

Another alternative is to install required components locally:
- Git projects for pelias dataloading (NLSFI, OpenAddresses, OSM, GTFS, etc.)
- pelias/schema git project
- WOF admin data and street polylines, both available as a part of this git project
- Properly configured pelias.json config file
- Install and start ElasticSearch
- Export three env. vars, DATA for a data folder path, SCRIPTS for data container scripts of this project
and TOOLS path to the parent dir of dataloading and schema tools
- Run the script scripts/dl-and-index.sh


## Data deployments

Pelias api updates are sometimes backward incompatible with old data containers.
Builder application handles breaking changes by testing the data with development api version,
and by running a single compatibility ensuring test with the production api version.
Based on these tests, builder deploys selectively to dev and prod. Furthermore,
setting an environment variable PROD_DEPLOY=0 prevents production deployments regardless of the tests.
This can be useful when the current api and the new container are compatible, but perform poorly together.
Using the switch, data can be let automatically build into dev and later be updated by
manually tagging a properly compatible api and the new data container into production simultaneously.
