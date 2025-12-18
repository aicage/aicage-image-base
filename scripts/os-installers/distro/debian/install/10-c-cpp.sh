#!/usr/bin/env bash
set -euo pipefail

echo "CHECK LTRACE: $(apt-cache show ltrace)"

if apt-cache show ltrace >/dev/null 2>&1; then
  TRACE_TOOLS=strace ltrace
else
  TRACE_TOOLS=strace
fi

apt-get install -y --no-install-recommends \
  build-essential \
  clang \
  cmake \
  gdb \
  libssl-dev \
  lld \
  lldb \
  ${TRACE_TOOLS} \
  ninja-build \
  pkg-config \
  valgrind \
  zlib1g-dev
