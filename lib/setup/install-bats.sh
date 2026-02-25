#!/usr/bin/env bash
# Compatibility shim: prefer install-bats-core.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: ./lib/setup/install-bats.sh [OPTIONS]"
    echo ""
    echo "Deprecated wrapper for ./lib/setup/install-bats-core.sh"
    echo "Passes all arguments through."
    echo ""
    echo "Use instead:"
    echo "  ./lib/setup/install-bats-core.sh [OPTIONS]"
    exit 0
fi

echo "[warn] ./lib/setup/install-bats.sh is deprecated; using ./lib/setup/install-bats-core.sh" >&2
exec "$SCRIPT_DIR/install-bats-core.sh" "$@"
