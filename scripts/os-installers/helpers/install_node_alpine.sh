#!/usr/bin/env bash
set -euo pipefail

: "${NODEJS_VERSION:?NODEJS_VERSION is required}"
: "${TARGETARCH:?TARGETARCH is required}"

# Prefer distro packages on Alpine to avoid missing musl tarballs.
apk add --no-cache nodejs npm

npm config set prefix /usr/local
