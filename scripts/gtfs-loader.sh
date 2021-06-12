#!/bin/bash

# errors should break the execution
set -e

# Download gtfs stop data

echo 'Loading GTFS data from api.digitransit.fi...'

URL="http://api.digitransit.fi/routing-data/v2/"
SERVICE="finland/"
NAME="router-finland.zip"
cd $DATA
mkdir -p gtfs
curl -sS -O --fail $URL$SERVICE$NAME
unzip -o $NAME -d gtfs && rm $NAME

SERVICE="waltti/"
NAME="router-waltti.zip"
curl -sS -O --fail $URL$SERVICE$NAME
unzip -o $NAME -d gtfs && rm $NAME

SERVICE="hsl/"
NAME="router-hsl.zip"
curl -sS -O --fail $URL$SERVICE$NAME
unzip -o $NAME -d gtfs && rm $NAME

echo '##### Loaded GTFS data'
