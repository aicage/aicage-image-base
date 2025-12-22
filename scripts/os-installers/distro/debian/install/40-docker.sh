#!/usr/bin/env bash
set -euo pipefail

export GNUPGHOME="$(mktemp -d)"

# keyring
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# repo
. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

# install
apt-get update
apt-get install -y --no-install-recommends \
  docker-ce-cli \
  docker-compose-plugin \
  docker-buildx-plugin

# cleanup
rm -rf "${GNUPGHOME}"
