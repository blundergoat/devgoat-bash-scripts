---
applyTo: "lib/aws/**"
---

# aws Domain

AWS infrastructure wrappers. Scripts are **templates** — users copy them into a project and fill in the CONFIGURATION block.

## Script Pattern

AWS scripts source `_aws-common.sh` for shared helpers (auth, .env loading, color constants, require_cmd). Each script defines:
1. `set -euo pipefail`
2. `# ---- CONFIGURATION ----` block with AWS_PROFILE_NAME, AWS_REGION, and resource-specific vars
3. `source "$SCRIPT_DIR/_aws-common.sh"` for shared colors, auth, and helpers
4. `_aws-common.sh` is an **Ask First** boundary — changes affect all AWS scripts

**Note:** `_aws-common.sh` provides `require_cmd`, `require_unix`, `require_modern_bash`, `ensure_aws_cli`, `require_aws_auth`, `load_env_file`, and color constants. Scripts that need `jq` or `bc` call `require_cmd` themselves.

## Logging Style

Standalone inline functions with `[tag]` prefixes:
```bash
log()     { echo -e "${BLUE}[tag]${NC} $*"; }
success() { echo -e "${GREEN}[tag]${NC} $*"; }
warn()    { echo -e "${YELLOW}[tag]${NC} $*"; }
error()   { echo -e "${RED}[tag]${NC} $*"; exit 1; }
```

**Notable tags:** `cloudfront-invalidate.sh` uses `[invalidate]`, `s3-sync.sh` uses `[s3-sync]`. Other aws scripts use generic `[info]`/`[ok]` style or vary. Match the existing tag in the script you're editing.

## Common Dependencies

- AWS CLI v2 (`aws`)
- jq (for JSON parsing)
- Terraform (for `terraform.sh`)

## CONFIGURATION Block Variables

Typical variables across aws scripts:
- `AWS_PROFILE_NAME`, `AWS_REGION` — always present (set before sourcing `_aws-common.sh`)
- `PROJECT_NAME` — used to derive resource names
- `APP_ID`, `BRANCH_NAME` — Amplify scripts
- `SECRET_PREFIX`, `REQUIRED_SECRETS` — Secrets Manager scripts
- `TF_OUTPUT_*`, `TF_ENV_RELPATH` — deploy/terraform scripts
- `CLOUDFRONT_DISTRIBUTION_ID`, `TF_OUTPUT_DISTRIBUTION_ID` — cloudfront-invalidate
- `S3_BUCKET`, `BUILD_DIR`, `CACHE_CONTROL` — s3-sync

## Security Notes

- Scripts never store credentials — they rely on AWS CLI profiles or SSO
- `secrets-manager-*.sh` scripts handle secrets; never log secret values
- `cloudfront-invalidate.sh` and `s3-sync.sh` call `aws sts get-caller-identity` to validate credentials before proceeding

## Script Interactions

- `s3-sync.sh` can trigger `cloudfront-invalidate.sh` after a successful sync via the `--invalidate` flag
- Both CDN scripts can read resource IDs from Terraform output when `TF_ENV_RELPATH` is configured
