# TimescaleDB (TSL edition) + timescaledb_toolkit packaged as a CloudNativePG
# extension image, mounted read-only into the stock CNPG operand via ImageVolume.
#
# Why we build this ourselves: the official ghcr.io/cloudnative-pg/timescaledb-oss
# image is the Debian +dfsg repack with the TSL code stripped (CNCF artifacts may
# not carry TSL). Blocky's `queryLog.type: timescale` calls add_retention_policy(),
# which is TSL-only - on an Apache build the function exists but fails at call
# time. So we need the full packagecloud packages.
#
# The builder stage IS the operand image, so the extension is compiled against
# the exact PostgreSQL major, Debian release and architecture it will run on.
# renovate: datasource=docker depName=ghcr.io/cloudnative-pg/postgresql
ARG BASE=ghcr.io/cloudnative-pg/postgresql:18-minimal-trixie

FROM ${BASE} AS builder

ARG PG_MAJOR=18
# Debian codename must match the operand image (trixie -> ~debian13 packages)
ARG DISTRO=trixie
# renovate: datasource=github-releases depName=timescale/timescaledb
ARG TS_VERSION=2.29.2
# renovate: datasource=github-releases depName=timescale/timescaledb-toolkit
ARG TOOLKIT_VERSION=1.25.0

USER 0

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg; \
    curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey \
      | gpg --dearmor -o /usr/share/keyrings/timescale.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/timescale.gpg] https://packagecloud.io/timescale/timescaledb/debian/ ${DISTRO} main" \
      > /etc/apt/sources.list.d/timescaledb.list; \
    apt-get update; \
    # The loader package carries timescaledb.control; the version-pinned package
    # carries timescaledb-tsl-<ver>.so. Both are required. Deliberately NOT
    # timescaledb-2-postgresql-N, which bundles every 2.23->2.29 build (341MB).
    apt-get install -y --no-install-recommends \
      "timescaledb-2-loader-postgresql-${PG_MAJOR}" \
      "timescaledb-2-${TS_VERSION}-postgresql-${PG_MAJOR}" \
      "timescaledb-toolkit-postgresql-${PG_MAJOR}"; \
    rm -rf /var/lib/apt/lists/*

# CNPG mounts this image at /extensions/<name> and defaults
# extension_control_path to <mount>/share and dynamic_library_path to <mount>/lib.
# Both extensions share one flat layout - their filenames do not collide - so no
# path overrides are needed on the Cluster.
FROM scratch

ARG PG_MAJOR=18

COPY --from=builder /usr/lib/postgresql/${PG_MAJOR}/lib/timescaledb*         /lib/
COPY --from=builder /usr/share/postgresql/${PG_MAJOR}/extension/timescaledb* /share/extension/

USER 65532:65532
