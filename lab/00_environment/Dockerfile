# GnuCOBOL runtime for the 1964 insurance renewal batch lab.
#
# The base is pinned by OCI *index* digest rather than by tag, so the same
# reference resolves correctly on arm64 (macOS dev host) and amd64 (Proxmox
# guest). Tag pinning would let the base drift between the two captures and
# silently invalidate the output-parity claim in ENV.md.
FROM debian:bookworm-slim@sha256:abd67ffcfa541b485a3dff59865ab629aa048a6c613e639d36e7456b0b229241

# bookworm ships gnucobol3 (3.1.2, stable) and gnucobol4 (a 2020 "early"
# pre-release). We want the stable series.
#
# The version is deliberately not hard-pinned: Debian applies arch-specific
# binNMU suffixes (arm64 resolves 3.1.2-5+b1), so an exact pin that works on
# one arch can fail to resolve on the other. Instead we assert the series and
# fail the build loudly if apt ever hands us something other than 3.1.2.
ARG COBOL_SERIES=3.1.2

RUN apt-get update \
 && apt-get install -y --no-install-recommends gnucobol3 \
 && rm -rf /var/lib/apt/lists/* \
 && cobc --version | head -1 \
 && cobc --version | head -1 | grep -q "$COBOL_SERIES"

WORKDIR /lab
