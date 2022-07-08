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
    URL=$DEV_DATA_API
    WALTTI_ALT_URL=$DEV_DATA_API"v3/waltti-alt/"
else
    URL=$DATA_API
    WALTTI_ALT_URL=$DATA_API"v3/waltti-alt/"
fi

# param1: data version, v2 or v3
# param2: service name
function load_gtfs {
    NAME="router-"$2
    ZIPNAME=$NAME.zip
    curl -sS -O --fail $URL$1/$2/$ZIPNAME
    unzip -o $ZIPNAME && rm $ZIPNAME
    mv $NAME/*.zip gtfs/
}

load_gtfs v2 finland
# use already validated osm data from our own data api
mv router-finland/*.pbf openstreetmap/

load_gtfs v2 waltti
load_gtfs v2 hsl
load_gtfs v3 varely

if [[ -v GTFS_AUTH ]]; then
    NAME="router-waltti-alt"
    ZIPNAME=$NAME.zip
    curl -sS -O --fail -u $GTFS_AUTH $WALTTI_ALT_URL$ZIPNAME"
    unzip -o $ZIPNAME && rm $ZIPNAME
    mv $NAME/*.zip gtfs/
fi

echo '##### Loaded GTFS data'
