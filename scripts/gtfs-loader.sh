#!/bin/bash

# errors should break the execution
set -e

NAME=router-finland.zip

# Download gtfs stop data
cd $DATA
curl -sS -O http://dev-api.digitransit.fi/routing-data/v1/$NAME
unzip $NAME

echo '##### Loaded GTFS data'
echo 'OK' >> /tmp/loadresults
