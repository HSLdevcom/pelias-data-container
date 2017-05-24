#!/bin/bash

# errors should break the execution
set -e

# Download gtfs stop data

URL="http://dev-api.digitransit.fi/routing-data/v2/"

NAME="finland/router-finland.zip"
cd $DATA
curl -sS -O $URL$NAME
unzip $NAME

NAME="waltti/router-waltti.zip"
curl -sS -O $URL$NAME
unzip $NAME

echo '##### Loaded GTFS data'
echo 'OK' >> /tmp/loadresults
