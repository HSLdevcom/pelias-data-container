#!/bin/bash

# errors should break the execution
set -e

# Download osm data
cd $DATA/openstreetmap
curl -sS -O http://download.geofabrik.de/europe/finland-latest.osm.pbf

echo 'OK' >> /tmp/loadresults
