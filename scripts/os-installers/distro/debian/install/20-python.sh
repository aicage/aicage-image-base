#!/usr/bin/env bash
set -euo pipefail

apt-get install -y --no-install-recommends \
  pipx \
  procps \
  python3 \
  python3-pip \
  python3-venv \
  python3-dev

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
generic_dir="${script_dir}/../../../generic"

"${generic_dir}/install_python.sh"
