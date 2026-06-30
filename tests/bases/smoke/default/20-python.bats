#!/usr/bin/env bats

@test "python toolchain present" {
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    --env AICAGE_HOST_IS_LINUX=true \
    --env AICAGE_UID=1234 \
    --env AICAGE_GID=2345 \
    --env AICAGE_HOST_USER=demo \
    --env AICAGE_HOME=/home/demo \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      command -v python3
      command -v pipx
      command -v python3-config
      python3 - <<'"'"'PY'"'"'
print("ok-python")
PY
      python3 -m venv /tmp/python-smoke
      /tmp/python-smoke/bin/python - <<'"'"'PY'"'"'
print("ok-venv")
PY
      python3-config --includes | grep -q -- "-I"
    '
  [ "$status" -eq 0 ]
}
