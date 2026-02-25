#!/usr/bin/env bash
set -euo pipefail

# Generate TypeScript types from the OpenAPI spec.
# Usage: ./scripts/generate-api-client.sh

# ---- CONFIGURATION ----
# Customize these variables for your project, or set them as environment variables.
PROJECT_NAME="${PROJECT_NAME:-my-project}"
SPEC_PATH="${SPEC_PATH:-apps/api/openapi.yaml}"
OUTPUT_PATH="${OUTPUT_PATH:-apps/web/src/api/types.ts}"
PACKAGE_MANAGER="${PACKAGE_MANAGER:-pnpm}"
PACKAGE_MANAGER_DIR="${PACKAGE_MANAGER_DIR:-apps/web}"
# ---- END CONFIGURATION ----

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SPEC_FILE="$ROOT_DIR/$SPEC_PATH"
OUTPUT_FILE="$ROOT_DIR/$OUTPUT_PATH"

if [ ! -f "$SPEC_FILE" ]; then
  echo "OpenAPI spec not found: $SPEC_FILE" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

echo "Generating TypeScript types from $SPEC_FILE"

# Use the configured package manager to run openapi-typescript.
$PACKAGE_MANAGER --dir "$ROOT_DIR/$PACKAGE_MANAGER_DIR" exec openapi-typescript "$SPEC_FILE" -o "$OUTPUT_FILE"

echo "Generated: $OUTPUT_FILE"
