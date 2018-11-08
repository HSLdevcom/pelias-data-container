#!/bin/bash

# errors should break the execution
set -e

mkdir -p $DATA/openaddresses
cd $DATA/openaddresses

# Download all '/fi/' entries from OpenAddresses
# state.txt describes netries, but urls must be transformed to point to reliable amazonaws and scandic 'ä' urlencoded
curl -sS --fail http://results.openaddresses.io/state.txt | sed 's/\s\+/\n/g' | grep '/fi/.*\.zip' | sed 's/ä/%C3%A4/g' | sed 's/http:\/\//https:\/\/s3.amazonaws.com\//g' | xargs -n 1 curl -O -sS --fail
ls *.zip | xargs -n 1 unzip -o
rm *.zip README.*

echo '##### Loaded OpenAddresses data'
