#!/bin/bash
URL=https://whosonfirst.mapzen.com/bundles
METADIR=wof_data/meta/
DATADIR=wof_data/data/
mkdir -p $METADIR
mkdir -p $DATADIR

cd $METADIR

admins=( continent borough country county dependency disputed localadmin locality macrocounty macroregion neighbourhood region )

for target in "${admins[@]}"
do
    echo getting $target metadata
    curl -O -sS $URL/wof-$target-latest.csv
    if [ "$target" != "continent" ]
    then
	head -1 wof-$target-latest.csv > temp && cat wof-$target-latest.csv | grep ",FI" >> temp
	mv temp wof-$target-latest.csv
    fi
done

cd ../../

for target in "${admins[@]}"
do
    echo getting $target data
    $HOME/wof-clone/bin/wof-clone-metafiles -dest $DATADIR $METADIR/wof-$target-latest.csv
done
