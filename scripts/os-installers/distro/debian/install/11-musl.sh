#!/usr/bin/env bash
set -euo pipefail

apt-get install -y --no-install-recommends \
  linux-libc-dev \
  musl-tools
