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

RUN curl https://deb.nodesource.com/node_0.12/pool/main/n/nodejs/nodejs_0.12.9-1nodesource1~jessie1_amd64.deb > node.deb \
 && dpkg -i node.deb \
 && rm node.deb

RUN git clone https://github.com/openvenues/address_deduper.git \
  && cd address_deduper \
  && pip install -r requirements.txt

# Auxiliary folders
RUN rm -rf /mnt \
  & mkdir -p /mnt/data/openstreetmap \
  & mkdir -p /tmp/openstreetmap \
  & mkdir -p /mnt/data/openaddresses \
  & mkdir -p /mnt/data/quattroshapes \
  & mkdir -p /mnt/data/nls-places

# Download quattroshapes data (only higher levels will be used)
WORKDIR /mnt/data/quattroshapes
RUN curl -sS -O http://quattroshapes.mapzen.com/quattroshapes/alpha3/FIN.tgz \
  && tar zxvf FIN.tgz && rm -f FIN.tgz \
  && SHAPE_ENCODING="ISO-8859-1" ogr2ogr qs_adm0.shp FIN/FIN_admin0.shp -lco ENCODING=UTF-8 \
  && SHAPE_ENCODING="ISO-8859-1" ogr2ogr qs_adm1.shp FIN/FIN_admin1.shp -lco ENCODING=UTF-8 \
  && SHAPE_ENCODING="ISO-8859-1" ogr2ogr qs_adm2.shp FIN/FIN_admin2.shp -lco ENCODING=UTF-8 \
  && SHAPE_ENCODING="ISO-8859-1" ogr2ogr qs_localadmin.shp FIN/FIN_localadmin.shp -lco ENCODING=UTF-8 \
  && rm -rf FIN

# Download Finnish municipalities and convert these to quattroshapes format
RUN curl -sS -O http://kartat.kapsi.fi/files/kuntajako/kuntajako_10k/etrs89/gml/TietoaKuntajaosta_2015_10k.zip \
  && unzip TietoaKuntajaosta_2015_10k.zip \
  && ogr2ogr -t_srs EPSG:4326 -nlt POLYGON -splitlistfields -where "nationalLevel='4thOrder'" -f "ESRI Shapefile" kunnat.shp TietoaKuntajaosta_2015_10k/SuomenKuntajako_2015_10k.xml AdministrativeUnit -lco ENCODING=UTF-8 \
  && ogr2ogr -sql "SELECT text1 AS qs_loc FROM kunnat" -f "ESRI Shapefile" qs_localities.shp kunnat.shp -lco ENCODING=UTF-8 \
  && rm -rf TietoaKuntajaosta_2015_10k.zip TietoaKuntajaosta_2015_10k/ kunnat.*

# Download zip codes and convert these to quattroshapes format
RUN ogr2ogr -t_srs EPSG:4326 -nlt POLYGON -sql "SELECT CONCAT( posti_alue, ' ', nimi ) AS name from 'postialue:pno_meri_2015'" -f "ESRI Shapefile" qs_neighborhoods.shp WFS:http://geo.stat.fi/geoserver/postialue/postialue%3Apno_meri_2015/wfs -lco ENCODING=UTF-8

# Download OpenStreetMap
WORKDIR /mnt/data/openstreetmap
RUN curl -sS -O http://download.geofabrik.de/europe/finland-latest.osm.pbf

#TODO: find out run number from http://results.openaddresses.io/state.txt
#TODO: Add Tampere after their data has been fixed
WORKDIR /mnt/data/openaddresses
RUN curl -sS -O http://data.openaddresses.io.s3.amazonaws.com/runs/37881/fi/18/helsinki.zip \
  && unzip -o helsinki.zip \
  && rm helsinki.zip \
  && curl -sS -O http://data.openaddresses.io.s3.amazonaws.com/runs/37878/fi/14/oulu.zip \
  && unzip -o oulu.zip \
  && rm oulu.zip \
  && curl -sS -O http://data.openaddresses.io.s3.amazonaws.com/runs/32517/fi/19/turku.zip \
  && unzip -o turku.zip \
  && rm turku.zip

# Download nls paikat data
WORKDIR /mnt/data/nls-places
RUN curl -sS -O http://kartat.kapsi.fi/files/nimisto/paikat/etrs89/gml/paikat_2015_05.zip \
  && unzip paikat_2015_05.zip \
  && rm paikat_2015_05.zip

RUN git clone https://github.com/HSLdevcom/pelias-nlsfi-places-importer.git $HOME/.pelias/nls-fi-places \
  && cd $HOME/.pelias/nls-fi-places \
  && npm install

WORKDIR /root

# Copying pelias config file
ADD pelias.json pelias.json

# Add elastisearch-head plugin for browsing ElasticSearch data
RUN chmod +wx /usr/share/elasticsearch/plugins/
RUN /usr/share/elasticsearch/bin/plugin -install mobz/elasticsearch-head

# The address deduper will run trough the build process, so start it in the background
# Hence the single ampersand after the deduper process
RUN gosu elasticsearch elasticsearch -d \
  && python /address_deduper/app.py serve \
  & npm install -g pelias-cli \
  && sleep 30 \
  && pelias schema#production create_index \
  && node $HOME/.pelias/nls-fi-places/lib/index -d /mnt/data/nls-places \
  && pelias openaddresses#production import --admin-values --deduplicate \
  && pelias openstreetmap#production import

RUN chmod -R a+rwX /var/lib/elasticsearch/ \
  && chown -R 9999:9999 /var/lib/elasticsearch/

ENV ES_HEAP_SIZE 1g

ENTRYPOINT ["elasticsearch"]

USER 9999
