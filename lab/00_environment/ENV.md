# Environment

GnuCOBOL runs in a container rather than from Homebrew, because the evidence
has to reproduce on a Proxmox guest and in a cloud runner, not just on one
laptop. The container is the source of truth; a host `cobc` is a convenience
path via `make forensics RUNNER=local`.

## What is pinned, and why

The base image is pinned by **OCI index digest** rather than by tag:

```
debian:bookworm-slim@sha256:abd67ffcfa541b485a3dff59865ab629aa048a6c613e639d36e7456b0b229241
```

An index digest resolves correctly on both arm64 (the macOS dev host) and
amd64 (the Proxmox guest), so one pin covers both architectures. A tag would
let the base drift between the two captures and silently invalidate any claim
that their output matches.

The compiler package is **not** version-pinned. Debian applies arch-specific
binNMU suffixes — arm64 resolves `gnucobol3` to `3.1.2-5+b1` — so an exact pin
that works on one architecture can fail to resolve on the other. The
Dockerfile asserts the `3.1.2` series instead and fails the build loudly if
apt ever hands over something else.

bookworm also offers `gnucobol4`, but that is `4.0~early~20200606`, a
pre-release. The stable 3.1.2 series is the right choice for a lab whose
entire point is trustworthy output.

## Output parity

`cobc --version` differs between a Homebrew build and a Debian container
build. If that banner landed in the evidence files, the two environments could
never produce matching output and "parity" would be unfalsifiable. So:

- `03_forensics/output-*.txt` — program behaviour only. Expected to be
  **byte-identical** across environments.
- `03_forensics/env-*.txt` — compiler build, kernel, architecture. Expected
  to **differ**.

Parity check, captured 2026-08-12. All six `output-*.txt` files matched
byte-for-byte between `macos-docker` and `proxmox-debian`. The `env-*.txt`
files differed in kernel, architecture, and the compiler's `Built` timestamp
(arch-specific binNMU), which is the split working as designed:

```sh
for f in 03_forensics/output-*.txt; do
    diff -q "$f" "/tmp/proxmox-forensics/$(basename "$f")" && echo "match $(basename "$f")"
done
```

## Captured environments

### macos-docker — captured

| | |
|---|---|
| Host | Apple Silicon, Docker Desktop 29.7.2 |
| Kernel in container | Linux 6.12.76-linuxkit aarch64 |
| Compiler | GnuCOBOL 3.1.2.0, built Sep 19 2022, C version 12.2.0 |
| Flags | `-x -std=cobol85 -Wall` |

Full detail in `../03_forensics/env-macos-docker.txt`.

### proxmox-debian — captured

| | |
|---|---|
| Host | Proxmox VM 101 `debian-test`, `172.16.25.89`, user `cobol` (`ssh cobol-lab`) |
| Kernel in container | Linux 6.12.94+deb13-amd64 x86_64 |
| Compiler | GnuCOBOL 3.1.2.0, built Sep 19 2022, C version 12.2.0 |
| Flags | `-x -std=cobol85 -Wall` |

Full detail in `../03_forensics/env-proxmox-debian.txt`. The `Built` line is
four hours later than the macOS capture because Debian's `3.1.2-5+b1` is an
arch-specific rebuild; the series assertion in the Dockerfile still holds.

#### Access path

Verified 2026-08-12. The dev host and the hypervisor are at **different
physical sites**, on different subnets behind different public IPs, so
Tailscale is not a convenience here — it is the only route. Plain LAN SSH is
not an option.

```
macbook-pro-2          LXC 102                     pve-node-1         VM 101
10.0.0.164/24    ──►   tailscale-router       ──►  172.16.25.50  ──►  debian-test
                       100.89.133.26               hypervisor         172.16.25.89
                       advertises 172.16.25.0/24                      ssh cobol-lab
```

| | |
|---|---|
| Hypervisor | `pve-node-1`, `172.16.25.50`, Debian 13 trixie, pve-manager 9.2.5 |
| Subnet router | LXC 102 `tailscale-router`, `100.89.133.26`, advertises `172.16.25.0/24` |
| Route status | Approved and serving — present in Tailscale `PrimaryRoutes`, not merely `AllowedIPs` |
| Path quality | Direct, not DERP-relayed: ~17ms via `24.8.197.82:41641` |
| Guest login | user `cobol`, key `id_ed25519_cobol_lab`, `SHA256:b5BD62bL1eqzcwBG763cMaV1h3/Q39iO/nMBkC6s3Zc` |

The subnet router is an LXC container running **on** the Proxmox host, not a
separate appliance and not the hypervisor itself. Because its route is already
approved, **no Tailscale ACL or admin-console change is required** — the guest
becomes reachable as a side effect of the `/24` route the moment it has an
address on `vmbr0`.

Installing Tailscale on the guest directly would be an upgrade rather than a
prerequisite: it would make the guest individually ACL-able instead of
reachable as a side effect of a whole-subnet route, and it would survive the
LXC router being down.

#### Runbook Stage 1 fields

| Field | Value |
|---|---|
| VMID | `101` (`debian-test`) |
| Bridge | `vmbr0`, the same bridge as `172.16.25.50/24` |
| IP | `172.16.25.89` (static on `ens18`/`vmbr0`) |
| Tailscale hostname | _n/a — reached via subnet route, not as a tailnet node_ |

#### Recapture

The guest is provisioned: Docker 26.1.5, git, make, rsync, user `cobol` in the
`docker` group, key `id_ed25519_cobol_lab`. The hypervisor still has none of
those tools, which is correct — Debian trixie's packaged `cobc` would not
match the pinned `cobol-lab:3.1.2` image.

From the repo root on the dev host:

```sh
rsync -az --exclude .git ./ cobol-lab:~/COBOL/
ssh cobol-lab 'cd ~/COBOL/lab && make forensics CAPTURE_HOST=proxmox-debian'
rsync -az cobol-lab:~/COBOL/lab/03_forensics/ /tmp/proxmox-forensics/
```

Artifacts land in `/tmp/proxmox-forensics/` rather than back over
`03_forensics/`, so the macOS capture survives to be compared against. Then run
the parity check above. `env-proxmox-debian.txt` is the one file that should
be copied back into `03_forensics/` when provenance changes.

## Why `-std=cobol85`

It is period-appropriate and rejects modern syntax that would defeat the
exercise. It also forced an honest design decision: `ORGANIZATION IS LINE
SEQUENTIAL` is a post-1985 extension, so the lab uses record-sequential card
images with no line delimiters instead — which is what a 1964 deck actually
was, and which turns the column-shift lesson into a real experiment rather
than a thought experiment.
