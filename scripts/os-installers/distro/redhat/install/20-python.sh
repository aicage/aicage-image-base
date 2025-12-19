#!/usr/bin/env bash
set -euo pipefail

dnf -y install \
  pipx \
  python3 \
  python3-pip \
  python3-virtualenv \
  python3-devel

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
generic_dir="${script_dir}/../../../generic"

"${generic_dir}/install_python.sh"
