#!/usr/bin/env bash
# =============================================================================
# S3 Sync - Sync build artifacts to an S3 bucket
# =============================================================================
#
# Uploads a local directory to S3 with configurable cache control.
# Optionally triggers a CloudFront invalidation after sync.
#
# USAGE:
#   ./scripts/s3-sync.sh                    # Sync build dir to S3
#   ./scripts/s3-sync.sh --dry-run          # Preview what would be synced
#   ./scripts/s3-sync.sh --delete           # Remove files from S3 not in source
#   ./scripts/s3-sync.sh --invalidate       # Trigger CloudFront invalidation after sync
#
# PREREQUISITES:
#   - AWS CLI configured with correct profile
#   - S3 bucket exists
#
# =============================================================================

set -euo pipefail

# ---- CONFIGURATION ----
# Customize these variables for your project, or set them as environment variables.
AWS_PROFILE="${AWS_PROFILE:-default}"
AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-my-project}"

# S3 bucket name (without s3:// prefix)
S3_BUCKET="${S3_BUCKET:-my-project-assets}"

# Local directory to sync (relative to project root)
BUILD_DIR="${BUILD_DIR:-dist}"

# Cache-Control header for uploaded files
CACHE_CONTROL="${CACHE_CONTROL:-public, max-age=31536000, immutable}"

# Cache-Control for HTML files (shorter cache)
HTML_CACHE_CONTROL="${HTML_CACHE_CONTROL:-public, max-age=0, must-revalidate}"

# CloudFront invalidation script path (relative to project root)
INVALIDATE_SCRIPT="${INVALIDATE_SCRIPT:-lib/aws/cloudfront-invalidate.sh}"
# ---- END CONFIGURATION ----

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

export AWS_PROFILE
export AWS_DEFAULT_REGION="$AWS_REGION"

log()     { echo -e "${BLUE}[s3-sync]${NC} $*"; }
success() { echo -e "${GREEN}[s3-sync]${NC} $*"; }
warn()    { echo -e "${YELLOW}[s3-sync]${NC} $*"; }
error()   { echo -e "${RED}[s3-sync]${NC} $*"; exit 1; }

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Syncs a local build directory to an S3 bucket. Sets Cache-Control headers
for optimal CDN caching.

OPTIONS:
    -h, --help          Show this help message
    -n, --dry-run       Preview what would be synced without uploading
    --delete            Remove files from S3 that are not in the source directory
    --invalidate        Trigger CloudFront invalidation after sync

EXAMPLES:
    $0                          # Sync to S3
    $0 --dry-run                # Preview sync
    $0 --delete --invalidate    # Sync, clean orphans, and invalidate CDN
EOF
}

# Default values
DRY_RUN=false
DELETE_FLAG=false
INVALIDATE=false

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
        --delete)
            DELETE_FLAG=true
            shift
            ;;
        --invalidate)
            INVALIDATE=true
            shift
            ;;
        -*)
            error "Unknown option: $1"
            ;;
        *)
            error "Unexpected argument: $1"
            ;;
    esac
done

BUILD_PATH="$PROJECT_ROOT/$BUILD_DIR"

# ── Prerequisites ──────────────────────────────────────────────────
log "Checking prerequisites..."

if ! command -v aws &>/dev/null; then
    error "AWS CLI is not installed"
fi

if ! aws sts get-caller-identity &>/dev/null; then
    error "AWS credentials not found or expired. Run: aws sso login --profile $AWS_PROFILE"
fi

if [[ ! -d "$BUILD_PATH" ]]; then
    error "Build directory not found: $BUILD_DIR"
fi

file_count=$(find "$BUILD_PATH" -type f 2>/dev/null | wc -l)
file_count="${file_count//[^0-9]/}"
log "Source: ${BOLD}${BUILD_DIR}/${NC} (${file_count} files)"
log "Target: ${BOLD}s3://${S3_BUCKET}${NC}"

# ── Build sync args ────────────────────────────────────────────────
SYNC_ARGS=("$BUILD_PATH" "s3://${S3_BUCKET}")

if [[ "$DRY_RUN" == true ]]; then
    SYNC_ARGS+=("--dryrun")
fi

if [[ "$DELETE_FLAG" == true ]]; then
    SYNC_ARGS+=("--delete")
fi

# ── Sync non-HTML files with long cache ────────────────────────────
log ""
log "Syncing assets (long cache)..."

aws s3 sync "${SYNC_ARGS[@]}" \
    --cache-control "$CACHE_CONTROL" \
    --exclude "*.html" \
    --no-cli-pager

# ── Sync HTML files with short cache ──────────────────────────────
log "Syncing HTML (no cache)..."

aws s3 sync "${SYNC_ARGS[@]}" \
    --cache-control "$HTML_CACHE_CONTROL" \
    --exclude "*" \
    --include "*.html" \
    --no-cli-pager

# ── Summary ────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == true ]]; then
    log ""
    log "DRY RUN - no files were uploaded"
else
    success ""
    success "Sync complete!"
    success "  Source: ${BUILD_DIR}/"
    success "  Target: s3://${S3_BUCKET}"
fi

# ── Invalidate CloudFront ──────────────────────────────────────────
if [[ "$INVALIDATE" == true ]]; then
    log ""
    INVALIDATE_PATH="$PROJECT_ROOT/$INVALIDATE_SCRIPT"
    if [[ -x "$INVALIDATE_PATH" ]]; then
        log "Triggering CloudFront invalidation..."
        if [[ "$DRY_RUN" == true ]]; then
            bash "$INVALIDATE_PATH" --dry-run
        else
            bash "$INVALIDATE_PATH"
        fi
    else
        warn "Invalidation script not found: $INVALIDATE_SCRIPT"
        warn "Set CLOUDFRONT_DISTRIBUTION_ID and run cloudfront-invalidate.sh manually"
    fi
fi
