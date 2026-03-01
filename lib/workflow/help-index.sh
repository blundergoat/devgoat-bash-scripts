#!/usr/bin/env bash
# =============================================================================
# Help Index - categorized listing of all available scripts
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

show_help() {
    cat << HELP
Usage: ./help.sh [KEYWORD]

Show available scripts grouped by workflow area.
If KEYWORD is provided, only matching entries are shown.

OPTIONS:
    -h, --help      Show this help message

EXAMPLES:
    ./help.sh
    ./help.sh deploy
    ./help.sh db
HELP
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

if [[ $# -gt 1 ]]; then
    echo "Too many arguments" >&2
    show_help
    exit 1
fi

QUERY="${1:-}"

entry() {
    local name="$1"
    local desc="$2"
    printf "  ${GREEN}%-34s${RESET} ${DIM}%s${RESET}\n" "$name" "$desc"
}

print_category() {
    local title="$1"
    local query="$2"
    shift 2
    local lines=("$@")
    local printed=false

    for line in "${lines[@]}"; do
        local name="${line%%|*}"
        local desc="${line#*|}"
        local haystack="${name} ${desc}"

        if [[ -n "$query" ]] && ! echo "$haystack" | grep -qi -- "$query"; then
            continue
        fi

        if [[ "$printed" == false ]]; then
            echo ""
            echo -e "  ${BOLD}${title}${RESET}"
            echo ""
            printed=true
        fi

        entry "$name" "$desc"
    done
}

echo ""
echo -e "${BOLD}  devgoat-bash-scripts${RESET}"
echo -e "  ${DIM}$(printf '─%.0s' {1..50})${RESET}"

if [[ -n "$QUERY" ]]; then
    echo -e "  ${DIM}filter: ${QUERY}${RESET}"
fi

ROOT_ENTRIES=(
    "help.sh|Script index"
    "preflight-checks.sh|Repo quality gate"
)

WORKFLOW_ENTRIES=(
    "lib/workflow/help-index.sh|Categorized script index"
    "lib/workflow/sync-env.sh|Sync .env.example files"
    "lib/workflow/git-change-branch.sh|Change git branch (renamed from git-checkout)"
    "lib/workflow/git-status.sh|Repository status summary"
)

DOCKER_ENTRIES=(
    "lib/docker/up.sh|Start docker compose services"
    "lib/docker/down.sh|Stop docker compose services"
    "lib/docker/restart.sh|Restart docker compose services"
    "lib/docker/prune.sh|Prune Docker resources"
    "lib/docker/logs-tail.sh|Tail Docker Compose logs"
    "lib/docker/network-heal.sh|Diagnose/prune docker networks"
    "lib/docker/mount-doctor.sh|Inspect container mounts"
)

DB_ENTRIES=(
    "lib/stacks/go/rebuild-database.sh|Go DB rebuild"
    "lib/stacks/go/db-migrate-rollback.sh|Go DB rollback"
    "lib/stacks/go/seed-data.sh|Go DB seeding"
)

HEALTH_ENTRIES=(
    "lib/aws/health-check.sh|Remote AWS infrastructure health checks"
    "lib/health/check-api-auth.sh|Bearer-token API auth probe"
    "lib/health/check-gpu.sh|GPU availability checks"
    "lib/health/port-check.sh|Port listener checks"
    "lib/health/load-test.sh|HTTP load tests"
)

QUALITY_ENTRIES=(
    "lib/quality/preflight.sh|Repo-wide quality checks"
    "lib/quality/lint-shell.sh|bash -n + shellcheck for lib/*.sh"
    "lib/quality/lint-stack.sh|Run stack preflight scripts"
    "lib/quality/patch-lint.sh|Lint only changed shell scripts"
)

DEPS_ENTRIES=(
    "lib/deps/install.sh|Dispatch dependency install by stack"
    "lib/deps/update.sh|Dispatch dependency update by stack"
    "lib/deps/composer.sh|composer pass-through helper"
    "lib/deps/npm.sh|npm pass-through helper"
    "lib/deps/pip.sh|pip3 pass-through helper"
    "lib/deps/cargo.sh|cargo pass-through helper"
)

AWS_ENTRIES=(
    "lib/aws/aws-cli.sh|AWS CLI install/login helpers"
    "lib/aws/terraform.sh|Terraform wrapper"
    "lib/aws/s3-sync.sh|Sync artifacts to S3"
    "lib/aws/cloudfront-invalidate.sh|Invalidate CloudFront cache"
    "lib/aws/secrets-manager-get.sh|Read secrets"
    "lib/aws/secrets-manager-set.sh|Write secrets"
    "lib/aws/secrets-manager-health-check.sh|Validate required secrets"
)

STACKS_ENTRIES=(
    "lib/stacks/php/setup.sh|PHP setup"
    "lib/stacks/php/preflight-checks.sh|PHP quality gates"
    "lib/stacks/php/check-complexity.php|PHP complexity analyzer"
    "lib/stacks/node/setup.sh|Node setup"
    "lib/stacks/node/preflight-checks.sh|Node quality gates"
    "lib/stacks/python/setup.sh|Python setup"
    "lib/stacks/python/preflight-checks.sh|Python quality gates"
    "lib/stacks/rust/setup.sh|Rust setup"
    "lib/stacks/rust/preflight-checks.sh|Rust quality gates"
    "lib/stacks/go/rebuild-database.sh|Go DB rebuild"
    "lib/stacks/go/db-migrate-rollback.sh|Go DB rollback"
    "lib/stacks/go/seed-data.sh|Go DB seeding"
)

AI_CLI_ENTRIES=(
    "lib/ai-cli/install-*.sh|AI CLI installers"
    "lib/ai-cli/uninstall-*.sh|AI CLI uninstallers"
)

MAINTENANCE_ENTRIES=(
    "lib/maintenance/git-cleanup.sh|Delete merged local branches"
    "lib/maintenance/make-scripts-executable.sh|Restore +x on scripts"
    "lib/maintenance/remove-zone-identifier.sh|Remove Zone.Identifier files"
    "lib/maintenance/scan-secrets.sh|Scan for committed secrets"
)

TOOLS_ENTRIES=(
    "lib/tools/install-bats-core.sh|Install bats-core"
    "lib/tools/install-ollama.sh|Install Ollama"
    "lib/tools/uninstall-ollama.sh|Uninstall Ollama"
    "lib/tools/install-starship.sh|Install Starship"
    "lib/tools/uninstall-starship.sh|Uninstall Starship"
)

CODEGEN_ENTRIES=(
    "lib/codegen/generate-code-map.sh|Generate repository code map"
)

DASHBOARD_ENTRIES=(
    "dashboard/start-dev.sh|Launch PHP dashboard UI"
)

print_category "Root" "$QUERY" "${ROOT_ENTRIES[@]}"
print_category "Workflow" "$QUERY" "${WORKFLOW_ENTRIES[@]}"
print_category "Dependencies" "$QUERY" "${DEPS_ENTRIES[@]}"
print_category "Docker" "$QUERY" "${DOCKER_ENTRIES[@]}"
print_category "Database" "$QUERY" "${DB_ENTRIES[@]}"
print_category "Health" "$QUERY" "${HEALTH_ENTRIES[@]}"
print_category "Quality" "$QUERY" "${QUALITY_ENTRIES[@]}"
print_category "AWS" "$QUERY" "${AWS_ENTRIES[@]}"
print_category "Stacks" "$QUERY" "${STACKS_ENTRIES[@]}"
print_category "AI CLI" "$QUERY" "${AI_CLI_ENTRIES[@]}"
print_category "Maintenance" "$QUERY" "${MAINTENANCE_ENTRIES[@]}"
print_category "Tools" "$QUERY" "${TOOLS_ENTRIES[@]}"
print_category "Codegen" "$QUERY" "${CODEGEN_ENTRIES[@]}"
print_category "Dashboard" "$QUERY" "${DASHBOARD_ENTRIES[@]}"

echo ""
echo -e "  ${DIM}Run any script with --help for usage details.${RESET}"
echo ""
