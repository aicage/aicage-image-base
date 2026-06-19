#!/usr/bin/env bats

@test "musl toolchain available" {
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      . /etc/os-release

      cat >/tmp/hello.c <<'"'"'EOF'"'"'
      int main(void) { return 0; }
EOF

      if [[ "${ID:-}" == "alpine" ]]; then
        apk info --installed musl >/dev/null
        cc -o /tmp/hello /tmp/hello.c
      else
        command -v musl-gcc
        musl-gcc -o /tmp/hello /tmp/hello.c
      fi

      /tmp/hello
    '
  [ "$status" -eq 0 ]
}

@test "musl vendored libbpf prerequisites available" {
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail

      command -v autoreconf
      command -v autopoint
      command -v flex
      command -v bison
      command -v gawk
      command -v libtoolize
      command -v make
      command -v pkg-config
    '
  [ "$status" -eq 0 ]
}
