#!/usr/bin/env bash
set -euo pipefail

. /etc/os-release

dnf config-manager addrepo \
  --from-repofile="https://download.docker.com/linux/${ID}/docker-ce.repo"

dnf -y install \
  docker-ce-cli \
  docker-buildx-plugin \
  docker-compose-plugin

# Ensure docker group exists for runtime membership
if ! getent group docker >/dev/null 2>&1; then
  groupadd -r docker
fi
