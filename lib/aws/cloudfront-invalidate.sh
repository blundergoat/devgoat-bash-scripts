#!/usr/bin/env bash
# =============================================================================
# CloudFront Invalidation - Invalidate CloudFront distribution cache
# =============================================================================
#
# Creates a CloudFront invalidation for the specified distribution.
# Can read the distribution ID from Terraform output or from configuration.
#
# USAGE:
#   ./scripts/cloudfront-invalidate.sh                 # Invalidate all paths
#   ./scripts/cloudfront-invalidate.sh --paths "/*"    # Invalidate specific paths
#   ./scripts/cloudfront-invalidate.sh --help
#
# PREREQUISITES:
#   - AWS CLI configured with correct profile
#   - CloudFront distribution exists
#
# =============================================================================

set -euo pipefail

# ---- CONFIGURATION ----
# Customize these variables for your project, or set them as environment variables.
AWS_PROFILE="${AWS_PROFILE:-default}"
AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-my-project}"

# CloudFront distribution ID (leave empty to read from Terraform output)
CLOUDFRONT_DISTRIBUTION_ID="${CLOUDFRONT_DISTRIBUTION_ID:-}"

# Terraform output name for the distribution ID (used if CLOUDFRONT_DISTRIBUTION_ID is empty)
TF_OUTPUT_DISTRIBUTION_ID="${TF_OUTPUT_DISTRIBUTION_ID:-cloudfront_distribution_id}"

# Relative path from project root to Terraform environment directory
TF_ENV_RELPATH="${TF_ENV_RELPATH:-infra/terraform/environments/prod}"

# Default paths to invalidate
DEFAULT_INVALIDATION_PATHS="${DEFAULT_INVALIDATION_PATHS:-/*}"
# ---- END CONFIGURATION ----

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TF_DIR="$PROJECT_ROOT/$TF_ENV_RELPATH"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

export AWS_PROFILE
export AWS_DEFAULT_REGION="$AWS_REGION"

log()     { echo -e "${BLUE}[invalidate]${NC} $*"; }
success() { echo -e "${GREEN}[invalidate]${NC} $*"; }
warn()    { echo -e "${YELLOW}[invalidate]${NC} $*"; }
error()   { echo -e "${RED}[invalidate]${NC} $*"; exit 1; }

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Creates a CloudFront invalidation for the configured distribution.

OPTIONS:
    -h, --help              Show this help message
    --paths "PATHS"         Paths to invalidate (default: /*)
    -n, --dry-run           Show what would be invalidated without doing it

EXAMPLES:
    $0                              # Invalidate all paths
    $0 --paths "/index.html /css/*" # Invalidate specific paths
    $0 --dry-run                    # Preview invalidation
EOF
}

# Default values
INVALIDATION_PATHS=""
DRY_RUN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --paths)
            INVALIDATION_PATHS="${2:-}"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
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

INVALIDATION_PATHS="${INVALIDATION_PATHS:-$DEFAULT_INVALIDATION_PATHS}"

# ── Prerequisites ──────────────────────────────────────────────────
log "Checking prerequisites..."

if ! command -v aws &>/dev/null; then
    error "AWS CLI is not installed"
fi

if ! aws sts get-caller-identity &>/dev/null; then
    error "AWS credentials not found or expired. Run: aws sso login --profile $AWS_PROFILE"
fi

# ── Get Distribution ID ───────────────────────────────────────────
if [[ -z "$CLOUDFRONT_DISTRIBUTION_ID" ]]; then
    log "Reading distribution ID from Terraform output..."
    if [[ -d "$TF_DIR" ]] && command -v terraform &>/dev/null; then
        CLOUDFRONT_DISTRIBUTION_ID=$(terraform -chdir="$TF_DIR" output -raw "$TF_OUTPUT_DISTRIBUTION_ID" 2>/dev/null) || true
    fi

    if [[ -z "$CLOUDFRONT_DISTRIBUTION_ID" ]]; then
        error "CLOUDFRONT_DISTRIBUTION_ID is not set and could not be read from Terraform"
    fi
fi

log "Distribution: ${BOLD}${CLOUDFRONT_DISTRIBUTION_ID}${NC}"
log "Paths: ${BOLD}${INVALIDATION_PATHS}${NC}"

# ── Build paths array ──────────────────────────────────────────────
# shellcheck disable=SC2206
PATHS_ARRAY=($INVALIDATION_PATHS)

if [[ "$DRY_RUN" == true ]]; then
    log ""
    log "DRY RUN — Would invalidate:"
    for path in "${PATHS_ARRAY[@]}"; do
        log "  $path"
    done
    exit 0
fi

# ── Create Invalidation ───────────────────────────────────────────
log "Creating invalidation..."

CALLER_REF="${PROJECT_NAME}-$(date +%s)"

invalidation_output=$(aws cloudfront create-invalidation \
    --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
    --paths "${PATHS_ARRAY[@]}" \
    --caller-reference "$CALLER_REF" \
    --no-cli-pager 2>&1)

INVALIDATION_ID=$(echo "$invalidation_output" | grep -o '"Id": "[^"]*"' | head -1 | cut -d'"' -f4)

if [[ -n "$INVALIDATION_ID" ]]; then
    success ""
    success "Invalidation created!"
    success "  Distribution: $CLOUDFRONT_DISTRIBUTION_ID"
    success "  Invalidation: $INVALIDATION_ID"
    success "  Paths: ${INVALIDATION_PATHS}"
    success ""
    success "Monitor progress:"
    success "  aws cloudfront get-invalidation --distribution-id $CLOUDFRONT_DISTRIBUTION_ID --id $INVALIDATION_ID --no-cli-pager"
    success ""
else
    error "Failed to create invalidation: $invalidation_output"
fi
