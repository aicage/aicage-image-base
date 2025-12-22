#!/usr/bin/env bash
set -euo pipefail

. /etc/os-release

dnf config-manager addrepo \
  --from-repofile="https://download.docker.com/linux/${ID}/docker-ce.repo"

dnf -y install \
  docker-buildx-plugin \
  docker-ce-cli \
  docker-compose-plugin
