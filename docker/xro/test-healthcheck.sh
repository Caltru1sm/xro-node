#!/usr/bin/env bash
# Assert the healthcheck probes the address the node is actually bound to.
#
# Usage: docker/xro/test-healthcheck.sh <image>
#
# The regression this guards is not hypothetical. Before healthcheck.sh existed
# the Dockerfile probed http://127.0.0.1:${RPC_PORT} unconditionally, so a node
# binding one specific interface - the correct configuration under
# network_mode: host, where no `-p 127.0.0.1:8076:8076` publish layer exists to
# keep RPC off the LAN - was reported unhealthy forever while serving perfectly.
# A live XRO node bound to ::ffff:172.17.0.1 hit exactly that.
#
# Resolution is checked by putting a fake curl ahead of the real one on PATH and
# reading back the URL the script chose. That keeps the test hermetic: no node,
# no network, no waiting on a start-period, and it fails for one reason only.
set -euo pipefail

IMG=${1:?usage: test-healthcheck.sh <image>}
fail=0

# The image must actually be wired to the script, not just ship it. A correct
# healthcheck.sh that nothing invokes would pass every resolution case below.
probe_cmd=$(docker inspect "$IMG" --format '{{json .Config.Healthcheck.Test}}')
echo "HEALTHCHECK: ${probe_cmd}"
if [[ "$probe_cmd" != *healthcheck.sh* ]]; then
  echo "FAIL: image HEALTHCHECK does not invoke healthcheck.sh" >&2
  fail=1
fi
if ! docker run --rm --entrypoint test "$IMG" -x /usr/local/bin/healthcheck.sh; then
  echo "FAIL: /usr/local/bin/healthcheck.sh is missing or not executable" >&2
  fail=1
fi

# addr written into config-rpc.toml -> URL the probe must request.
check() {
  local addr=$1 want=$2 got
  # `|| got=<error>` matters: under `set -e` a failing command substitution
  # aborts the whole script, so a missing healthcheck.sh would stop at the first
  # case and hide every other result. Collect and report them all instead.
  got=$(docker run --rm -i -e ADDR="$addr" --entrypoint sh "$IMG" -s <<'INNER' 2>/dev/null || echo '<probe errored>'
set -e
mkdir -p /root/RaiblocksOne /fake
printf 'address = "%s"\n' "$ADDR" > /root/RaiblocksOne/config-rpc.toml
cat > /fake/curl <<'STUB'
#!/bin/sh
for a in "$@"; do case "$a" in http*) echo "$a";; esac; done
STUB
chmod +x /fake/curl
PATH=/fake:$PATH
name=RaiblocksOne RPC_PORT=8076 exec /usr/local/bin/healthcheck.sh
INNER
)
  if [[ "$got" == "$want" ]]; then
    printf '  ok    %-22s -> %s\n' "$addr" "$got"
  else
    printf '  FAIL  %-22s -> %s (want %s)\n' "$addr" "$got" "$want" >&2
    fail=1
  fi
}

echo "address resolution:"
# The case that broke a real node: a specific interface must be probed there,
# not on loopback.
check '::ffff:172.17.0.1' 'http://172.17.0.1:8076'
# A wildcard bind answers on loopback, which is the cheapest route from inside.
check '::ffff:0.0.0.0'    'http://127.0.0.1:8076'
check '::ffff:127.0.0.1'  'http://127.0.0.1:8076'
# Addresses written without the v4-mapped prefix still work.
check '10.1.2.3'          'http://10.1.2.3:8076'
# A real IPv6 literal needs brackets or curl misparses the port.
check 'fd00::1'           'http://[fd00::1]:8076'

# First start: the probe runs inside the start-period, before init.sh has
# written any config. It must fall back rather than error.
echo "no config yet:"
got=$(docker run --rm -i --entrypoint sh "$IMG" -s <<'INNER' 2>/dev/null || echo '<probe errored>'
set -e
mkdir -p /fake
cat > /fake/curl <<'STUB'
#!/bin/sh
for a in "$@"; do case "$a" in http*) echo "$a";; esac; done
STUB
chmod +x /fake/curl
PATH=/fake:$PATH
name=RaiblocksOne RPC_PORT=8076 exec /usr/local/bin/healthcheck.sh
INNER
)
if [[ "$got" == 'http://127.0.0.1:8076' ]]; then
  printf '  ok    %-22s -> %s\n' '(missing config)' "$got"
else
  printf '  FAIL  %-22s -> %s (want http://127.0.0.1:8076)\n' '(missing config)' "$got" >&2
  fail=1
fi

[ "$fail" -eq 0 ] && echo "healthcheck OK" || { echo "healthcheck FAILED" >&2; exit 1; }
