#!/usr/bin/env bash
set -euo pipefail

dnf -y install \
  autoconf \
  automake \
  bison \
  flex \
  gawk \
  gettext \
  gettext-devel \
  libtool \
  musl-devel \
  musl-gcc \
  musl-libc-static
