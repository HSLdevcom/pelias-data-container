# Dockerfile for image which runs the data loader and builds and deploys the final image

FROM docker:1.11.0

WORKDIR /mnt

ADD Dockerfile.loader ${WORKDIR}
ADD scripts/build-data-container.sh ${WORKDIR}
ADD pelias.json ${WORKDIR}

RUN apk add --no-cache bash git python curl jq alpine-sdk

ENTRYPOINT ["/mnt/build-data-container.sh" ]
