FROM elasticsearch:1.7
MAINTAINER Reittiopas version: 0.1

# Finalize elasticsearch installation

ADD config/elasticsearch.yml /usr/share/elasticsearch/config/

RUN mkdir -p /var/lib/elasticsearch/pelias_data \
  && chown -R elasticsearch:elasticsearch /var/lib/elasticsearch/pelias_data

ENV ES_HEAP_SIZE 4g

# Install dependencies for importers

RUN set -x \
  && apt-get update \
  && apt-get install -y --no-install-recommends git unzip python python-pip python-dev build-essential gdal-bin rlwrap \
  && rm -rf /var/lib/apt/lists/*

RUN curl https://deb.nodesource.com/node_0.12/pool/main/n/nodejs/nodejs_0.12.13-1nodesource1~jessie1_amd64.deb > node.deb \
 && dpkg -i node.deb \
 && rm node.deb

# Auxiliary folders
RUN rm -rf /mnt \
  & mkdir -p /mnt/data/openstreetmap \
  & mkdir -p /tmp/openstreetmap \
  & mkdir -p /mnt/data/openaddresses \
  & mkdir -p /mnt/data/nls-places

# Download OpenStreetMap
WORKDIR /mnt/data/openstreetmap
RUN curl -sS -O http://download.geofabrik.de/europe/finland-latest.osm.pbf

#TODO: Add Tampere after their data has been fixed
WORKDIR /mnt/data/openaddresses
RUN curl http://results.openaddresses.io/state.txt | sed -e 's/\s\+/\n/g' | grep '/fi/.*fi\.zip' | xargs -n 1 curl -O \
  && ls | xargs -n 1 unzip -o \
  && rm *.zip README.txt

# Download nls paikat data
WORKDIR /mnt/data/nls-places
RUN curl -sS -O http://kartat.kapsi.fi/files/nimisto/paikat/etrs89/gml/paikat_2015_05.zip \
  && unzip paikat_2015_05.zip \
  && rm paikat_2015_05.zip

RUN git clone https://github.com/HSLdevcom/pelias-nlsfi-places-importer.git $HOME/.pelias/nls-fi-places \
  && cd $HOME/.pelias/nls-fi-places \
  && npm install

# Download WOF
WORKDIR /mnt/data/
RUN git clone https://github.com/pelias/whosonfirst \
  && cd whosonfirst \
  && npm install \
  && npm run download

WORKDIR /root

# Copying pelias config file
ADD pelias.json pelias.json

# Add elastisearch-head plugin for browsing ElasticSearch data
RUN chmod +wx /usr/share/elasticsearch/plugins/
RUN /usr/share/elasticsearch/bin/plugin -install mobz/elasticsearch-head

RUN gosu elasticsearch elasticsearch -d \
  && npm install -g pelias-cli \
  && sleep 30 \
  && pelias schema#master create_index \
  && node $HOME/.pelias/nls-fi-places/lib/index -d /mnt/data/nls-places \
  && pelias openstreetmap#master import \
  && pelias openaddresses#master import --admin-values

RUN chmod -R a+rwX /var/lib/elasticsearch/ \
  && chown -R 9999:9999 /var/lib/elasticsearch/

ENV ES_HEAP_SIZE 1g

ENTRYPOINT ["elasticsearch"]

USER 9999
