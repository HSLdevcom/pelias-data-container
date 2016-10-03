#!/bin/bash

# errors should break the execution
set -e

cd $TOOLS/geonames
./bin/pelias-geonames -m
./bin/pelias-geonames -d fi

echo 'OK' >> /tmp/loadresults
