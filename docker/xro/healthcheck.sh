#!/bin/sh
# Probe the RPC at whatever address it is actually bound to.
#
# The obvious healthcheck - curl http://127.0.0.1:${RPC_PORT} - is wrong for any
# node that binds a specific interface. Under `network_mode: host` that is the
# correct thing to do: binding a single host interface is what keeps the RPC off
# the LAN, since there is no `-p 127.0.0.1:8076:8076` publish layer to do it.
# A node bound to, say, the docker bridge address is perfectly healthy and
# serving, but a probe aimed at loopback gets ECONNREFUSED and the container is
# reported unhealthy forever. That misreads a correct configuration as a fault.
#
# So read the bind out of config-rpc.toml rather than assuming it. The config is
# the authority: init.sh generates it on first start and never rewrites it, so
# it reflects what the node is really listening on.
set -eu

CONFIG="/root/${name:-Nano}/config-rpc.toml"
PORT="${RPC_PORT:-8076}"

# Fall back to loopback when the config has not been written yet - on the very
# first start the probe runs inside the start-period, before the node has
# generated anything.
addr=""
if [ -f "$CONFIG" ]; then
  addr=$(sed -n 's/^[[:space:]]*address[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' "$CONFIG" | head -n1)
fi
[ -n "$addr" ] || addr="127.0.0.1"

# Strip the v4-mapped prefix the node writes ("::ffff:172.17.0.1"). curl wants
# a bare address, and the mapped form would otherwise be treated as IPv6 below.
addr=${addr#::ffff:}

# A wildcard bind answers on loopback, and loopback is the cheapest route from
# inside the container. Anything else is a specific interface: probe it directly.
case "$addr" in
  0.0.0.0|::|"") addr="127.0.0.1" ;;
esac

# Bracket a real IPv6 literal for the URL.
case "$addr" in
  *:*) addr="[${addr}]" ;;
esac

exec curl -fsS -m 8 -o /dev/null -d '{"action":"block_count"}' "http://${addr}:${PORT}"
