#!/usr/bin/env bash
set -euo pipefail

if command -v apt-get >/dev/null 2>&1; then
  apt-get install -y --no-install-recommends \
    default-mysql-client \
    postgresql-client \
    sqlite3
elif command -v dnf >/dev/null 2>&1; then
  dnf -y install \
    mysql \
    postgresql \
    sqlite
elif command -v apk >/dev/null 2>&1; then
  apk add --no-cache \
    mariadb-client \
    postgresql-client \
    sqlite
else
  echo "Unsupported package manager for database client installation" >&2
  exit 1
fi
