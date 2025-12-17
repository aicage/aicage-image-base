#!/usr/bin/env bash
set -euo pipefail

apt-get update

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
install_dir="${script_dir}/install"

for install_script in "${install_dir}"/*.sh; do
  bash "${install_script}"
done

apt-get clean
rm -rf /var/lib/apt/lists/*
