#!/usr/bin/env bash
set -euo pipefail

apk add --no-cache \
  docker-cli \
  docker-cli-compose \
  docker-cli-buildx

# Ensure docker group exists for runtime membership
if ! getent group docker >/dev/null 2>&1; then
  addgroup -S docker
fi
