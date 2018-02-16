#!/bin/bash

# errors should break the execution
set -e

mkdir -p $DATA/nls-places
cd $DATA/nls-places

URL='http://kartat.kapsi.fi/files/nimisto/paikat/etrs89/gml/'

function get_name {
    # find out latest zip filename
    NAME=$(curl -Ss $URL | grep -o 'href=".*zip"' | sort -r | head $1 | tail -1 | sed 's/\(href=\|"\)//g')
}

get_name -1

# Download nls paikat data
set +e
echo 'Loading nlsfi data from' $URL$NAME
curl -sS -O --fail $URL$NAME
unzip -o $NAME
RESULT=$?
rm $NAME

if [ $RESULT -ne 0 ]; then
    get_name -2
    echo 'Bad data package, trying older version' $URL$NAME
    curl -sS -O --fail $URL$NAME
    set -e
    unzip -o $NAME
    rm $NAME
fi

echo '##### Loaded nlsfi data'
