#!/usr/bin/env bash

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[context]${NC} $*"
}

success() {
    echo -e "${GREEN}[ok]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[warn]${NC} $*"
}

fail() {
    echo -e "${RED}[fail]${NC} $*" >&2
    FAILURES=$((FAILURES + 1))
}

show_help() {
    cat <<'EOF'
Usage: ./scripts/context-validate.sh

Validate the Codex workflow assets:
  - AGENTS.md line count and required sections
  - AGENTS.md router targets
  - playbook required sections
  - lessons/footguns/ownership docs
  - executable verification scripts
  - tasks runtime files
  - Codex eval uniqueness

Exit codes:
  0  All checks passed
  1  One or more checks failed
EOF
}

check_required_heading() {
    local file="$1"
    local pattern="$2"

    if ! grep -qF "$pattern" "$file"; then
        fail "Missing heading '$pattern' in ${file#"$REPO_ROOT"/}"
    fi
}

is_optional_runtime_path() {
    local path="$1"

    case "$path" in
        docs/confusion-log.md|\
        tasks/todo.md|tasks/handoff.md)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

check_agents() {
    local agents_file="$REPO_ROOT/AGENTS.md"
    local line_count

    line_count=$(wc -l < "$agents_file")
    log "AGENTS.md: ${line_count} lines"

    if (( line_count > 150 )); then
        fail "AGENTS.md exceeds 150 line hard ceiling ($line_count)"
    elif (( line_count > 135 )); then
        warn "AGENTS.md exceeds 135 line target ($line_count)"
    fi

    check_required_heading "$agents_file" "## Essential Commands"
    check_required_heading "$agents_file" "## Execution Loop: READ → CLASSIFY → SCOPE → ACT → VERIFY → LOG"
    check_required_heading "$agents_file" "## Autonomy Tiers"
    check_required_heading "$agents_file" "## Definition of Done"
    check_required_heading "$agents_file" "## Working Memory"
    check_required_heading "$agents_file" "## Sub-Agent Objectives"
    check_required_heading "$agents_file" "## Communication When Blocked"
    check_required_heading "$agents_file" "## Router"
}

check_router_targets() {
    local agents_file="$REPO_ROOT/AGENTS.md"
    local in_router=false
    local line raw_path path

    while IFS= read -r line; do
        if [[ "$line" == "## Router" ]]; then
            in_router=true
            continue
        fi

        if [[ "$in_router" != true ]]; then
            continue
        fi

        if [[ -z "$line" ]]; then
            break
        fi

        if [[ "$line" != \|* ]]; then
            continue
        fi

        raw_path="$(printf '%s\n' "$line" | awk -F'|' '{print $3}' | xargs)"
        if [[ -z "$raw_path" || "$raw_path" == "Path" || "$raw_path" == "---" ]]; then
            continue
        fi

        path="${raw_path//\`/}"
        if [[ "$path" == *"*"* ]]; then
            if ! compgen -G "$REPO_ROOT/$path" > /dev/null; then
                fail "Router target missing: $path"
            fi
        elif is_optional_runtime_path "$path" && [[ ! -e "$REPO_ROOT/$path" ]]; then
            warn "Optional local runtime file absent in this checkout: $path"
        elif [[ ! -e "$REPO_ROOT/$path" ]]; then
            fail "Router target missing: $path"
        fi
    done < "$agents_file"
}

check_playbooks() {
    local dir="$REPO_ROOT/docs/codex-playbooks"
    local count

    count=$(find "$dir" -maxdepth 1 -type f -name '*.md' | wc -l)
    if [[ "$count" -ne 5 ]]; then
        fail "Expected 5 playbooks in docs/codex-playbooks, found $count"
    fi

    check_required_heading "$dir/goat-preflight.md" "## MUST"
    check_required_heading "$dir/goat-preflight.md" "## SHOULD"
    check_required_heading "$dir/goat-preflight.md" "## MAY"
    check_required_heading "$dir/goat-preflight.md" "## Output"

    check_required_heading "$dir/goat-research.md" "## Hard Gate"
    check_required_heading "$dir/goat-research.md" "### Files Involved"
    check_required_heading "$dir/goat-research.md" "### Request Flow"
    check_required_heading "$dir/goat-research.md" "### Boundaries Touched"
    check_required_heading "$dir/goat-research.md" "### Risks / Gotchas"

    check_required_heading "$dir/goat-debug.md" "## Hard Gate"
    check_required_heading "$dir/goat-debug.md" "## Workflow"
    check_required_heading "$dir/goat-debug.md" "## Diagnosis Template"

    check_required_heading "$dir/goat-audit.md" "## Pass 1"
    check_required_heading "$dir/goat-audit.md" "## Pass 2"
    check_required_heading "$dir/goat-audit.md" "## Pass 3"
    check_required_heading "$dir/goat-audit.md" "## Pass 4"
    check_required_heading "$dir/goat-audit.md" "## Self-Check"

    check_required_heading "$dir/goat-review.md" "## Severity"
    check_required_heading "$dir/goat-review.md" "## Review Flow"
    check_required_heading "$dir/goat-review.md" "## Output"
}

