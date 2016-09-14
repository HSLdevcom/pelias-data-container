#!/bin/bash
set -e
git clone --depth 1 --single-branch https://github.com/hsldevcom/wof-admin-lookup $TOOLS/wof-admin-lookup
cd $TOOLS/wof-admin-lookup
npm install
#make the package locally available
npm link
npm link pelias-wof-pip-service
echo 'OK' >> /tmp/npmlog
