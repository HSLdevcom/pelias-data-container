#!/bin/bash

# path where to find wof cloning tool
TOOLS=../

# to install the wof cloning tool:
# git clone https://github.com/whosonfirst/go-whosonfirst-clone.git $TOOLS/wof-clone
# cd $TOOLS/wof-clone
# make deps
# make bin


# Download Whosonfirst admin lookup data
URL=https://whosonfirst.mapzen.com/bundles
METADIR=meta/
DATADIR=data/
mkdir -p $METADIR
mkdir -p $DATADIR

cd $METADIR

admins=( country localadmin locality neighbourhood region )

for target in "${admins[@]}"
do
    echo getting $target metadata
    curl -O -sS $URL/wof-$target-latest.csv
    if [ "$target" != "continent" ]
    then
	head -1 wof-$target-latest.csv > temp && cat wof-$target-latest.csv | grep ",FI," >> temp || true
	mv temp wof-$target-latest.csv
    fi
done

empty_admins=( continent borough county dependency disputed macrocounty macroregion )

for target in "${empty_admins[@]}"
do
    cp ../empty.csv wof-$target-latest.csv
done

cd ../

for target in "${admins[@]}"
do
    echo getting $target data
    $TOOLS/go-whosonfirst-clone/bin/wof-clone-metafiles -dest $DATADIR $METADIR/wof-$target-latest.csv
done
