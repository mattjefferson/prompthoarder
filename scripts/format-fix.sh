#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v swiftformat >/dev/null 2>&1; then
  echo "format-fix: swiftformat not found (install with brew install swiftformat)" >&2
  exit 1
fi

swiftformat Sources Tests
