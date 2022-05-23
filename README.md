# pelias-data-container

[![Build](https://github.com/hsldevcom/pelias-data-container/workflows/Process%20master%20push%20or%20pr/badge.svg?branch=master)](https://github.com/HSLdevcom/pelias-data-container/actions)

Geocoding data build tools

## github actions build

Creates and pushes to dockerhub/hsldevcom two docker containers:

- pelias-data-container-base
- pelias-data-container-builder

pelias-data-container-base is the base image for the running geocoding data service. It is based on Elasticsearch and also
contains all tools for loading and adding address and POI data into the ES index.

pelias-data-container-builder is the data builder application, which builds the final geocoding data container using the base image.
It tests built containers thoroughly using hsldevcom/pelias-fuzzy-tests project and a defined regression threshold (currently 2%).
If the tests pass, the new container is deployed to dockerhub.

## Data builder application

Data builder obeys the following environment variables, which can pe passed to the container using docker run -e option:

 * DOCKER_USER - dockerhub credentials for image deployment
 * DOCKER_AUTH
 * MMLAPIKEY - needed for loading nlsfi data
 * GTFS_AUTH - string of form user:passwd, for loading private gtfs packages from digitransit api
 * ORG - optional, for dockerhub image pushing, default 'hsldevcom'
 * BUILD_INTERVAL - optional, as days, defaults to 7
 * THRESHOLD - optional regression limit, as %, defaults to 2%
 * BUILDER_TYPE - optional, prod or dev, default dev. Controls slack messages and data image tagging (dev->latest, prod->prod)
 * OSM_VENUE_FILTERS and OSM_ADDRESS_FILTERS - json array for adding additional key - value pairs to remove undesired content

An example venue filter: '[{ "name": "some ugly word" }]'

Data builder needs an access to host environment's docker service. The following example call to launch the builder container
shows how to accomplish this:

```bash
docker run -v /var/run/docker.sock:/var/run/docker.sock -e DOCKER_USER=hsldevcom -e DOCKER_AUTH=<secret> -e MMLAPIKEY=<secret> hsldevcom/pelias-data-container-builder
```

Note: the builder image does not include a tool or script for relaunching the data build immediately from within the container. If an immediate build is needed,
rerun the docker image with an environment variable BUILD_INTERVAL=0. The image then executes the build immediately and exits, after which it should be relaunched
with normal (= run forever) settings again.

## Usage in a local system

Builder app can be run locally to get the data-container image:

```bash
#leave dockerhub credentials unset to skip deployment
#runs immediately and once if BUILD_INTERVAL=0
docker run -v /var/run/docker.sock:/var/run/docker.sock -e BUILD_INTERVAL=0 -e MMLAPIKEY=<secret> hsldevcom/pelias-data-container-builder
```

Another alternative is to install required components locally:
- Git projects for pelias dataloading (NLSFI, DVV, OSM, GTFS, bikes, parks, etc.)
- hsldevcom/pelias-schema git project
- WOF admin data is available as a part of this git project
- Properly configured pelias.json config file found in user's home path ̃
- Install and start ElasticSearch
- Export four env. vars, DATA for a data folder path, SCRIPTS for data container scripts of this project,
TOOLS path to the parent dir of dataloading and schema tools and MMLAPIKEY for accessing nlsfi data
- Run the script scripts/dl-and-index.sh

