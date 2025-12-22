#!/usr/bin/env bash
set -euo pipefail

apk add --no-cache \
  docker-cli \
  docker-cli-compose \
  docker-cli-buildx
