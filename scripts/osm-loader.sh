#!/bin/bash

# errors should break the execution
set -e

mkdir -p $DATA/openstreetmap
cd $DATA/openstreetmap

# Download osm data
curl -sS -O -L --fail https://karttapalvelu.storage.hsldev.com/finland.osm/finland.osm.pbf

echo '##### Loaded OSM data'
