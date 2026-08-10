# Running an XRO node

For a brand new node. If you already have one, see `UPGRADE.md` instead.

**Current release: 2.0.0-R2.** A new node syncs from scratch in about 45 minutes,
unattended. No snapshot needed.

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

Anywhere is fine. Whatever you pick goes in the `-v` line below.

## 2. Start it

```
docker run -d --name xro --restart unless-stopped \
  -p 0.0.0.0:8075:8075 \
  -p 127.0.0.1:8076:8076 \
  -p 127.0.0.1:8078:8078 \
  -e prefix="xro_" \
  -e name="RaiblocksOne" \
  -e account="xro_3oh6tp9b8y65w1fzp3aaxgebptkdhnrziiqaairqfhzkcntiwn1r97cgzikp" \
  -e source="D5E4D58E937883E01BFB0508EB989B6A4B7D31F842E8443176BFF255350E5018" \
  -e work="9da7e03b2a2ec54b" \
  -e signature="FBB7588466EAA76196181C3CDF249178BAC70929E28AABBD5DE284362A34899AB4C972A232824067F439E89F2672B792105D3A55763B852FD21967EC7957260D" \
  -e peering="peering.raione.cc" \
  -e peering_port=8075 \
  -e RPC_PORT=8076 \
  -e WS_PORT=8078 \
  -v /data/nodes/xro:/root \
  caltru1sm/xro-node:latest
```

**Change `-v /data/nodes/xro:/root` if your folder is elsewhere.** That's the only line
you need to touch — the rest is identical for everyone, and every `-e` value is required.

Note the ports: **8075 is published to the world, 8076 and 8078 are bound to localhost
only.** Keep it that way. Those two are the RPC and websocket, and they should not be
reachable from the internet.

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

Should say `"node_vendor": "Nano xro-node-2.0.0-R2"`.

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

**`name: unbound variable`** — you left out one of the `-e` values. They're all required.

**No peers after a few minutes** — check port 8075 is actually forwarded and open.
`docker logs xro | grep Peers` should show a non-zero count.

**Stuck at 156,000 blocks and not moving for over 30 minutes** — that shouldn't happen on
R2. Check `docker logs xro` for errors and say something in Discord.

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
