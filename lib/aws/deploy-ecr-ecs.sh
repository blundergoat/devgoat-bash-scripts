#!/usr/bin/env bash
# =============================================================================
# Deploy Script - Build and Push Docker Images to ECR + ECS Redeploy
# =============================================================================
#
# Builds Docker images and pushes them to ECR,
# then forces an ECS service redeployment.
#
# USAGE:
#   ./scripts/deploy-ecr-ecs.sh              # Build and deploy all images
#   ./scripts/deploy-ecr-ecs.sh <target>     # Build and deploy a specific target
#
# PREREQUISITES:
#   - AWS CLI configured with correct profile
#   - Docker running
#   - Terraform applied (ECR repos must exist)
#
# =============================================================================

set -euo pipefail

# ---- CONFIGURATION ----
# Customize these variables for your project, or set them as environment variables.
AWS_PROFILE="${AWS_PROFILE:-default}"
AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-my-project}"

# ECS service name for redeployment
ECS_SERVICE_NAME="${ECS_SERVICE_NAME:-${PROJECT_NAME}-app}"

# Terraform output names for ECR repository URLs and ECS cluster
# These are used to read values from `terraform output`.
TF_OUTPUT_ECR_PRIMARY="${TF_OUTPUT_ECR_PRIMARY:-ecr_agent_repository_url}"
TF_OUTPUT_ECR_SECONDARY="${TF_OUTPUT_ECR_SECONDARY:-ecr_app_repository_url}"
TF_OUTPUT_ECS_CLUSTER="${TF_OUTPUT_ECS_CLUSTER:-ecs_cluster_name}"

# Relative path from project root to Terraform environment directory
TF_ENV_RELPATH="${TF_ENV_RELPATH:-infra/terraform/environments/prod}"

# Docker build targets: name, Dockerfile path (relative to project root), and context path
# Override these for your project layout.
PRIMARY_TARGET_NAME="${PRIMARY_TARGET_NAME:-agent}"
PRIMARY_DOCKERFILE="${PRIMARY_DOCKERFILE:-Dockerfile}"
PRIMARY_CONTEXT="${PRIMARY_CONTEXT:-.}"

SECONDARY_TARGET_NAME="${SECONDARY_TARGET_NAME:-app}"
SECONDARY_DOCKERFILE="${SECONDARY_DOCKERFILE:-Dockerfile.app}"
SECONDARY_CONTEXT="${SECONDARY_CONTEXT:-.}"

# Extra docker build arguments (optional, space-separated)
PRIMARY_DOCKER_EXTRA_ARGS="${PRIMARY_DOCKER_EXTRA_ARGS:-}"
SECONDARY_DOCKER_EXTRA_ARGS="${SECONDARY_DOCKER_EXTRA_ARGS:-}"

IMAGE_TAG="${IMAGE_TAG:-latest}"
# ---- END CONFIGURATION ----

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TF_DIR="$PROJECT_ROOT/$TF_ENV_RELPATH"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

export AWS_PROFILE
export AWS_DEFAULT_REGION="$AWS_REGION"

# What to deploy
TARGET="${1:-all}"

log() { echo -e "${BLUE}[deploy]${NC} $*"; }
success() { echo -e "${GREEN}[deploy]${NC} $*"; }
warn() { echo -e "${YELLOW}[deploy]${NC} $*"; }
error() { echo -e "${RED}[deploy]${NC} $*"; exit 1; }

# Get ECR repository URLs from Terraform outputs
get_tf_output() {
    terraform -chdir="$TF_DIR" output -raw "$1" 2>/dev/null
}

# Verify prerequisites
log "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    error "Docker is not installed"
fi

if ! command -v aws &> /dev/null; then
    error "AWS CLI is not installed"
fi

if ! aws sts get-caller-identity &> /dev/null; then
    error "AWS credentials not found or expired. Run: aws sso login --profile $AWS_PROFILE"
fi

# Get ECR URLs from Terraform
log "Reading ECR repository URLs from Terraform..."
PRIMARY_REPO=$(get_tf_output "$TF_OUTPUT_ECR_PRIMARY") || error "Could not read ${TF_OUTPUT_ECR_PRIMARY}. Run terraform apply first."
SECONDARY_REPO=$(get_tf_output "$TF_OUTPUT_ECR_SECONDARY") || error "Could not read ${TF_OUTPUT_ECR_SECONDARY}. Run terraform apply first."
ECS_CLUSTER=$(get_tf_output "$TF_OUTPUT_ECS_CLUSTER") || error "Could not read ${TF_OUTPUT_ECS_CLUSTER}."

# Extract AWS account ID and region from repo URL
AWS_ACCOUNT_ID=$(echo "$PRIMARY_REPO" | cut -d. -f1)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Login to ECR
log "Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"

# Build and push primary image
if [[ "$TARGET" == "all" || "$TARGET" == "$PRIMARY_TARGET_NAME" ]]; then
    log ""
    log "${BOLD}Building ${PRIMARY_TARGET_NAME} image...${NC}"
    docker build \
        ${PRIMARY_DOCKER_EXTRA_ARGS} \
        -t "${PRIMARY_REPO}:${IMAGE_TAG}" \
        -f "$PROJECT_ROOT/$PRIMARY_DOCKERFILE" \
        "$PROJECT_ROOT/$PRIMARY_CONTEXT"

    log "Pushing ${PRIMARY_TARGET_NAME} image..."
    docker push "${PRIMARY_REPO}:${IMAGE_TAG}"
    success "${PRIMARY_TARGET_NAME} image pushed: ${PRIMARY_REPO}:${IMAGE_TAG}"
fi

# Build and push secondary image
if [[ "$TARGET" == "all" || "$TARGET" == "$SECONDARY_TARGET_NAME" ]]; then
    log ""
    log "${BOLD}Building ${SECONDARY_TARGET_NAME} image...${NC}"
    docker build \
        ${SECONDARY_DOCKER_EXTRA_ARGS} \
        -t "${SECONDARY_REPO}:${IMAGE_TAG}" \
        -f "$PROJECT_ROOT/$SECONDARY_DOCKERFILE" \
        "$PROJECT_ROOT/$SECONDARY_CONTEXT"

    log "Pushing ${SECONDARY_TARGET_NAME} image..."
    docker push "${SECONDARY_REPO}:${IMAGE_TAG}"
    success "${SECONDARY_TARGET_NAME} image pushed: ${SECONDARY_REPO}:${IMAGE_TAG}"
fi

# Force ECS redeployment
log ""
log "Forcing ECS service redeployment..."
aws ecs update-service \
    --cluster "$ECS_CLUSTER" \
    --service "$ECS_SERVICE_NAME" \
    --force-new-deployment \
    --region "$AWS_REGION" \
    --no-cli-pager > /dev/null

success ""
success "============================================="
success " Deployment initiated!"
success "============================================="
success ""
success " Images pushed:"
if [[ "$TARGET" == "all" || "$TARGET" == "$PRIMARY_TARGET_NAME" ]]; then
    success "   ${PRIMARY_TARGET_NAME}: ${PRIMARY_REPO}:${IMAGE_TAG}"
fi
if [[ "$TARGET" == "all" || "$TARGET" == "$SECONDARY_TARGET_NAME" ]]; then
    success "   ${SECONDARY_TARGET_NAME}: ${SECONDARY_REPO}:${IMAGE_TAG}"
fi
success ""
success " ECS service redeployment triggered."
success " Monitor progress:"
success "   aws ecs describe-services --cluster $ECS_CLUSTER --services $ECS_SERVICE_NAME --query 'services[0].deployments' --no-cli-pager"
success ""
