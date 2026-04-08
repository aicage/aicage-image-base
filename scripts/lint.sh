#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

# YAML
yamllint .

# Markdown
pymarkdown \
  --config .pymarkdown.json scan \
  --recurse \
  --exclude '**/.venv*/**' \
  .

# Shellcheck
mapfile -t shell_scripts < <(find . -type f -name '*.sh' -not -path './.venv/*' | sort)

if [[ ${#shell_scripts[@]} -gt 0 ]]; then
  echo "Validate shell scripts with bash -n"
  for script in "${shell_scripts[@]}"; do
    bash -n "${script}"
  done

  echo "Run shellcheck"
  shellcheck -x "${shell_scripts[@]}"
fi

# Schemas
check-jsonschema \
  --schemafile validation/config.schema.json \
  config.yml

check-jsonschema \
  --schemafile validation/base.schema.json \
  bases/*/base.yml

check-jsonschema \
  --schemafile validation/base-build.schema.json \
  bases/*/base-build.yml
