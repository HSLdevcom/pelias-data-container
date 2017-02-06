#!/bin/bash

# this import script indexes nlsfi places, polylines and osm data

# errors should break the execution
set -e

node $TOOLS/pelias-nlsfi-places-importer/lib/index -d $DATA/nls-places
echo '###### nlsfi places done'

node $TOOLS/polylines/bin/cli.js --config --db
echo '###### polylines done'

node $TOOLS/openstreetmap/index
echo '###### openstreetmap done'

echo 'OK' >> /tmp/indexresults
