#!/bin/bash

# errors should break the execution
set -e

mkdir -p $DATA/openstreetmap
cd $DATA/openstreetmap

# Download osm data
curl -sS -O --fail http://dev.hsl.fi/osm.finland/finland.osm.pbf

echo '##### Loaded OSM data'
