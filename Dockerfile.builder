# Dockerfile which runs the data loader and builds and deploys the final image

FROM docker:1.11.0

WORKDIR /mnt

ADD Dockerfile.loader
ADD build-data-container.sh
ADD pelias.json

ENTRYPOINT ["/mnt/build-data-container.sh" ]
