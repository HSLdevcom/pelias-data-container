#!/bin/bash

#renewed script for processing data fetched from current WOF distribution at https://geocode.earth/data/whosonfirst

#remove all point features which cannot define an area
#this will cause harmless warnings in wof lookup as metafiles refer to unknown geometry
#to get rid of warnings, log warnings to a file and modify each warning line to to execute:
#  sed -i '/xxxx.geojson/d' whosonfirst-data-<layer>-latest.csv
grep -lr data -e '"type":"Point"'  | xargs rm
grep -lr data -e 'alt-quattroshapes'  | xargs rm

#Use only localadmins from figov. The rest are duplicates or trash.
sed -i '/qs_pg/d' meta/whosonfirst-data-admin-fi-localadmin-latest.csv

#remove quattroshapes neighbourhoods, they are rubbish, and some other data from bad sources
sed -i '/quattroshapes/d' meta/whosonfirst-data-admin-fi-neighbourhood-latest.csv
sed -i '/mz/d' meta/whosonfirst-data-admin-fi-neighbourhood-latest.csv
sed -i '/qs_pg/d' meta/whosonfirst-data-admin-fi-neighbourhood-latest.csv

#remove geonames localities, bad quality and always point geometry
sed -i '/geonames/d' meta/whosonfirst-data-admin-fi-locality-latest.csv
sed -i '/alt-quattroshapes/d' meta/whosonfirst-data-admin-fi-locality-latest.csv

#remove bad region
sed -i '/85683085.geojson/d' meta/whosonfirst-data-admin-fi-region-latest.csv

#remove bad postalcodes
sed -i '/geoplanet/d' meta/whosonfirst-data-postalcode-fi-postalcode-latest.csv

cd meta
#remove unused admin metadata
rm whosonfirst-data-admin-fi-borough-latest.csv
rm whosonfirst-data-admin-fi-campus-latest.csv
rm whosonfirst-data-admin-fi-country-latest.csv
rm whosonfirst-data-admin-fi-county-latest.csv
rm whosonfirst-data-admin-fi-dependency-latest.csv
rm whosonfirst-data-admin-fi-macrohood-latest.csv
rm whosonfirst-data-admin-fi-macroregion-latest.csv
rm whosonfirst-data-admin-fi-microhood-latest.csv

#rename metadata files into backward compatible form we use
mv whosonfirst-data-admin-fi-neighbourhood-latest.csv whosonfirst-data-neighbourhood-latest.csv
mv whosonfirst-data-admin-fi-region-latest.csv whosonfirst-data-region-latest.csv
mv whosonfirst-data-admin-fi-localadmin-latest.csv whosonfirst-data-localadmin-latest.csv
mv whosonfirst-data-admin-fi-locality-latest.csv whosonfirst-data-locality-latest.csv
mv whosonfirst-data-postalcode-fi-postalcode-latest.csv whosonfirst-data-postalcode-latest.csv
