# Running an XRO node

For a brand new node. If you already have one, see `UPGRADE.md` instead.

**Current release: 2.0.3.** A new node syncs from scratch in about 45 minutes,
unattended. No snapshot needed.

The image is multi-architecture — the same tag works on an x86 box, a Raspberry
Pi 4/5 or CM5, an Oracle Ampere A1, or Graviton. Docker picks the right one on
pull; there is no separate arm64 tag to hunt for.

---

## What you need

- **Docker**
- **Port 8075 open** — forwarded in your router and allowed by your firewall. This is
  the only port that needs to be reachable from outside.
- **~2 GB of disk** for the ledger, plus room to grow.
- Roughly **150 GB/month** of bandwidth at default settings. See the bottom if that's
  tight.

---

## 1. Make a folder for the ledger

```
mkdir -p /data/nodes/xro
```

Whatever you pick goes in the `-v` line below. Pick something on ordinary
writable storage, and check it is before you commit to it:

```
df -h /data/nodes/xro
```

On an immutable-root system — ZimaOS, Fedora Silverblue, Talos — `/` is mounted
read-only and this path is the wrong choice twice over. Docker can't create it,
so the container never starts; and on the ones that do let it through, `/data`
often sits on an overlay that an OS update resets, taking the ledger with it and
resyncing from genesis with no warning. Use the box's persistent volume instead
— on ZimaOS that's `/DATA`, so `/DATA/AppData/xro/data`.

## 2. Start it

```
docker run -d --name xro --restart unless-stopped \
  -p 0.0.0.0:8075:8075 \
  -p 127.0.0.1:8076:8076 \
  -p 127.0.0.1:8078:8078 \
  -v /data/nodes/xro:/root \
  caltru1sm/xro-node:latest
```

That's the whole thing. **Change `-v /data/nodes/xro:/root` if your folder is elsewhere**
— it's the only line you need to touch.

XRO's network identity is baked into the image from 2.0.1 onward, so the ten `-e`
values older guides listed are no longer required. They are still honoured if you pass
them, and the node re-validates whatever ends up in effect: if the genesis it computes
isn't XRO's, it refuses to start rather than coming up quietly on the wrong network.

Note the ports: **8075 is published to the world, 8076 and 8078 are bound to localhost
only.** Keep it that way. Those two are the RPC and websocket, and they should not be
reachable from the internet.

Prefer Compose? `docker/xro/docker-compose.yml` in this repo is the same setup — drop it
in a folder, `mkdir -p ./data`, and `docker compose up -d`.

## 3. Leave it alone for 45 minutes

```
docker logs -f xro
```

You'll see the block count climb. It is normal for it to slow down noticeably somewhere
around 156,000 blocks and sit there for fifteen or twenty minutes — that's the node
untangling a chain of dependencies. **Don't restart it.** It picks up speed again on its
own and finishes.

Check progress any time:

```
curl -d '{"action":"block_count"}' http://127.0.0.1:8076
```

You're done when `count` and `cemented` match and stop moving much. Compare against any
public node or the explorer to confirm you're at the network height.

## 4. Confirm the version

```
curl -d '{"action":"version"}' http://127.0.0.1:8076
```

Should say `"node_vendor": "Nano 2.0.3"`, and `"network_identifier":
"F1604E756A99982DB284E5767804DBAA857FE34720CAB8310CB68DC6AC5F10C7"`. That identifier is
XRO's — if you see a different one, the node is on another network.

---

## Optional: skip the wait with a snapshot

45 minutes of syncing, or a 4 minute download. Both end up in the same place.

Stop the node first if it's running, then:

```
wget https://github.com/Caltru1sm/xro-node/releases/download/xro-node-2.0.0/xro-ledger-625082-2026-08-04.data.ldb.gz
wget https://github.com/Caltru1sm/xro-node/releases/download/xro-node-2.0.0/xro-ledger-625082-2026-08-04.sha256
sha256sum -c xro-ledger-625082-2026-08-04.sha256
mkdir -p /data/nodes/xro/RaiblocksOne
gunzip -c xro-ledger-625082-2026-08-04.data.ldb.gz > /data/nodes/xro/RaiblocksOne/data.ldb
```

Then start the node as above. It'll catch up the remaining blocks in a few minutes.

**Check the sha256.** And note the snapshot is `data.ldb` only — no wallet, no node
identity. Your node generates its own `node_id_private.key` on first start. Never copy
someone else's, or you'll both be on the network as the same node.

---

## If it goes wrong

**`curl: (56) Recv failure: Connection reset by peer` on port 8076** — your node was
created before 2.0.1, when the RPC was generated bound to the container's own loopback.
A published port can't reach that, so the RPC looks dead while the node is actually fine.
Upgrading won't fix it on its own: `config-rpc.toml` is written once and never rewritten,
so the old bind survives every upgrade. Repair it in place, then restart:

```
docker exec xro sed -i 's|^address = .*|address = "::ffff:0.0.0.0"|' /root/RaiblocksOne/config-rpc.toml
docker restart xro
```

2.0.1 and later print a warning at startup when they detect this. The node stays private
either way — `-p 127.0.0.1:8076:8076` binds your machine's loopback, so nothing off-box
can reach the RPC regardless of what the container binds. Keep that `127.0.0.1:` prefix.

**Container sits in `Created` and `docker logs xro` is empty** — it never ran, so there
is nothing to log and the image is not the problem. The reason is on the container
object, not in the logs:

```
docker inspect xro --format '{{.State.Error}}'
```

`mkdir /data: read-only file system` means the ledger path is on a read-only root.
Move the `-v` to persistent storage (see step 1), then `docker rm xro` and recreate it.
A container that fails this way alongside a healthy-looking restart loop from some
other container is easy to misread as an image fault — check `.State.Error` first.

**`name: unbound variable`** — you cleared one of the baked identity values, by passing
an empty `-e name=` or an `--env-file` with a blank entry. Drop the override and let the
image's default stand.

**Container reports `unhealthy` while the node is clearly fine** — on 2.0.2 and earlier
the healthcheck always probed `127.0.0.1`, so binding the RPC to a specific interface
(correct under `network_mode: host`, where there's no `-p 127.0.0.1:` layer to keep it
off the LAN) left the probe knocking on the wrong address forever. 2.0.3 reads the bind
from `config-rpc.toml` instead. Upgrade, or override the probe on the container.

**No peers after a few minutes** — check port 8075 is actually forwarded and open.
`docker logs xro | grep Peers` should show a non-zero count.

**Stuck at 156,000 blocks and not moving for over 30 minutes** — that shouldn't happen on
2.0.3. Check `docker logs xro` for errors and say something in Discord.

**Wrong genesis / no handshake** — check every `-e` value matches exactly. Those derive
the genesis block; one wrong character puts you on a different network and peers will
refuse you.

---

## Bandwidth

Default is roughly 150 GB/month. If that's a problem, and **only once your node is fully
synced**, create `/data/nodes/xro/RaiblocksOne/config-node.toml`:

```toml
[node.bootstrap_server]
max_frontiers_served = 32

[node.bootstrap]
frontier_rate_limit = 1
```

Restart the container. Measured on a live node this takes it to roughly 55 GB/month.

Don't set these while a node is still catching up — they'll slow it down.
