#!/bin/bash

# this import script indexes nlsfi places, polylines and osm data

# errors should break the execution
set -e

node $TOOLS/pelias-nlsfi-places-importer/lib/index -d $DATA/nls-places

node $TOOLS/polylines/bin/cli.js --config --db
node $TOOLS/openstreetmap/index

echo 'OK' >> /tmp/indexresults
