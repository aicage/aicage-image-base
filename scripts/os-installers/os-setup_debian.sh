#!/usr/bin/env bash
set -euo pipefail

apt-get update
apt-get install -y --no-install-recommends \
  bash \
  bash-completion \
  build-essential \
  ca-certificates \
  curl \
  git \
  gnupg \
  jq \
  locales \
  nano \
  openssh-client \
  pipx \
  python3 \
  python3-pip \
  python3-venv \
  gosu \
  ripgrep \
  tar \
  tini \
  unzip \
  xz-utils \
  zip
rm -rf /var/lib/apt/lists/*

locale-gen en_US.UTF-8

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
helpers_dir="${script_dir}/helpers"
"${helpers_dir}/install_node.sh"
"${helpers_dir}/install_python.sh"
