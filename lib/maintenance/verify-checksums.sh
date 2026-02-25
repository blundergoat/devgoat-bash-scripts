#!/usr/bin/env bash

set -euo pipefail

# Script to verify file integrity using SHA-256 checksums from a manifest file

# Color functions for output
info() {
    echo -e "\033[32mINFO:\033[0m $1"
}

warn() {
    echo -e "\033[33mWARN:\033[0m $1"
}

err() {
    echo -e "\033[31mERROR:\033[0m $1"
}

show_help() {
    cat << EOF
Usage: $0 [OPTIONS] MANIFEST

Verifies file integrity using SHA-256 checksums from a manifest file.
Manifest format: one "sha256  filename" pair per line (sha256sum output format).

OPTIONS:
    -h, --help      Show this help message
    -n, --dry-run   Show which files would be checked without verifying

ARGUMENTS:
    MANIFEST        Path to the checksums manifest file

EXAMPLES:
    $0 checksums.sha256                 # Verify all files in manifest
    $0 --dry-run checksums.sha256       # Preview what would be checked

CREATING A MANIFEST:
    sha256sum file1.tar.gz file2.zip > checksums.sha256
    shasum -a 256 file1.tar.gz file2.zip > checksums.sha256   # macOS
EOF
}

# Default values
DRY_RUN=false
MANIFEST=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -*)
            err "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$MANIFEST" ]]; then
                MANIFEST="$1"
            else
                err "Only one manifest file accepted"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "$MANIFEST" ]]; then
    err "Manifest file required"
    show_help
    exit 1
fi

if [[ ! -f "$MANIFEST" ]]; then
    err "Manifest file not found: $MANIFEST"
    exit 1
fi

# Detect checksum command
HASH_CMD=""
if command -v sha256sum &>/dev/null; then
    HASH_CMD="sha256sum"
elif command -v shasum &>/dev/null; then
    HASH_CMD="shasum -a 256"
else
    err "Neither sha256sum nor shasum found"
    exit 1
fi

info "Using: $HASH_CMD"
info "Manifest: $MANIFEST"
echo ""

# Read manifest and verify
pass_count=0
fail_count=0
skip_count=0
total_count=0

while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" == \#* ]] && continue

    total_count=$((total_count + 1))

    # Parse "hash  filename" format (two spaces between hash and filename)
    expected_hash=$(echo "$line" | awk '{print $1}')
    filepath="${line#* }"
    filepath="${filepath# }"

    if [[ -z "$expected_hash" || -z "$filepath" ]]; then
        warn "Malformed line: $line"
        skip_count=$((skip_count + 1))
        continue
    fi

    if [[ "$DRY_RUN" == true ]]; then
        if [[ -f "$filepath" ]]; then
            echo -e "\033[36mWould verify:\033[0m $filepath"
        else
            echo -e "\033[33mMissing file:\033[0m $filepath"
        fi
        continue
    fi

    if [[ ! -f "$filepath" ]]; then
        echo -e "\033[31mMISSING:\033[0m $filepath"
        fail_count=$((fail_count + 1))
        continue
    fi

    # Compute hash
    actual_hash=$($HASH_CMD "$filepath" 2>/dev/null | awk '{print $1}')

    if [[ "$actual_hash" == "$expected_hash" ]]; then
        echo -e "\033[32mPASS:\033[0m $filepath"
        pass_count=$((pass_count + 1))
    else
        echo -e "\033[31mFAIL:\033[0m $filepath"
        echo "       expected: $expected_hash"
        echo "       actual:   $actual_hash"
        fail_count=$((fail_count + 1))
    fi
done < "$MANIFEST"

echo ""

if [[ "$DRY_RUN" == true ]]; then
    info "DRY RUN: Would verify $total_count file(s)"
elif [[ $fail_count -gt 0 ]]; then
    err "$fail_count of $total_count file(s) failed verification"
    exit 1
else
    info "All $pass_count file(s) passed verification"
fi
