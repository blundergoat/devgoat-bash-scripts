#!/usr/bin/env bash

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[preflight]${NC} $*"
}

success() {
    echo -e "${GREEN}[ok]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[warn]${NC} $*"
}

error() {
    echo -e "${RED}[error]${NC} $*" >&2
    exit 1
}

show_help() {
    cat <<'EOF'
Usage: ./scripts/preflight-checks.sh

Codex workflow preflight for devgoat-bash-scripts.

Runs:
  - root repo preflight (lib/**/*.sh + bats)
  - bash -n and shellcheck on shell entrypoints outside lib/
  - php -l on dashboard/*.php
  - scripts/context-validate.sh
  - scripts/deny-dangerous.sh --self-test
EOF
}

run_step() {
    local label="$1"
    shift

    log "$label"
    "$@"
    success "$label"
}

check_additional_shell_files() {
    local -a shell_files=(
        "$REPO_ROOT/help.sh"
        "$REPO_ROOT/preflight-checks.sh"
        "$REPO_ROOT/dashboard/start-dev.sh"
    )
    local file

    while IFS= read -r -d '' file; do
        shell_files+=("$file")
    done < <(find "$REPO_ROOT/scripts" -maxdepth 1 -type f -name '*.sh' -print0 | sort -z)

    for file in "${shell_files[@]}"; do
        bash -n "$file"
    done

    if ! command -v shellcheck > /dev/null 2>&1; then
        error "shellcheck is required for scripts/preflight-checks.sh"
    fi

    shellcheck "${shell_files[@]}"
}

check_dashboard_php() {
    local php_file

    if ! command -v php > /dev/null 2>&1; then
        error "php is required for dashboard linting"
    fi

    while IFS= read -r -d '' php_file; do
        php -l "$php_file" > /dev/null
    done < <(find "$REPO_ROOT/dashboard" -maxdepth 1 -type f -name '*.php' -print0 | sort -z)
}

report_dependency_audit_scope() {
    local manifests=()
    local manifest

    while IFS= read -r -d '' manifest; do
        manifests+=("${manifest#"$REPO_ROOT"/}")
    done < <(find "$REPO_ROOT" -maxdepth 2 -type f \( -name 'package.json' -o -name 'composer.json' -o -name 'Cargo.toml' -o -name 'go.mod' -o -name 'pyproject.toml' \) -print0 | sort -z)

    if [[ ${#manifests[@]} -eq 0 ]]; then
        warn "No package-manager manifests found at repo root; dependency audit not applicable"
        return
    fi

    warn "Dependency manifests detected: ${manifests[*]}"
    warn "Run the stack-native audit command if those manifests become part of the repo workflow"
}

case "${1:-}" in
    "" ) ;;
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        error "Unknown argument: $1"
        ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel)"

run_step "Root repo preflight" "$REPO_ROOT/preflight-checks.sh"
run_step "Extra shell syntax and shellcheck" check_additional_shell_files
run_step "Dashboard PHP lint" check_dashboard_php
run_step "Context validation" "$REPO_ROOT/scripts/context-validate.sh"
run_step "Dangerous-command policy self-test" "$REPO_ROOT/scripts/deny-dangerous.sh" --self-test
report_dependency_audit_scope
success "Codex workflow preflight passed"
