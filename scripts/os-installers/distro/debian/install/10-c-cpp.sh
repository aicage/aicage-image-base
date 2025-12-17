#!/usr/bin/env bash
set -euo pipefail

apt-get install -y --no-install-recommends \
  build-essential \
  clang \
  cmake \
  gdb \
  libssl-dev \
  lld \
  lldb \
  ltrace \
  ninja-build \
  pkg-config \
  strace \
  valgrind \
  zlib1g-dev
