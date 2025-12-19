#!/bin/sh
set -eu

apk add --no-cache bash

script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
install_dir="${script_dir}/install"

for install_script in "${install_dir}"/*.sh; do
  echo "Running: ${install_script}"
  bash "${install_script}"
done
