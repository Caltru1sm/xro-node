# XRO node image, built from source.
#
# The upstream yxse/nan image did NOT build from source - it ran
#   wget https://github.com/MyEcoria/nano-env/releases/download/V1.1/nano_node
# with no checksum verification, and renamed the result to nan_node. This image
# compiles the binary from the tree it is built against, which is both the only
# way to apply the bootstrap-weights fix and a removal of that supply-chain
# exposure.
#
# Layout is kept deliberately compatible with the image it replaces:
#   binary     /bin/nan_node
#   entrypoint /usr/local/bin/init.sh
#   workdir    /root   (data dir bind-mounted here)

FROM ubuntu:22.04 AS builder

ARG COMPILER=gcc
ARG NANO_NETWORK=live
ARG BUILD_TYPE=RelWithDebInfo
ARG NANO_TEST=OFF
ARG NANO_TRACING=OFF
ARG COVERAGE=OFF
ARG CI_TAG=xro-bootstrap-fix
ARG CI_VERSION_PRE_RELEASE=OFF

# ci/build.sh hardcodes `cmake --build --parallel $(nproc)` with no override, and
# 12 concurrent gcc jobs OOMs a 7 GB machine on rocksdb. nproc honours CPU
# affinity, so taskset caps it. --cpuset-cpus on `docker build` would not work
# here: BuildKit ignores it.
ARG BUILD_CPUS=0-3

COPY ./ci/prepare/linux /tmp/prepare
RUN /tmp/prepare/prepare.sh

COPY ./ /tmp/src
WORKDIR /tmp/src

RUN taskset -c ${BUILD_CPUS} ci/build-node.sh

FROM ubuntu:24.04

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends ca-certificates curl jq \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /tmp/src/build/nano_node /bin/nan_node
COPY docker/xro/init.sh /usr/local/bin/init.sh
RUN chmod +x /bin/nan_node /usr/local/bin/init.sh

WORKDIR /root
ENTRYPOINT ["/usr/local/bin/init.sh"]
