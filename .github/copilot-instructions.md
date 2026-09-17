# pelias-data-container

This repo builds and deploys the geocoding data used by HSL/Digitransit's Pelias-based
geocoding service. There is no application code to unit test — the repo is a set of shell
scripts and small Node.js helpers that download source data (OSM, DVV/VRK, NLSFI, GTFS,
Who's On First), index it into Elasticsearch, and package the result as Docker images.

## Build / test / lint

There is no test suite, linter, or build tool (no `npm test`/`npm run build`/CI lint step).
The only "build" is producing Docker images; the only validation available is running the
scripts themselves.

- Install Node deps for the loader scripts: `cd scripts && npm install`
- Run a single Node helper directly to check it works, e.g.:
  `node scripts/parse_nlsfi_url.js` (requires `MMLAPIKEY` env var)
  `node scripts/fetchBlackList.js` (expects a pelias config at `/root/pelias.json`)
- Shell scripts can be sanity-checked with `bash -n scripts/<script>.sh` (syntax only) since
  most of them expect to run inside the built Docker images with specific env vars/paths set
  (`$DATA`, `$TOOLS`, `$SCRIPTS`, `$WORKDIR`) and cannot be run standalone on a dev machine.
- Full end-to-end build/test/deploy: `bash scripts/build-data-container.sh` — builds
  `Dockerfile.loader` from the base image, runs the container, boots
  `hsldevcom/pelias-fuzzy-tests` regression tests against it (default 2% threshold via
  `THRESHOLD`), and only pushes to Docker Hub if `DOCKER_USER`/`DOCKER_AUTH` are set. This is
  normally invoked from inside `Dockerfile.pelias-data-container-builder`, not run bare.

## Architecture (three-stage image pipeline)

1. **`pelias-data-container-base`** (`Dockerfile.pelias-data-container-base`) — installs
   Elasticsearch 7.16.2 + `analysis-icu`, copies in `scripts/`, `config/elasticsearch.yml`,
   and `pelias.json`, and runs `scripts/install-tools.sh` to clone/npm-install all the
   external Pelias importer projects (`pelias-schema`, `openstreetmap`, `pelias-vrk`,
   `pelias-nlsfi-places-importer`, `pelias-gtfs`, `bikes-pelias`, `parking-areas-pelias`)
   into `/mnt/tools`. This image has the tools but no data.
2. **`pelias-data-container` (loader)** (`Dockerfile.loader`) — `FROM` the base image, runs
   `scripts/getdata.sh` at build time, which starts Elasticsearch and calls
   `scripts/dl-and-index.sh`. That script downloads data via the `*-loader.sh` scripts
   (`vrk-loader.sh`, `osm-loader.sh`, `nlsfi-loader.sh`, `gtfs-loader.sh`), pulls the
   `wof_data/` (Who's On First admin data, pre-filtered by `wof_data/update.sh`) from this
   same repo, then indexes everything via the external importer tools cloned in step 1,
   producing a self-contained ES data image.
3. **`pelias-data-container-builder`** (`Dockerfile.pelias-data-container-builder`) — a
   docker-in-docker image containing `scripts/build-data-container.sh` and the
   `pelias-fuzzy-tests` project. It builds the loader image, spins it up alongside a
   `pelias-api` container, runs fuzzy-test regression checks plus smoke tests (reverse
   geocode, autocomplete, place lookup), and pushes the image to Docker Hub if tests pass
   and credentials are present. Slack notifications are sent via `SLACK_CHANNEL_ID` when set.

CI (`.github/workflows/dev-pipeline.yml`, `prod-pipeline.yml`) only builds/pushes the
**base** and **builder** images (via `.github/workflows/scripts/build_and_push_dev.sh` /
`push_prod.sh`); the actual data-loading/testing/deploy cycle above runs later, driven by
the builder image itself (e.g. via a scheduled job elsewhere), not by these workflows.

## Key conventions

- All cross-script env vars are passed positionally through the pipeline: scripts assume
  `$DATA`, `$TOOLS`, `$SCRIPTS`, `$WORKDIR`, `$MMLAPIKEY`, `$GTFS_AUTH`,
  `$API_SUBSCRIPTION_QUERY_PARAMETER_NAME`/`$API_SUBSCRIPTION_TOKEN`, and `$BUILDER_TYPE`
  (`dev` or `prod`, controls whether dev-api or prod-api Digitransit endpoints are used and
  how images are tagged: `dev`→`latest`, `prod`→`prod`) are already exported by the caller.
  Don't assume defaults exist outside what a script itself sets with `${VAR:-default}`.
- Every loader script starts with `set -e` — data loading is expected to abort hard on any
  failure; preserve this when editing.
- GTFS zip files are prefixed with their source service name during download
  (`gtfs-loader.sh`, e.g. `waltti--x-gtfs.zip`) so `dl-and-index.sh`'s `import_gtfs` can
  recover the correct OTP routing service (`finland`/`waltti`/`hsl`/`varely`) from the
  filename when picking the `otpUrl` for import.
- `wof_data/` is checked into this repo (not downloaded at build time) and is intentionally
  pre-filtered by `wof_data/update.sh` — when refreshing it, re-run that script rather than
  copying raw Who's On First exports in directly, to keep unwanted place types/sources out.
- `pelias.json` in the repo root is the canonical Pelias config template; it gets copied into
  images and is patched in place at runtime (e.g. `fetchBlackList.js` rewrites
  `imports.blacklist`, `build-data-container.sh` rewrites `endpoints.local` via `sed`).
- External Pelias tool projects (schema, importers) are cloned from `hsldevcom`/`HSLdevcom`
  GitHub orgs at image build time (`install-tools.sh`), not vendored — this repo only owns
  the orchestration scripts and Digitransit-specific config/data.
