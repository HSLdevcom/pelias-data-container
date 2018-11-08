# Dockerfile for image which runs the data loader and builds and deploys the final image

FROM docker:18.06

ENV DOCKER_API_VERSION ${DOCKER_API_VERSION:-1.23}

WORKDIR /mnt

ADD Dockerfile.loader ${WORKDIR}
ADD scripts/build-data-container.sh ${WORKDIR}
ADD pelias.json ${WORKDIR}

RUN apk add --no-cache alpine-sdk bash bc curl git jq python sed grep coreutils

ENTRYPOINT ["/mnt/build-data-container.sh" ]
