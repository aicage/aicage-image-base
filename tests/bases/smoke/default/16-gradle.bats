#!/usr/bin/env bats

@test "gradle present" {
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
      command -v gradle
      mkdir -p /tmp/gradle-smoke
      cat >/tmp/gradle-smoke/settings.gradle <<'"'"'EOF'"'"'
rootProject.name = "smoke"
EOF
      cat >/tmp/gradle-smoke/build.gradle <<'"'"'EOF'"'"'
tasks.register("hello") {
  doLast {
    println("ok-gradle")
  }
}
EOF
      gradle -p /tmp/gradle-smoke --no-daemon -q hello | grep -qx ok-gradle
    '
  [ "$status" -eq 0 ]
}
