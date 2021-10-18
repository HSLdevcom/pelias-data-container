#!/bin/bash

# errors should break the execution
set -e

# Download gtfs stop data

echo 'Loading GTFS data from api.digitransit.fi...'

cd $DATA
mkdir -p gtfs
mkdir -p openstreetmap

URL="http://api.digitransit.fi/routing-data/v2/"
SERVICE="finland/"
NAME="router-finland.zip"
curl -sS -O --fail $URL$SERVICE$NAME
unzip -o $NAME && rm $NAME
mv router-finland/*.zip gtfs/

SERVICE="waltti/"
NAME="router-waltti.zip"
curl -sS -O --fail $URL$SERVICE$NAME
unzip -o $NAME && rm $NAME
mv router-waltti/*.zip gtfs/

SERVICE="hsl/"
NAME="router-hsl.zip"
curl -sS -O --fail $URL$SERVICE$NAME
unzip -o $NAME && rm $NAME
mv router-hsl/*.zip gtfs/

echo '##### Loaded GTFS data'
