#!/usr/bin/env bash
set -euo pipefail

dnf -y makecache

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
install_dir="${script_dir}/install"

for install_script in "${install_dir}"/*.sh; do
  "${install_script}"
done

dnf clean all
