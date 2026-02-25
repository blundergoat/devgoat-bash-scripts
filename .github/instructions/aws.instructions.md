---
applyTo: "lib/aws/**"
---

# aws Domain

AWS infrastructure wrappers. All scripts are **templates** — users copy them into a project and fill in the CONFIGURATION block.

## Script Pattern

All aws scripts are self-contained (no shared library). Each defines:
1. `set -euo pipefail`
2. `# ---- CONFIGURATION ----` block with AWS_PROFILE, AWS_REGION, PROJECT_NAME, and resource-specific vars
3. Inline color constants (RED, GREEN, YELLOW, BLUE, CYAN, BOLD, NC)
4. Inline logging functions

## Logging Style

Standalone inline functions with `[tag]` prefixes:
```bash
log()     { echo -e "${BLUE}[tag]${NC} $*"; }
success() { echo -e "${GREEN}[tag]${NC} $*"; }
warn()    { echo -e "${YELLOW}[tag]${NC} $*"; }
error()   { echo -e "${RED}[tag]${NC} $*"; exit 1; }
```

**Notable tags:** `deploy-ecr-ecs.sh` uses `[deploy]`, `cloudfront-invalidate.sh` uses `[invalidate]`, `s3-sync.sh` uses `[s3-sync]`. Other aws scripts use generic `[info]`/`[ok]` style or vary. Match the existing tag in the script you're editing.

## Common Dependencies

- AWS CLI v2 (`aws`)
- jq (for JSON parsing)
- Terraform (for `terraform.sh` and `deploy-ecr-ecs.sh`)
- Docker (for `deploy-ecr-ecs.sh`)

## CONFIGURATION Block Variables

Typical variables across aws scripts:
- `AWS_PROFILE`, `AWS_REGION` — always present
- `PROJECT_NAME` — used to derive resource names
- `APP_ID`, `BRANCH_NAME` — Amplify scripts
- `SECRET_PREFIX`, `REQUIRED_SECRETS` — Secrets Manager scripts
- `TF_OUTPUT_*`, `TF_ENV_RELPATH` — deploy/terraform scripts
- `CLOUDFRONT_DISTRIBUTION_ID`, `TF_OUTPUT_DISTRIBUTION_ID` — cloudfront-invalidate
- `S3_BUCKET`, `BUILD_DIR`, `CACHE_CONTROL` — s3-sync

## Security Notes

- Scripts never store credentials — they rely on AWS CLI profiles or SSO
- `secrets-manager-*.sh` scripts handle secrets; never log secret values
- `deploy-ecr-ecs.sh`, `cloudfront-invalidate.sh`, and `s3-sync.sh` call `aws sts get-caller-identity` to validate credentials before proceeding

## Script Interactions

- `s3-sync.sh` can trigger `cloudfront-invalidate.sh` after a successful sync via the `--invalidate` flag
- Both CDN scripts can read resource IDs from Terraform output when `TF_ENV_RELPATH` is configured
