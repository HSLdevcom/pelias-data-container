#!/bin/bash

# this import script indexes nlsfi places, polylines and osm data

# errors should break the execution
set -e

# param: zip name containing gtfs data
function import_gtfs {
    unzip -o $1
    node $TOOLS/pelias-gtfs/import -d $DATA/router-finland
}

cd $DATA/router-finland
targets=(`ls *.zip`)
for target in "${targets[@]}"
do
    import_gtfs $target
done

node $TOOLS/pelias-nlsfi-places-importer/lib/index -d $DATA/nls-places
node $TOOLS/polylines/bin/cli.js --config --db
node $TOOLS/openstreetmap/index

echo 'OK' >> /tmp/indexresults
