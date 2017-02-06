#!/bin/bash

# errors should break the execution
set -e

mkdir -p $DATA/nls-places
cd $DATA/nls-places

URL='http://kartat.kapsi.fi/files/nimisto/paikat/etrs89/gml/'

# find out latest zip filename
NAME=$(curl -Ss $URL | grep -o 'href=".*zip"' | sort -r | head -1 | sed 's/\(href=\|"\)//g')

echo 'Loading nlsfi data from' $URL$NAME

# Download nls paikat data
curl -sS -O $URL$NAME
unzip $NAME
rm $NAME

echo '##### Loaded nlsfi data'
echo 'OK' >> /tmp/loadresults
