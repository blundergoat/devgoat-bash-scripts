#!/usr/bin/env bash
#
# secrets-manager-set.sh - Create or update secrets in AWS Secrets Manager
#
# USAGE:
#   ./scripts/secrets-manager-set.sh <secret-name> <value>
#   ./scripts/secrets-manager-set.sh <secret-name> --generate [length]
#   ./scripts/secrets-manager-set.sh <secret-name> --file <file>
#
# EXAMPLES:
#   # Set a secret value directly
#   ./scripts/secrets-manager-set.sh admin/api-key "my-secure-api-key"
#
#   # Generate a random secret (default 32 chars)
#   ./scripts/secrets-manager-set.sh jwt/signing-key --generate
#
#   # Generate a random secret with specific length
#   ./scripts/secrets-manager-set.sh session/hash-salt --generate 64
#
#   # Set from a file (useful for multiline secrets)
#   ./scripts/secrets-manager-set.sh db/url --file ./db-connection-string.txt
#
#   # Use full path
#   ./scripts/secrets-manager-set.sh /my-project/prod/admin/api-key "value"
#
# SECURITY:
#   - Avoids putting secret values in shell history by reading from stdin
#   - Use --generate for cryptographically secure random values
#   - Use --file for sensitive values
#
# RELATED:
#   - ./scripts/secrets-manager-get.sh          - View secrets
#   - ./scripts/secrets-manager-health-check.sh - Check secret health
#

set -euo pipefail

# ---- CONFIGURATION ----
# Customize these variables for your project, or set them as environment variables.
SECRETS_PREFIX="${SECRETS_PREFIX:-/my-project/prod}"
# ---- END CONFIGURATION ----

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWS_CLI="${SCRIPT_DIR}/aws-cli.sh"
SECRET_PREFIX="${SECRETS_PREFIX}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

show_help() {
    cat << EOF
Usage: $(basename "$0") <secret-name> <value>
       $(basename "$0") <secret-name> --generate [length]
       $(basename "$0") <secret-name> --file <file>

Create or update secrets in AWS Secrets Manager.

Options:
  --generate [N]  Generate a random secret (default: 32 chars)
  --file FILE     Read secret value from a file
  --description   Set a description for the secret
  --yes, -y       Skip confirmation prompt
  --help          Show this help

Arguments:
  secret-name     Secret to create/update (full path or short name)
                  Short names are auto-prefixed with ${SECRET_PREFIX}/
  value           The secret value (avoid for sensitive data, use --generate or --file)

Examples:
  # Set a secret directly (value visible in shell history!)
  $(basename "$0") admin/api-key "my-api-key"

  # Generate a random 32-character secret
  $(basename "$0") jwt/signing-key --generate

  # Generate a random 64-character secret
  $(basename "$0") session/hash-salt --generate 64

  # Set from file (safer for sensitive data)
  $(basename "$0") db/url --file ./db-url.txt

  # Interactive (safest - prompts for value)
  $(basename "$0") admin/api-key

SECURITY TIPS:
  - Use --generate for API keys, JWT keys, salts, etc.
  - Use --file for connection strings and complex values
  - Run with leading space to avoid shell history: '  $(basename "$0") ...'
  - Set HISTCONTROL=ignorespace to auto-ignore space-prefixed commands
EOF
}

# Check if aws-cli.sh exists
if [[ ! -x "${AWS_CLI}" ]]; then
    error "AWS CLI wrapper not found: ${AWS_CLI}"
    exit 1
fi

# Parse arguments
SECRET_NAME=""
SECRET_VALUE=""
GENERATE_MODE=false
GENERATE_LENGTH=32
FILE_MODE=false
FILE_PATH=""
DESCRIPTION=""
SKIP_CONFIRM=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --generate)
            GENERATE_MODE=true
            shift
            # Check if next arg is a number (length)
            if [[ $# -gt 0 && "$1" =~ ^[0-9]+$ ]]; then
                GENERATE_LENGTH="$1"
                shift
            fi
            ;;
        --file)
            FILE_MODE=true
            FILE_PATH="$2"
            shift 2
            ;;
        --description)
            DESCRIPTION="$2"
            shift 2
            ;;
        --yes|-y)
            SKIP_CONFIRM=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        -*)
            error "Unknown option: $1"
            exit 1
            ;;
        *)
            if [[ -z "${SECRET_NAME}" ]]; then
                SECRET_NAME="$1"
            elif [[ -z "${SECRET_VALUE}" ]]; then
                SECRET_VALUE="$1"
            else
                error "Unexpected argument: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [[ -z "${SECRET_NAME}" ]]; then
    error "No secret name specified"
    show_help
    exit 1
fi

