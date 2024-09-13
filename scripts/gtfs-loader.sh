#!/bin/bash

# errors should break the execution
set -e

# Download gtfs stop data

echo 'Loading GTFS data'

cd $DATA
mkdir -p gtfs
mkdir -p openstreetmap

PARAMS='?'"$API_SUBSCRIPTION_QUERY_PARAMETER_NAME"'='"$API_SUBSCRIPTION_TOKEN"

if [ "$BUILDER_TYPE" = "dev" ]; then
    URL="https://dev-api.digitransit.fi/routing-data/"
else
    URL="https://api.digitransit.fi/routing-data/"
fi

# param1: data version, v2 or v3
# param2: service name
function load_gtfs {
    NAME="router-"$2
    ZIPNAME=$NAME.zip
    DATAURL=$URL$1/$2/$ZIPNAME
    echo Loading GTFS from "$DATAURL"
    curl -sS --fail $DATAURL$PARAMS -o $ZIPNAME
    unzip -o $ZIPNAME && rm $ZIPNAME
    mv $NAME/*.zip gtfs/
}

load_gtfs v3 finland
# use already validated osm data from our own data api
mv router-finland/*.pbf openstreetmap/

load_gtfs v3 waltti
load_gtfs v3 hsl
load_gtfs v3 varely
load_gtfs v3 waltti-alt

echo '##### Loaded GTFS data'
