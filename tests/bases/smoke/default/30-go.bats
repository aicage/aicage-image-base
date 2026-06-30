#!/usr/bin/env bats

@test "go toolchain present" {
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
      command -v go
      cat >/tmp/hello.go <<'"'"'EOF'"'"'
package main

import "fmt"

func main() {
  fmt.Println("ok-go")
}
EOF
      go run /tmp/hello.go | grep -qx ok-go
    '
  [ "$status" -eq 0 ]
}
