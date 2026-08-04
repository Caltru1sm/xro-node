#!/bin/bash
# XRO node entrypoint.
#
# Differences from the upstream yxse/nan init.sh, both deliberate:
#
#  1. `exec` the node. Upstream ran it as a child of bash (PID 1), so SIGTERM
#     was never forwarded, `docker stop` always timed out, and every restart
#     was a SIGKILL (observed exit code 137). LMDB survives that, but a clean
#     shutdown is strictly better and costs nothing.
#
#  2. Fail closed on config generation. Upstream wrote a default config-rpc.toml
#     with address "::ffff:0.0.0.0" and enable_control = true whenever the file
#     was absent. On a node holding a wallet that is a wallet-drain default: lose
#     the TOML in a restore and the node silently comes back with a
#     control-enabled RPC on every interface. Defaults here are loopback with
#     control disabled; a wider bind must be opted into explicitly via RPC_BIND.

set -euo pipefail

dir="/root/${name}"
mkdir -p "$dir"
cd "$dir"

# Safe defaults; override explicitly in compose when a wider bind is intended
# (e.g. RPC_BIND=::ffff:172.17.0.1 to reach the node from a reverse proxy).
RPC_BIND="${RPC_BIND:-::ffff:127.0.0.1}"
WS_BIND="${WS_BIND:-::ffff:127.0.0.1}"
ENABLE_CONTROL="${ENABLE_CONTROL:-false}"

if [ ! -f config-node.toml ]; then
  cat > config-node.toml <<EOF
[node]
enable_voting = true
work_threads = 0
receive_minimum = "10000"

[node.websocket]
address = "${WS_BIND}"
enable = true
port=${WS_PORT}

[rpc]
enable=true
EOF
  echo "init: generated config-node.toml (websocket bind ${WS_BIND})"
else
  echo "init: config-node.toml exists, left untouched"
fi

if [ ! -f config-rpc.toml ]; then
  cat > config-rpc.toml <<EOF
port=${RPC_PORT}
address = "${RPC_BIND}"
enable_control = ${ENABLE_CONTROL}
EOF
  echo "init: generated config-rpc.toml (bind ${RPC_BIND}, enable_control ${ENABLE_CONTROL})"
else
  echo "init: config-rpc.toml exists, left untouched"
fi

exec nan_node --daemon
