#!/usr/bin/env bash
set -euo pipefail

apt-get install -y --no-install-recommends \
  ant \
  maven \
  protobuf-compiler

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
generic_dir="${script_dir}/../../../generic"

"${generic_dir}/install_jdk.sh"
