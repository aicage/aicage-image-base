#!/usr/bin/env bash
set -euo pipefail

if command -v rustc >/dev/null 2>&1; then
  exit 0
fi

export RUSTUP_HOME=/usr/local/rustup
export CARGO_HOME=/usr/local/cargo

# add retry and other params to reduce failure in pipelines
curl_wrapper() {
  curl -fsSL \
    --retry 8 \
    --retry-all-errors \
    --retry-delay 2 \
    --max-time 600 \
    "$@"
}

curl_wrapper https://sh.rustup.rs | sh -s -- -y --profile minimal --no-modify-path

PATH="${CARGO_HOME}/bin:${PATH}" rustup component add rustfmt clippy

for bin in "${CARGO_HOME}/bin/"*; do
  ln -sf "${bin}" "/usr/local/bin/$(basename "${bin}")"
done

install -d /usr/share/licenses/rustup
curl_wrapper https://raw.githubusercontent.com/rust-lang/rustup/master/LICENSE-APACHE \
  -o /usr/share/licenses/rustup/LICENSE-APACHE
curl_wrapper https://raw.githubusercontent.com/rust-lang/rustup/master/LICENSE-MIT \
  -o /usr/share/licenses/rustup/LICENSE-MIT

cat > /etc/profile.d/rust.sh <<'RUST'
export RUSTUP_HOME=/usr/local/rustup
export CARGO_HOME=/usr/local/cargo
export PATH="$CARGO_HOME/bin:$PATH"
RUST
