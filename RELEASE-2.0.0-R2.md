# xro-node 2.0.0-R2

**New nodes can sync from scratch now.** That was broken — a fresh node got to about
156,000 blocks and stopped there forever. This fixes it.

```
docker pull caltru1sm/xro-node:latest
```

Nothing to configure. Keeps your existing ledger if you have one.

---

## If you're starting a new node

Point it at an empty folder and leave it alone. It'll be fully synced in about
45 minutes.

You no longer need a ledger snapshot. The snapshot is still there if you'd
rather not wait — it's a 4 minute download instead of a 45 minute sync — but
it's a shortcut now, not a requirement.

## If you already run a node

Nothing changes for you. Your node was never affected by this; the bug only
ever hit nodes syncing from nothing. Upgrade anyway when convenient — same
pull, stop, remove, run as always, ending in `caltru1sm/xro-node:latest`.

---

## What was wrong

When a node receives a block whose source it doesn't have yet, it parks that
account as "blocked" and notes which other account it's waiting on. A
background pass is supposed to go find those accounts.

That pass skipped any account it saw was already queued — reasonable, except
the queue had filled with roughly 94,000 accounts that were sent funds and
never opened. Being somewhere in a queue that size isn't the same as being
dealt with. So the blocked accounts sat there, the queue never unwound, and
the node stopped growing.

The fix moves those accounts to the front instead of skipping them. Something
being blocked on an account is the strongest possible signal that it's
actually needed.

Tested three times on a fresh empty node, left completely alone:

| | blocks | accounts | time |
|---|---|---|---|
| before | 156,144 | 1,459 | stops forever |
| after | 626,220 | 8,459 | ~45 minutes |

Full sync, matching the network exactly, no restarts, no snapshot.

---

## Still in from R1

The bandwidth fix. If you skipped R1, this is the release where node traffic
drops by roughly 9x — one operator went from 6-8 Mbps down to about 1 Mbps.

If your node is **already synced** and you want to trim it further:

```toml
[node.bootstrap_server]
max_frontiers_served = 32
```

Measured on a live node: upload 0.44 → 0.10 Mbps. Leave it alone while a node
is still catching up.

---

## Rolling back

Same run command with `caltru1sm/xro-node:2.0.0-R1` at the end. Your ledger is
untouched either way.

---

Source: https://github.com/Caltru1sm/xro-node
