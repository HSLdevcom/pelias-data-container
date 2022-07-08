#!/bin/bash

# errors should break the execution
set -e

# Download gtfs stop data

echo 'Loading GTFS data from digitransit api...'

cd $DATA
mkdir -p gtfs
mkdir -p openstreetmap

DATA_API="http://api.digitransit.fi/routing-data/"
DEV_DATA_API="http://dev-api.digitransit.fi/routing-data/"

if [ $BUILDER_TYPE = "dev" ]; then
    URL=$DEV_DATA_API"v2/"
    WALTTI_ALT_URL=$DEV_DATA_API"v3/waltti-alt/"
else
    URL=$DATA_API"v2/"
    WALTTI_ALT_URL=$DATA_API"v3/waltti-alt/"
fi

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
    NAME="router-waltti-alt"
    ZIPNAME=$NAME.zip
    curl -sS -O --fail -u $GTFS_AUTH $WALTTI_ALT_URL$ZIPNAME"
    unzip -o $ZIPNAME && rm $ZIPNAME
    mv $NAME/*.zip gtfs/
fi

echo '##### Loaded GTFS data'
