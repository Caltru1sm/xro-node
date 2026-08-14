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

# Skip Qt, valgrind and the X stack. This image builds nano_node and nano_rpc
# only, never the wallet, and ci/build.sh passes -DNANO_GUI=OFF - so none of it
# is ever looked for, it is just apt download time. Set to false to restore the
# full dependency set.
ARG NANO_BUILD_MINIMAL=true

COPY ./ci/prepare/linux /tmp/prepare
RUN NANO_BUILD_MINIMAL=${NANO_BUILD_MINIMAL} /tmp/prepare/prepare.sh

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

# =============================================================================
# XRO NETWORK IDENTITY - baked defaults
#
# Ten variables. Eight are read directly by the node at runtime, two by init.sh:
#
#   prefix        nano/lib/numbers.cpp:77    address encode AND decode
#   source        nano/secure/common.cpp:46  genesis source pubkey
#   account       nano/secure/common.cpp:58  genesis account + representative
#   work          nano/secure/common.cpp:70  genesis work
#   signature     nano/secure/common.cpp:82  genesis signature
#   name          nano/secure/utility.cpp:29 data directory under /root
#   peering       nano/node/nodeconfig.cpp:22 seed host for peer discovery
#   peering_port  nano/lib/constants.hpp:100 P2P listen port
#   RPC_PORT      docker/xro/init.sh         written into config-rpc.toml
#   WS_PORT       docker/xro/init.sh         written into config-node.toml
#
# WHY THESE ARE BAKED
# -------------------
# Every one of them has a fallback, and every fallback is Nano's, not XRO's:
# genesis defaults to Nano mainnet's, `prefix` to nano_/xrb_, `name` to "Nano",
# `peering` to peering.nano.org, `peering_port` to 7075. A node started without
# them does not fail - it comes up clean on the wrong network, finds no peers,
# and presents as a bootstrap fault. Requiring ten exact `-e` flags made that
# the single most common way a new peer got it wrong.
#
# Baked, `docker run -v <dir>:/root -p 8075:8075 caltru1sm/xro-node` is a
# correct XRO node with no flags at all.
#
# These are DEFAULTS. Anything passed via -e or env_file still wins, so the
# existing amd64 deployment - which sets all ten explicitly - is unaffected.
# init.sh re-validates whatever ends up in effect.
# =============================================================================
ENV prefix="xro_"
ENV account="xro_3oh6tp9b8y65w1fzp3aaxgebptkdhnrziiqaairqfhzkcntiwn1r97cgzikp"
ENV source="D5E4D58E937883E01BFB0508EB989B6A4B7D31F842E8443176BFF255350E5018"
ENV work="9da7e03b2a2ec54b"
ENV signature="FBB7588466EAA76196181C3CDF249178BAC70929E28AABBD5DE284362A34899AB4C972A232824067F439E89F2672B792105D3A55763B852FD21967EC7957260D"
ENV name="RaiblocksOne"
ENV peering="peering.raione.cc"
ENV peering_port="8075"
ENV RPC_PORT="8076"
ENV WS_PORT="8078"

WORKDIR /root

# 8075 is the only port that needs to reach the internet. 8076 (RPC) and 8078
# (websocket) bind loopback inside the container by default - see init.sh.
EXPOSE 8075

HEALTHCHECK --interval=60s --timeout=10s --start-period=300s --retries=3 \
  CMD curl -fsS -m 8 -d '{"action":"block_count"}' \
      "http://127.0.0.1:${RPC_PORT}" >/dev/null || exit 1

ENTRYPOINT ["/usr/local/bin/init.sh"]
