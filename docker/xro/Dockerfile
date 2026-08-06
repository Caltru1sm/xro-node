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
# XRO's own release version, surfaced as node_vendor / --version. This is only a
# display string. The wire-visible version fields peers actually compare
# (major/minor/patch/pre_release in telemetry) come from CPACK_PACKAGE_VERSION_*
# in CMakeLists.txt and stay at Nano's 28.0.0 - the honest base version. Renaming
# those to 2.x would advertise this node as ancient to a network that de-peers
# old versions.
ARG CI_TAG=xro-node-2.0.0
ARG CI_VERSION_PRE_RELEASE=OFF

# Parallelism is derived from available memory, not hardcoded.
#
# ci/build.sh runs `cmake --build --parallel $(nproc)` with no override, so job
# count tracks CPU count while the real constraint is RAM - rocksdb translation
# units are the ones that OOM. Since nproc honours CPU affinity, taskset is the
# lever (BuildKit ignores --cpuset-cpus on `docker build`).
#
# Empirically this tree needs ~1.5 GB per concurrent gcc job: 7 GB sustained 4
# jobs, 12 GB sustains 8. Deriving it means the build adapts to whatever machine
# it runs on instead of depending on the builder knowing their own specs.
# Override with --build-arg BUILD_JOBS=N to pin it.
ARG BUILD_JOBS=auto
ARG MB_PER_JOB=1536

COPY ./ci/prepare/linux /tmp/prepare
RUN /tmp/prepare/prepare.sh

COPY ./ /tmp/src
WORKDIR /tmp/src

RUN set -eu; \
    cores=$(nproc); \
    if [ "${BUILD_JOBS}" = "auto" ]; then \
      mem_mb=$(awk '/^MemTotal:/ {printf "%d", $2/1024}' /proc/meminfo); \
      jobs=$(( mem_mb / ${MB_PER_JOB} )); \
      [ "$jobs" -lt 1 ] && jobs=1; \
      [ "$jobs" -gt "$cores" ] && jobs=$cores; \
    else \
      jobs=${BUILD_JOBS}; \
    fi; \
    echo "build: ${mem_mb:-?} MB RAM, ${cores} cores -> ${jobs} parallel jobs"; \
    taskset -c 0-$(( jobs - 1 )) ci/build-node.sh

FROM ubuntu:24.04

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends ca-certificates curl jq \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /tmp/src/build/nano_node /bin/nan_node
COPY docker/xro/init.sh /usr/local/bin/init.sh
RUN chmod +x /bin/nan_node /usr/local/bin/init.sh

WORKDIR /root
ENTRYPOINT ["/usr/local/bin/init.sh"]
