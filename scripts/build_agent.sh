#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="${HOME}/.cargo/bin:${PATH}"
export RUSTUP_USE_CURL="${RUSTUP_USE_CURL:-1}"

cd "$ROOT/native"
cargo build --release

AGENT="$ROOT/native/target/release/portless_agent"
echo "Built: $AGENT"
"$AGENT" ping
