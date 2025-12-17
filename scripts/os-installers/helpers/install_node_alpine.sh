#!/usr/bin/env bash
set -euo pipefail

# Prefer distro packages on Alpine to avoid missing musl tarballs.
apk add --no-cache nodejs-current npm

npm config set prefix /usr/local
