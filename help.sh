#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_SCRIPT="${ROOT_DIR}/lib/workflow/help-index.sh"

exec "${TARGET_SCRIPT}" "$@"
