#!/usr/bin/env bash
set -euo pipefail

apk add --no-cache \
  python3-dev

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
generic_dir="${script_dir}/../../../generic"

"${generic_dir}/install_python.sh"
