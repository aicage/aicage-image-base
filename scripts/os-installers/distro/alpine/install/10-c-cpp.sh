#!/usr/bin/env bash
set -euo pipefail

apk add --no-cache \
  build-base \
  clang \
  cmake \
  gdb \
  lld \
  lldb \
  ltrace \
  ninja \
  openssl-dev \
  pkgconf \
  strace \
  valgrind \
  zlib-dev
