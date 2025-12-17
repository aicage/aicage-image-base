#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
helpers_dir="${script_dir}/../../../helpers"

"${helpers_dir}/install_node_alpine.sh"
