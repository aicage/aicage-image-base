#!/usr/bin/env bats

@test "imagemagick present" {
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
      if command -v magick >/dev/null; then
        magick -size 1x1 xc:red txt:- | grep -q " red$"
      else
        convert -size 1x1 xc:red txt:- | grep -q " red$"
      fi
    '
  [ "$status" -eq 0 ]
}
