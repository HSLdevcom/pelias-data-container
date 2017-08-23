#!/bin/bash

# errors should break the execution
set -e

# Download gtfs stop data

URL="http://dev-api.digitransit.fi/routing-data/v2/"
SERVICE="finland/"
NAME="router-finland.zip"
cd $DATA
curl -sS -O $URL$SERVICE$NAME
unzip -o $NAME

SERVICE="waltti/"
NAME="router-waltti.zip"
curl -sS -O $URL$SERVICE$NAME
unzip -o $NAME

echo '##### Loaded GTFS data'
