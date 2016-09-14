#!/bin/bash
set -e
git clone --depth 1 --single-branch https://github.com/hsldevcom/wof-pip-service $TOOLS/wof-pip-service
cd $TOOLS/wof-pip-service
npm install
#make the package locally available
npm link
echo 'OK' >> /tmp/npmlog
