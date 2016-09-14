#!/bin/bash
set -e
git clone --depth 1 --single-branch https://github.com/hsldevcom/openaddresses $TOOLS/openaddresses
cd $TOOLS/openaddresses
npm install
npm link pelias-dbclient
npm link pelias-wof-admin-lookup
echo 'OK' >> /tmp/npmlog
