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

# ---------------------------------------------------------------------------
# Network identity preflight.
#
# The image bakes all ten of these, so in the normal case this block is a
# no-op that prints a summary. It earns its place when someone overrides one:
# every variable here has a fallback, and every fallback is Nano's rather than
# XRO's. Getting one wrong does not crash the node - it produces a node that
# boots cleanly onto the wrong network and reports zero peers, which is a much
# more expensive thing to debug than an abort at startup.
#
# Exits 78 (EX_CONFIG) so the cause is unambiguous in `docker inspect`.
# ---------------------------------------------------------------------------
NANO_GENESIS_SOURCE="E89208DD038FBB269987689621D52292AE9C35941A7484756ECCED92A65093BA"
NANO_GENESIS_ACCOUNT="nano_3t6k35gi95xu6tergt6p69ck76ogmitsa8mnijtpxm9fkcm736xtoncuohr3"

die() {
  echo "=============================================================" >&2
  echo "XRO STARTUP ABORTED" >&2
  echo "  $1" >&2
  echo "" >&2
  echo "  This image ships correct XRO defaults for every network" >&2
  echo "  variable. If you are passing -e or an env_file, remove the" >&2
  echo "  override or correct it. Starting anyway would put this node" >&2
  echo "  on the wrong network." >&2
  echo "=============================================================" >&2
  exit 78
}

for v in prefix source account work signature name peering peering_port RPC_PORT WS_PORT; do
  eval "val=\${${v}:-}"
  [ -n "$val" ] || die "'${v}' is empty or unset (overridden to nothing?)"
done

[ "${source}" != "${NANO_GENESIS_SOURCE}" ] || die "'source' is Nano mainnet's genesis, not XRO's"
[ "${account}" != "${NANO_GENESIS_ACCOUNT}" ] || die "'account' is Nano mainnet's genesis, not XRO's"
[ "${peering}" != "peering.nano.org" ] || die "'peering' points at Nano's seed host, not XRO's"

case "${prefix}" in
  *_) : ;;
  *) echo "init: WARNING prefix '${prefix}' does not end in an underscore" >&2 ;;
esac

# A ledger written under one 'name' is invisible under another - the node just
# starts an empty resync into the new directory. Catch the rename rather than
# letting it look like data loss.
for existing in /root/*/data.ldb; do
  [ -e "$existing" ] || continue
  found="$(basename "$(dirname "$existing")")"
  [ "$found" = "${name}" ] || echo "init: WARNING found an existing ledger in /root/${found} but 'name' is '${name}' - the node will ignore it and sync from scratch" >&2
done

echo "init: XRO network identity OK"
echo "init:   prefix ${prefix} / account ${account}"
echo "init:   data dir /root/${name} / peering ${peering}:${peering_port}"
echo "init:   arch $(uname -m)"

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

# Point the node at XRO's peering host.
#
# `peering` has been passed in the compose file since the original image, but
# nothing ever read it - neither upstream's init.sh nor this one. Without it the
# node falls back to nodeconfig.cpp's default_live_peer_network, which is
# "peering.nano.org": Nano's mainnet seed. A node with no cached peer database
# therefore has no way to find the XRO network at all. It opens connections to
# Nano nodes, fails the handshake against a different genesis, and sits at zero
# realtime peers indefinitely.
#
# NANO_DEFAULT_PEER feeds default_live_peer_network directly, so this works for
# existing installs too, not only ones where config-node.toml is generated fresh.
# An explicit preconfigured_peers list in config-node.toml still overrides it.
if [ -n "${peering:-}" ]; then
  export NANO_DEFAULT_PEER="${peering}"
  echo "init: peering host ${peering}"
else
  echo "init: WARNING no 'peering' set - falling back to ${NANO_DEFAULT_PEER:-peering.nano.org}, which is not XRO"
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
