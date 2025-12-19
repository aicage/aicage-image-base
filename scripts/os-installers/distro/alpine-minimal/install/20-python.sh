#!/usr/bin/env bash
set -euo pipefail

apk add --no-cache \
  py3-pip \
  python3 \
  py3-virtualenv \
  python3-dev

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
generic_dir="${script_dir}/../../../generic"

"${generic_dir}/install_python.sh"
