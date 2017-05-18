#!/bin/bash

# errors should break the execution
set -e

NAME="finland/router-finland.zip"
PATH="http://dev-api.digitransit.fi/routing-data/v1/"

# Download gtfs stop data
cd $DATA
curl -sS -O $PATH$NAME
unzip $NAME

NAME="waltti/router-waltti.zip"
curl -sS -O $PATH$NAME
unzip $NAME

echo '##### Loaded GTFS data'
echo 'OK' >> /tmp/loadresults
