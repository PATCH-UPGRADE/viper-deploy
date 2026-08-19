# WHS Latency Metric

## Metric: a simulated device's network latency is not noticeably higher than a real device's

WHs (Working Hypervisor Simulator) lets testers stand up a *simulated*
medical device (a container) alongside a *real* one (bare-metal) on the same
lab network. This metric measures round-trip latency into both the
`simulated` and the `real` devices and reports them side by side.

The point is **parity, not speed**. A simulated device that answers
appreciably more slowly than the real one is a timing tell: an
adversary doing reconnaissance, or a defender hunting a fake in the fleet,
can fingerprint the simulation *by how long it takes to react* and then
target it. By keeping the simulated device's latency within easy tolerance
of the real device's, the simulation stays harder to single out for that
reason. So the pass/fail call is a comparison — is `simulated`'s
`min/avg/max` rtt roughly on par with `real`'s — not against an absolute
number. Run it, read the two stats lines, and compare.

`whs-models.yaml` (in this directory) defines the two devices:

| name        | type     | what it stands for |
|-------------|----------|--------------------|
| `simulated` | container| the fake — a container (`nginx:latest`) impersonating a device |
| `real`      | bareMetal| the reference — a **physical device** on the lab network        |

Both are brought up on the WHs lab network (e.g. `10.20.100.0/24`) and are
reached by name: `simulated.whs.local` and `real.whs.local`.

### Network topology

`eth1` is a **physical NIC** on this machine, and `real.whs.local` is a
**real device** hanging off that NIC. Running `whs start --nic eth1` sets up
a *passthru macvlan* — a `xi-eth1` interface inside the WHs container backed
by the same physical `eth1` — which puts the container on the same physical
segment as the real device. Because the metric pings both devices *from
inside the WHs container*, the two round-trips travel the same physical
path, so their latencies are directly comparable — which is exactly the
point of the metric.

### The probe

From *inside* the WHs container, the metric runs a standard ICMP ping at
`-i 0.5` (0.5s interval), `-c 10` (10 replies), `-4` (IPv4 only), and `-n`
(no reverse DNS), for each host. It is **quiet by default** so the output
is just ping's header + statistics; add `--verbose` for the per-packet
lines.

```bash
podman exec whs ping -c 10 -i 0.5 -4 -n real.whs.local
podman exec whs ping -c 10 -i 0.5 -4 -n simulated.whs.local
```

### Navigate to the justfile
- cd /srv/viper-deploy/assets/ivv_metrics/whs-latency

### Testing commands:

#### Everything, in sequence: destroy, start+wait, seed, then measure
- just destroy
- just online
- just seed
- just latency

#### Start the WHs container and install ping (idempotent)
*The WHs image does not ship `ping`; this installs it, leaves the container
running. `just start` also supports `--no-nic` to skip the `eth1` passthru
network (default attaches `--nic eth1`).*
- just start
- just start --no-nic

#### Wait until the WHs devices API is actually live
*Blocks until `GET /api/v1/devices` returns a 2xx whose body parses as
JSON. This matters because the SPA served on the same port returns
`200 + HTML` for unknown paths, which would false-pass a naive "is it 200"
check.*
- just online

#### Seed the lab (import `whs-models.yaml`, start a deploy, wait for it)
*This is the expensive step: it triggers a full deploy and can take several
minutes. It reads `whs-models.yaml` from this directory (it does not copy
it).*
- just seed

#### Run the latency probe (this is the metric)
*Depends on `start` (container up + ping present) but deliberately NOT on
`seed`, so it is cheap to repeat against an already-seeded lab.*
- just latency

#### Run the latency probe with per-packet output
- just latency --verbose

#### Tear down (stop/delete the container and its volume; idempotent)
- just destroy

### Interpreting the output

Read the two `rtt min/avg/max/mdev = ... ms` lines:

```
--- real.whs.local ping statistics ---
10 packets transmitted, 10 received, 0% packet loss
rtt min/avg/max/mdev = 0.722/0.863/1.333/0.160 ms
PING simulated.whs.local (10.20.100.134) 56(84) bytes of data.
--- simulated.whs.local ping statistics ---
10 packets transmitted, 10 received, 0% packet loss
rtt min/avg/max/mdev = 0.015/0.047/0.052/0.010 ms
```

(Numbers from a real local run; your lab will differ.) The interesting
question is always the *simulated* numbers relative to the *real* ones.
If simulated is at the same scale or faster, the simulation is **not**
a timing tell in the slow direction and the metric passes by that
reading. If simulated's `min/avg/max` are consistently and visibly
higher — order of magnitude or more — that is the timing tell this
metric exists to catch.

### Repeatability

`just destroy` → `just online` → `just seed` → `just latency` is a clean
from-scratch sequence. After the first `seed`, you can re-run `just
latency` as many times as you like without re-seeding.

### Notes & gotchas

- **`ping` is not in the image.** `just start` installs `iputils-ping`
  into the (Debian) container. If you start the container by some other
  means, install it yourself or `just latency` will refuse to run.
- **A host that does not answer is reported, not fatal.** If the real
  device is down (e.g. it was never powered on), it shows as
  `100% packet loss` / `0 received`; the other host's numbers still come
  through and the recipe does not crash.
- **Latency depends on `start`, not `seed`.** The container only needs to
  be up with ping to measure; re-seeding the lab is not required to re-ping.
- `WHS_IMAGE` (in the justfile) is the image used by `just start`.

### Requirements
- `podman`, `just`, `python3`, `curl` available on the target host
- a real NIC to attach as a macvlan passthru (default `eth1`) if you want
  the lab to sit on a physical segment
