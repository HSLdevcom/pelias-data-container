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

#do some cleanup for redundant entries
rm -f fi/ahvenanmaa-fi.csv
rm -f fi/etelä-karjala-sv.csv
rm -f fi/etelä-savo-sv.csv
rm -f fi/kainuu-sv.csv
rm -f fi/kanta-häme-sv.csv
rm -f fi/keski-suomi-sv.csv
rm -f fi/lappi-sv.csv
rm -f fi/päijät-häme-sv.csv
rm -f fi/pirkanmaa-sv.csv
rm -f fi/pohjois-karjala-sv.csv
rm -f fi/pohjois-pohjanmaa-sv.csv
rm -f fi/pohjois-savo-sv.csv

echo '##### Loaded OpenAddresses data'
