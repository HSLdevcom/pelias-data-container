# Dockerfile for image which runs the data loader and builds and deploys the final image

FROM docker:18.06

WORKDIR /mnt

ADD Dockerfile.loader ${WORKDIR}
ADD scripts/build-data-container.sh ${WORKDIR}
ADD pelias.json ${WORKDIR}

RUN apk add --no-cache alpine-sdk bash bc curl git jq python sed grep coreutils nodejs nodejs-npm

RUN git clone --single-branch https://github.com/hsldevcom/pelias-fuzzy-tests \
  && cd pelias-fuzzy-tests \
  && npm install

ENTRYPOINT ["/mnt/build-data-container.sh" ]
