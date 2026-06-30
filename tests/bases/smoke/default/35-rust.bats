#!/usr/bin/env bats

@test "rust toolchain present" {
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
      command -v rustc
      command -v cargo
      command -v rustfmt
      command -v clippy-driver >/dev/null || command -v cargo-clippy >/dev/null

      musl_target="$(uname -m)-unknown-linux-musl"
      cargo new --quiet /tmp/rust-musl-smoke
      cd /tmp/rust-musl-smoke
      cargo build --target "${musl_target}"
    '
  [ "$status" -eq 0 ]
}

@test "rust shell environment configured" {
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    --env AICAGE_HOST_IS_LINUX=true \
    --env AICAGE_UID=1234 \
    --env AICAGE_GID=2345 \
    --env AICAGE_HOST_USER=demo \
    --env AICAGE_HOME=/home/demo \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -lc '
      set -euo pipefail
      test "${RUSTUP_HOME}" = "/usr/local/rustup"
      [[ ":${PATH}:" == *":/usr/local/cargo/bin:"* ]]
      [[ ":${PATH}:" == *":${HOME}/.cargo/bin:"* ]]
      rustup show active-toolchain >/dev/null
      cargo -V >/dev/null
      rustc -V >/dev/null
    '
  [ "$status" -eq 0 ]
}
