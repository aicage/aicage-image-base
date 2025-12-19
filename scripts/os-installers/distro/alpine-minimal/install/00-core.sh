#!/usr/bin/env bash
set -euo pipefail

apk add --no-cache \
  bash \
  libc-utils \
  shadow \
  tini