check_docs() {
    local architecture_lines
    local lessons_file="$REPO_ROOT/docs/lessons.md"
    local split_file="$REPO_ROOT/docs/guidelines-ownership-split.md"

    architecture_lines=$(wc -l < "$REPO_ROOT/docs/architecture.md")
    if (( architecture_lines > 100 )); then
        fail "docs/architecture.md exceeds 100 lines ($architecture_lines)"
    fi

    check_required_heading "$lessons_file" "## Patterns"
    check_required_heading "$lessons_file" "## Entries"
    check_required_heading "$split_file" "## Before / After Overlap Report"
}

check_footguns() {
    local footguns_file="$REPO_ROOT/docs/footguns.md"
    local entry_count ref_count
    local ref clean_ref path line total_lines
    local footgun_ref_regex

    if grep -qi "none confirmed yet" "$footguns_file"; then
        success "docs/footguns.md explicitly states none confirmed yet"
        return
    fi

    entry_count=$(grep -c '^## Footgun:' "$footguns_file")
    if (( entry_count == 0 )); then
        fail "docs/footguns.md has no '## Footgun:' entries"
        return
    fi

    footgun_ref_regex="\`[^\`]+:[0-9]+\`"
    ref_count=$(grep -oE "$footgun_ref_regex" "$footguns_file" | wc -l)
    if (( ref_count == 0 )); then
        fail "docs/footguns.md has no backticked file:line evidence"
        return
    fi

    while IFS= read -r ref; do
        clean_ref="${ref#\`}"
        clean_ref="${clean_ref%\`}"
        path="${clean_ref%:*}"
        line="${clean_ref##*:}"

        if [[ ! -f "$REPO_ROOT/$path" ]]; then
            fail "Footgun evidence path missing: $path"
            continue
        fi

        total_lines=$(wc -l < "$REPO_ROOT/$path")
        if (( line < 1 || line > total_lines )); then
            fail "Footgun evidence out of range: $clean_ref"
        fi
    done < <(grep -oE "$footgun_ref_regex" "$footguns_file")
}

check_tasks() {
    local todo_file="$REPO_ROOT/tasks/todo.md"
    local handoff_file="$REPO_ROOT/tasks/handoff.md"

    if [[ ! -f "$todo_file" ]]; then
        warn "Optional local runtime file absent in this checkout: tasks/todo.md"
    fi

    if [[ ! -f "$handoff_file" ]]; then
        warn "Optional local runtime file absent in this checkout: tasks/handoff.md"
    fi
}

check_scripts() {
    local script
    for script in \
        "$REPO_ROOT/scripts/context-validate.sh" \
        "$REPO_ROOT/scripts/deny-dangerous.sh" \
        "$REPO_ROOT/scripts/preflight-checks.sh"; do
        if [[ ! -x "$script" ]]; then
            fail "Verification script is not executable: ${script#"$REPO_ROOT"/}"
        fi
    done
}

check_evals() {
    local eval_dir="$REPO_ROOT/agent-evals"
    local eval_count
    local eval_file

    [[ -f "$eval_dir/README.md" ]] || fail "Missing agent-evals/README.md"
    eval_count=$(find "$eval_dir" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' | wc -l)
    if (( eval_count < 1 )); then
        fail "Expected at least 1 agent eval, found $eval_count"
    fi

    while IFS= read -r -d '' eval_file; do
        check_required_heading "$eval_file" "**Origin:**"
        check_required_heading "$eval_file" "**Agents:**"
        check_required_heading "$eval_file" "**Bug description:**"
        check_required_heading "$eval_file" "**Replay prompt:**"
        check_required_heading "$eval_file" "**Expected outcome:**"
        check_required_heading "$eval_file" "**Failure mode tested:**"
    done < <(find "$eval_dir" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' -print0 | sort -z)

    if [[ -d "$REPO_ROOT/.claude/skills" ]]; then
        eval_count=$(find "$REPO_ROOT/.claude/skills" -mindepth 1 -maxdepth 1 -type d -name 'goat-*' | wc -l)
        if (( eval_count != 5 )); then
            fail "Expected 5 Claude goat skill directories, found $eval_count"
        fi
    fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

if [[ $# -gt 0 ]]; then
    echo "Unknown argument: $1" >&2
    show_help
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel)"
FAILURES=0

log "Validating Codex workflow assets"
check_agents
check_router_targets
check_playbooks
check_docs
check_footguns
check_tasks
check_scripts
check_evals

if (( FAILURES > 0 )); then
    echo ""
    echo -e "${RED}[fail]${NC} Context validation failed with $FAILURES issue(s)" >&2
    exit 1
fi

success "Context validation passed"
