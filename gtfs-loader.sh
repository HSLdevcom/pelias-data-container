#!/bin/bash

# errors should break the execution
set -e

# Download gtfs stop data
cd $DATA
curl -sS -O http://dev-api.digitransit.fi/routing-data/v1/router-finland.zip
unzip router-finland.zip

echo 'OK' >> /tmp/loadresults
