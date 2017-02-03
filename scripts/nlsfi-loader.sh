#!/bin/bash

# errors should break the execution
set -e

NAME=paikat_2017_01.zip

mkdir -p $DATA/nls-places
cd $DATA/nls-places

# Download nls paikat data
curl -sS -O http://kartat.kapsi.fi/files/nimisto/paikat/etrs89/gml/$NAME
unzip $NAME
rm $NAME

echo '##### Loaded nlsfi data'
echo 'OK' >> /tmp/loadresults
