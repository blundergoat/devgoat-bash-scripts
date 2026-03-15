#!/usr/bin/env bash
#
# aws-cli.sh - AWS CLI and Terraform wrapper with consistent auth loading
#

set -euo pipefail

# ---- CONFIGURATION ----
AWS_PROFILE_NAME="${AWS_PROFILE_NAME:-default}"
AWS_REGION="${AWS_REGION:-us-east-1}"
# ---- END CONFIGURATION ----

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_aws-common.sh"

show_help() {
    cat << EOF
Usage: $0 [aws-subcommand...]
       $0 aws [aws-subcommand...]
       $0 terraform [terraform-args...]

Examples:
  $0 sts get-caller-identity
  $0 s3 ls
  $0 ecr describe-repositories
  $0 terraform plan

Environment:
  AWS auth:   $AWS_AUTH_MODE
  AWS region: ${AWS_DEFAULT_REGION:-$AWS_REGION}

EOF
    show_aws_auth_help
}

aws_args_require_auth() {
    local -a args=("$@")

    if [[ ${#args[@]} -eq 0 ]]; then
        return 1
    fi

    case "${args[0]}" in
        help|-h|--help|version|--version|completion)
            return 1
            ;;
        configure)
            return 1
            ;;
        sso)
            case "${args[1]:-}" in
                ""|help|login|logout)
                    return 1
                    ;;
            esac
            ;;
    esac

    return 0
}

terraform_requires_aws_auth() {
    case "${1:-}" in
        ""|help|-help|--help|fmt|validate|version|-version|--version)
            return 1
            ;;
    esac

    return 0
}

ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help|help)
            show_help
            exit 0
            ;;
        --)
            shift
            while [[ $# -gt 0 ]]; do
                ARGS+=("$1")
                shift
            done
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

if [[ ${#ARGS[@]} -eq 0 ]]; then
    show_help
    exit 0
fi

COMMAND="${ARGS[0]}"
REST=("${ARGS[@]:1}")

if [[ "$COMMAND" == "terraform" ]]; then
    require_cmd terraform "Install Terraform: https://developer.hashicorp.com/terraform/install"

    if terraform_requires_aws_auth "${REST[@]}"; then
        ensure_aws_cli
        require_aws_auth
    fi

    echo -e "${BLUE}Running: terraform ${REST[*]}${NC}"
    echo -e "${BLUE}Auth: $AWS_AUTH_MODE | Region: ${AWS_DEFAULT_REGION:-$AWS_REGION}${NC}"
    echo ""
    exec terraform "${REST[@]}"
fi

ensure_aws_cli

if [[ "$COMMAND" == "aws" ]]; then
    AWS_ARGS=("${REST[@]}")
else
    AWS_ARGS=("$COMMAND" "${REST[@]}")
fi

if aws_args_require_auth "${AWS_ARGS[@]}"; then
    require_aws_auth
fi

exec aws "${AWS_ARGS[@]}"
