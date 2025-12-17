#!/usr/bin/env bash
set -euo pipefail

apk add --no-cache \
  apache-ant \
  maven \
  protobuf

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
generic_dir="${script_dir}/../../../generic"

"${generic_dir}/install_jdk.sh"
