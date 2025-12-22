#!/usr/bin/env bash
set -euo pipefail

if command -v gradle >/dev/null 2>&1; then
  exit 0
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck source=../../scripts/common.sh
source "${ROOT_DIR}/scripts/common.sh"

gradle_json="$(curl_wrapper https://services.gradle.org/versions/current)"
gradle_version="$(echo "${gradle_json}" | jq -r '.version')"
download_url="$(echo "${gradle_json}" | jq -r '.downloadUrl')"
checksum_url="$(echo "${gradle_json}" | jq -r '.checksumUrl')"

if [[ -z "${gradle_version}" || "${gradle_version}" == "null" ]]; then
  echo "Unable to resolve Gradle version" >&2
  exit 1
fi

if [[ -z "${download_url}" || "${download_url}" == "null" ]]; then
  echo "Unable to resolve Gradle download URL" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

archive_path="${tmp_dir}/gradle.zip"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck source=../../scripts/common.sh
source "${ROOT_DIR}/scripts/common.sh"

curl_wrapper "${download_url}" -o "${archive_path}"

if [[ -n "${checksum_url}" && "${checksum_url}" != "null" ]]; then
  checksum="$(curl_wrapper "${checksum_url}")"
  echo "${checksum}  ${archive_path}" | sha256sum -c -
fi

install_root="/opt/gradle"
mkdir -p "${install_root}"
unzip -q "${archive_path}" -d "${install_root}"

gradle_home="${install_root}/gradle-${gradle_version}"
ln -sfn "${gradle_home}" "${install_root}/latest"
ln -sf "${install_root}/latest/bin/gradle" /usr/local/bin/gradle

cat > /etc/profile.d/gradle.sh <<'GRADLE'
export GRADLE_HOME=/opt/gradle/latest
export PATH="$GRADLE_HOME/bin:$PATH"
GRADLE
