#!/bin/bash
set -e
git clone --depth 1 --single-branch https://github.com/hsldevcom/dbclient $TOOLS/dbclient
cd $TOOLS/dbclient
npm install
#make the package locally available
npm link
echo 'OK' >> /tmp/npmlog
