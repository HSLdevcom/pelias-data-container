#!/bin/bash

# errors should break the execution
set -e

# Download gtfs stop data

echo 'Loading GTFS data from api.digitransit.fi...'

cd $DATA
mkdir -p gtfs
mkdir -p openstreetmap

URL="http://api.digitransit.fi/routing-data/v2/"

# param1: service name
# param2: optional basic auth string
function load_gtfs {
    NAME="router-"$1
    ZIPNAME=$NAME.zip
    curl -sS -O --fail $2 $URL$1/$ZIPNAME
    unzip -o $ZIPNAME && rm $ZIPNAME
    mv $NAME/*.zip gtfs/
}

load_gtfs finland
# use already validated osm data from our own data api
mv router-finland/*.pbf openstreetmap/

load_gtfs waltti
load_gtfs hsl

if [[ -v GTFS_AUTH ]]; then
    load_gtfs next-waltti "-u $GTFS_AUTH"
fi

echo '##### Loaded GTFS data'
