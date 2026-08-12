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
- `03_forensics/env-*.txt` — compiler build, kernel, architecture, container
  id. Expected to **differ**.

Parity check, once the Proxmox capture exists:

```sh
diff 03_forensics/output-04-multiply-bug.txt /path/to/proxmox/output-04-multiply-bug.txt
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

### proxmox-debian — not yet captured

These are the four fields Runbook Stage 1 asks for. They are recorded as
blanks rather than omitted, so the gap is visible:

| Field | Value |
|---|---|
| VMID | _not yet recorded_ |
| Bridge | _not yet recorded_ |
| IP | _not yet recorded_ |
| Tailscale hostname | _not yet recorded_ |

Note on reachability: the tailnet currently carries `macbook-pro-2`,
`nikolass-mac-mini`, and `tailscale-router`. No Proxmox host or Debian guest
is on it yet, so the guest needs Tailscale installed on it directly, or the
existing router node needs to advertise the Proxmox subnet. No ACL change is
required for this lab; the capture is a local `make` on that guest, and only
the resulting text files need to come back.

To capture there:

```sh
cd lab
make forensics CAPTURE_HOST=proxmox-debian
```

## Why `-std=cobol85`

It is period-appropriate and rejects modern syntax that would defeat the
exercise. It also forced an honest design decision: `ORGANIZATION IS LINE
SEQUENTIAL` is a post-1985 extension, so the lab uses record-sequential card
images with no line delimiters instead — which is what a 1964 deck actually
was, and which turns the column-shift lesson into a real experiment rather
than a thought experiment.
