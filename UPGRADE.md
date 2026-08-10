# Upgrading your XRO node

Keeps your existing ledger. No resync, no snapshot needed, nothing in your data
directory is touched.

**Current release: 2.0.0-R2.** New nodes sync from scratch in ~45 minutes (this was
broken before R2), and node bandwidth is roughly 9x lower than 2.0.0.

## 1. Pull the new image

```
docker pull caltru1sm/xro-node:latest
```

## 2. Stop and remove the old container

```
docker stop xro && docker rm xro
```

Your ledger lives in the mounted folder, not the container. Removing the container
does not delete it.

## 3. Start it again on the new image

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

**If your data folder is somewhere else, change `-v /data/nodes/xro:/root` to match.**
That one path is the only thing you must get right — everything else above is the same
for everyone.

## 4. Check it's running

```
docker logs --tail 20 xro
curl -d '{"action":"block_count"}' http://127.0.0.1:8076
```

`count` and `cemented` should be climbing and eventually match. If your node had fallen
behind, it catches up on its own — usually a few minutes.

Confirm you're on the new version:

```
curl -d '{"action":"version"}' http://127.0.0.1:8076
```

Should say `"node_vendor": "Nano xro-node-2.0.0-R2"`.

---

## If something goes wrong

Roll back by running the same command with `yxse/nan` at the end instead of
`caltru1sm/xro-node:2.0.0-R1`. Your ledger is untouched either way.

**`name: unbound variable`** — you left out `-e name="RaiblocksOne"`. It's required now.
The old image let it slide and quietly used the wrong folder.

**Node starts but no peers** — check port 8075 is still forwarded in your router.

---

## Optional: check your RPC isn't exposed

Upgrading does not change your existing config files, so this is worth a look:

```
cat /data/nodes/xro/RaiblocksOne/config-rpc.toml
```

If it says `address = "::ffff:0.0.0.0"` and `enable_control = true`:

- Running with `-p 127.0.0.1:8076:8076` as above? You're fine, Docker keeps it off the
  internet. Nothing to do.
- Running with `--network host`? Then your RPC is open on every interface with control
  enabled. Change `address` to `"::ffff:127.0.0.1"` and `enable_control` to `false`, then
  restart the container.
