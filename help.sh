#!/usr/bin/env bash
# =============================================================================
# Help — categorized listing of all available scripts
# =============================================================================
#
# Usage:
#   ./help.sh
#   ./help.sh -h|--help
#
# =============================================================================

set -euo pipefail

# --- Colors ---
GREEN='\033[0;32m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

show_help() {
    cat << EOF
Usage: $0

Lists all available scripts in the devgoat-bash-scripts repository,
organized by domain.

OPTIONS:
    -h, --help      Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

entry() {
    local name="$1" desc="$2"
    printf "  ${GREEN}%-42s${RESET} ${DIM}%s${RESET}\n" "$name" "$desc"
}

echo ""
echo -e "${BOLD}  devgoat-bash-scripts${RESET}"
echo -e "  ${DIM}$(printf '─%.0s' {1..50})${RESET}"

# ── Root ──────────────────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}Root Tools${RESET}"
echo ""
entry "help.sh" "This listing — all available scripts"
entry "preflight-checks.sh" "Repo-wide quality gate (shebang, strict mode, shellcheck)"

# ── AI CLI ────────────────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}AI CLI${RESET}  ${DIM}(lib/ai-cli/)${RESET}"
echo ""
entry "install-claude.sh" "Install Claude Code"
entry "install-codex.sh" "Install OpenAI Codex"
entry "install-cursor-agent.sh" "Install Cursor Agent"
entry "install-gemini-cli.sh" "Install Gemini CLI"
entry "install-github-copilot.sh" "Install GitHub Copilot CLI"
entry "install-kilo.sh" "Install Kilo Code"
entry "install-kiro-cli.sh" "Install Kiro CLI"
entry "uninstall-*.sh" "Matching uninstallers for each tool above"

# ── AWS ───────────────────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}AWS${RESET}  ${DIM}(lib/aws/ — all templates)${RESET}"
echo ""
entry "aws-cli.sh" "AWS CLI install/upgrade, SSO login"
entry "terraform.sh" "Terraform init/plan/apply with S3 backend"
entry "deploy-ecr-ecs.sh" "Build → ECR push → ECS redeploy"
entry "s3-sync.sh" "Sync build artifacts to S3"
entry "cloudfront-invalidate.sh" "Invalidate CloudFront cache"
entry "secrets-manager-*.sh" "Get, set, and health-check secrets"
entry "amplify-*.sh" "Amplify env var management and health checks"

# ── Code Generation ──────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}Code Generation${RESET}  ${DIM}(lib/codegen/)${RESET}"
echo ""
entry "generate-code-map.sh" "Annotated directory tree (drop-in)"

# ── Development ──────────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}Development${RESET}  ${DIM}(lib/dev/)${RESET}"
echo ""
entry "start-dev.sh" "Start local dev environment (template)"
entry "docker-cleanup.sh" "Prune unused Docker resources (drop-in)"
entry "port-check.sh" "Check port listeners, show PID/process (drop-in)"
entry "gpu-check.sh" "Detect NVIDIA GPU availability (drop-in)"
entry "health-check-localdev.sh" "Verify local services (template)"
entry "health-check-remote.sh" "Check remote AWS health (template)"
entry "db-reset.sh" "Drop/create/migrate/seed database (template)"
entry "api-load-test.sh" "HTTP load testing with curl (template)"
entry "docker-logs.sh" "Tail Docker Compose service logs (template)"
entry "sync-env.sh" "Copy .env.example → .env where missing (template)"

# ── Maintenance ──────────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}Maintenance${RESET}  ${DIM}(lib/maintenance/ — all drop-in)${RESET}"
echo ""
entry "git-cleanup.sh" "Delete merged local branches"
entry "lint-all.sh" "Run bash -n + shellcheck on all scripts"
entry "make-scripts-executable.sh" "chmod +x all .sh files"
entry "remove-zone-identifier.sh" "Remove Windows Zone.Identifier ADS files"
entry "scan-secrets.sh" "Scan for accidentally committed secrets"

# ── Tools ────────────────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}Tools${RESET}  ${DIM}(lib/tools/)${RESET}"
echo ""
entry "install-bats-core.sh" "Install bats-core test framework"
entry "install-ollama.sh" "Install Ollama for local LLM inference"
entry "uninstall-ollama.sh" "Uninstall Ollama"
entry "install-starship.sh" "Install Starship cross-shell prompt"
entry "uninstall-starship.sh" "Uninstall Starship"

# ── Stacks ───────────────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}Stacks${RESET}  ${DIM}(lib/stacks/ — all templates)${RESET}"
echo ""
entry "php/setup.sh" "First-time PHP project setup"
entry "php/preflight-checks.sh" "Quality gates: CS-Fixer, PHPStan, PHPUnit"
entry "php/check-complexity.php" "Cyclomatic complexity analyzer (drop-in)"
entry "node/setup.sh" "First-time Node.js project setup"
entry "node/preflight-checks.sh" "Quality gates: eslint, tsc, jest/vitest"
entry "python/setup.sh" "First-time Python project setup"
entry "python/preflight-checks.sh" "Quality gates: ruff, pytest"
entry "go/rebuild-database.sh" "Drop tables, migrate, seed"
entry "go/db-migrate-rollback.sh" "Safe migration rollback with backup"

# ── Dashboard ────────────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}Dashboard${RESET}  ${DIM}(dashboard/)${RESET}"
echo ""
entry "start.sh" "Launch PHP web UI for running scripts (template)"

# ── Footer ───────────────────────────────────────────────────────
echo ""
echo -e "  ${DIM}$(printf '─%.0s' {1..50})${RESET}"
echo -e "  ${DIM}Drop-in scripts run as-is. Templates need a CONFIGURATION block filled in.${RESET}"
echo -e "  ${DIM}Run any script with --help for usage details.${RESET}"
echo ""
