#!/usr/bin/env bash
set -euo pipefail

apk add --no-cache \
  autoconf \
  automake \
  bison \
  build-base \
  clang \
  cmake \
  flex \
  gdb \
  gettext \
  gawk \
  lld \
  lldb \
  libtool \
  ltrace \
  ninja \
  openssl-dev \
  pkgconf \
  strace \
  valgrind \
  zlib-dev
