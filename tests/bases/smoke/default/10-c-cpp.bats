#!/usr/bin/env bats

@test "c/c++ toolchain present" {
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
      command -v gcc
      command -v g++
      command -v cmake
      command -v ninja
      command -v clang
      command -v lldb
      command -v gdb
      command -v pkg-config
      command -v valgrind
      command -v strace
      command -v ltrace || [ "aarch64" == "$(uname -m)" ]
      command -v ld.lld >/dev/null || command -v lld >/dev/null

      cat >/tmp/hello.c <<'"'"'EOF'"'"'
#include <stdio.h>

int main(void) {
  puts("ok-c");
  return 0;
}
EOF

      gcc -o /tmp/hello-c-gcc /tmp/hello.c
      /tmp/hello-c-gcc | grep -qx ok-c

      clang -o /tmp/hello-c-clang /tmp/hello.c
      /tmp/hello-c-clang | grep -qx ok-c

      cat >/tmp/hello.cpp <<'"'"'EOF'"'"'
#include <iostream>

int main() {
  std::cout << "ok-cpp" << std::endl;
  return 0;
}
EOF

      g++ -o /tmp/hello-cpp /tmp/hello.cpp
      /tmp/hello-cpp | grep -qx ok-cpp

      mkdir -p /tmp/cmake-smoke
      cat >/tmp/cmake-smoke/CMakeLists.txt <<'"'"'EOF'"'"'
cmake_minimum_required(VERSION 3.20)
project(smoke C)
add_executable(smoke main.c)
EOF
      cat >/tmp/cmake-smoke/main.c <<'"'"'EOF'"'"'
#include <stdio.h>

int main(void) {
  puts("ok-cmake");
  return 0;
}
EOF
      cmake -S /tmp/cmake-smoke -B /tmp/cmake-smoke/build -G Ninja
      cmake --build /tmp/cmake-smoke/build
      /tmp/cmake-smoke/build/smoke | grep -qx ok-cmake
    '
  [ "$status" -eq 0 ]
}