# Auto-prefix if not a full path
if [[ "${SECRET_NAME}" != /* ]]; then
    SECRET_NAME="${SECRET_PREFIX}/${SECRET_NAME}"
fi

SHORT_NAME="${SECRET_NAME#${SECRET_PREFIX}/}"

# Determine the secret value
if [[ "${GENERATE_MODE}" == "true" ]]; then
    # Generate a random value
    SECRET_VALUE=$(openssl rand -base64 "${GENERATE_LENGTH}" | tr -d '\n' | head -c "${GENERATE_LENGTH}")
    info "Generated ${GENERATE_LENGTH}-character random secret"

elif [[ "${FILE_MODE}" == "true" ]]; then
    # Read from file
    if [[ ! -f "${FILE_PATH}" ]]; then
        error "File not found: ${FILE_PATH}"
        exit 1
    fi
    SECRET_VALUE=$(cat "${FILE_PATH}")
    info "Read secret from ${FILE_PATH} (${#SECRET_VALUE} chars)"

elif [[ -z "${SECRET_VALUE}" ]]; then
    # Interactive mode - prompt for value
    warn "No value provided. Enter secret value (will not echo):"
    read -r -s SECRET_VALUE
    echo

    if [[ -z "${SECRET_VALUE}" ]]; then
        error "Empty value not allowed"
        exit 1
    fi
    info "Read ${#SECRET_VALUE}-character secret from input"
fi

# Check if secret exists
info "Checking if secret exists..."
SECRET_EXISTS=false
DESCRIBE_RESULT=$("${AWS_CLI}" secretsmanager describe-secret \
    --secret-id "${SECRET_NAME}" 2>&1) && SECRET_EXISTS=true || true

# Show what we're about to do
echo ""
echo -e "${CYAN}Secret:${NC} ${SHORT_NAME}"
echo -e "${CYAN}Path:${NC}   ${SECRET_NAME}"
echo -e "${CYAN}Length:${NC} ${#SECRET_VALUE} characters"

if [[ "${SECRET_EXISTS}" == "true" ]]; then
    CURRENT_MODIFIED=$(echo "${DESCRIBE_RESULT}" | jq -r '.LastChangedDate // "N/A"')
    echo -e "${CYAN}Status:${NC} ${YELLOW}EXISTS${NC} (last modified: ${CURRENT_MODIFIED})"
    echo -e "${CYAN}Action:${NC} UPDATE existing secret"
else
    echo -e "${CYAN}Status:${NC} ${GREEN}NEW${NC}"
    echo -e "${CYAN}Action:${NC} CREATE new secret"
fi

if [[ -n "${DESCRIPTION}" ]]; then
    echo -e "${CYAN}Description:${NC} ${DESCRIPTION}"
fi

echo ""

# Confirm
if [[ "${SKIP_CONFIRM}" == "false" ]]; then
    if [[ "${SECRET_EXISTS}" == "true" ]]; then
        echo -e "${YELLOW}This will OVERWRITE the existing secret value.${NC}"
    fi
    read -p "Continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Cancelled"
        exit 0
    fi
fi

# Create or update the secret
if [[ "${SECRET_EXISTS}" == "true" ]]; then
    # Update existing secret
    info "Updating secret..."

    UPDATE_ARGS=(
        secretsmanager put-secret-value
        --secret-id "${SECRET_NAME}"
        --secret-string "${SECRET_VALUE}"
    )

    UPDATE_RESULT=$("${AWS_CLI}" "${UPDATE_ARGS[@]}" 2>&1) || {
        error "Failed to update secret"
        echo "${UPDATE_RESULT}" >&2
        exit 1
    }

    VERSION_ID=$(echo "${UPDATE_RESULT}" | jq -r '.VersionId // "N/A"')
    success "Secret updated (version: ${VERSION_ID})"

else
    # Create new secret
    info "Creating secret..."

    CREATE_ARGS=(
        secretsmanager create-secret
        --name "${SECRET_NAME}"
        --secret-string "${SECRET_VALUE}"
    )

    if [[ -n "${DESCRIPTION}" ]]; then
        CREATE_ARGS+=(--description "${DESCRIPTION}")
    fi

    CREATE_RESULT=$("${AWS_CLI}" "${CREATE_ARGS[@]}" 2>&1) || {
        error "Failed to create secret"
        echo "${CREATE_RESULT}" >&2
        exit 1
    }

    ARN=$(echo "${CREATE_RESULT}" | jq -r '.ARN // "N/A"')
    success "Secret created"
    info "ARN: ${ARN}"
fi

# Show the generated value if it was auto-generated
if [[ "${GENERATE_MODE}" == "true" ]]; then
    echo ""
    echo -e "${YELLOW}Generated value (save this somewhere safe):${NC}"
    echo "${SECRET_VALUE}"
fi

echo ""
success "Done!"
echo ""
info "Verify with: ./scripts/secrets-manager-get.sh ${SHORT_NAME}"
