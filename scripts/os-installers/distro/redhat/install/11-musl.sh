#!/usr/bin/env bash
set -euo pipefail

dnf -y install \
  musl-devel \
  musl-gcc \
  musl-libc-static
