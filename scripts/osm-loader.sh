#!/bin/bash

# errors should break the execution
set -e

mkdir -p $DATA/openstreetmap
cd $DATA/openstreetmap

# Download osm data
curl -sS -O http://dev.hsl.fi/osm.finland/finland.osm.pbf

echo 'OK' >> /tmp/loadresults
