#!/usr/bin/env bash
set -euo pipefail

apt-get install -y --no-install-recommends \
  autoconf \
  automake \
  autopoint \
  bison \
  flex \
  gawk \
  libtool \
  libtool-bin \
  linux-libc-dev \
  make \
  musl-tools
