#!/bin/bash

# errors should break the execution
set -e

# Download all '/fi/' entries from OpenAddresses
cd $DATA/openaddresses
curl -sS http://results.openaddresses.io/state.txt | sed -e 's/\s\+/\n/g' | grep '/fi/.*\.zip' | xargs -n 1 curl -O -sS
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

echo 'OK' >> /tmp/loadresults
