#!/usr/bin/env bash

################################################################################
# CODE MAP GENERATOR
################################################################################
#
# PURPOSE:
# Generates a code map for a given path pattern.
# Default: Simple tree structure
# With options: Deep code analysis with file contents
#
# USAGE:
#   ./generate_code_map.sh <path_pattern> [options]
#
# EXAMPLES:
#   ./generate_code_map.sh "config/"
#   ./generate_code_map.sh "config/*"
#   ./generate_code_map.sh "src/App/Security"
#   ./generate_code_map.sh "config/" --deep --max-lines=50
#   ./generate_code_map.sh "config/" --output=config_map.txt
#   ./generate_code_map.sh                # defaults to project root
#
# OPTIONS:
#   --deep                Show file contents (default: tree only)
#   --max-file-size=N     Skip files larger than N bytes (default: 100000)
#   --max-lines=N         Only show first N lines of each file (default: all)
#   --exclude=PATTERN     Exclude files matching pattern (can be used multiple times)
#   --output=FILE         Write output to file instead of stdout
#   --no-line-numbers     Don't show line numbers in file contents
#   --help                Show this help message
#
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURATION & DEFAULTS
# ============================================================================

MAX_FILE_SIZE=100000
MAX_LINES=0
DEEP_MODE=false
SHOW_LINE_NUMBERS=true
OUTPUT_FILE=""
EXCLUDE_PATTERNS=()
PATH_PATTERN=""
PYTHON_BIN=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN="python"
fi

if [ -n "$PYTHON_BIN" ]; then
    if ! "$PYTHON_BIN" -c "import sys" >/dev/null 2>&1; then
        PYTHON_BIN=""
    fi
fi

PYTHON_TREE_SCRIPT=$(cat <<'PY'
import sys

pattern = sys.argv[1]
paths = [line.rstrip("\n") for line in sys.stdin if line.rstrip("\n")]

if not paths:
    print(f"Scope: {pattern}")
    print("(no files)")
    sys.exit(0)

class Node:
    __slots__ = ("children", "is_file")
    def __init__(self):
        self.children = {}
        self.is_file = False

root = Node()
for path in sorted(paths):
    parts = [part for part in path.split("/") if part]
    node = root
    for index, part in enumerate(parts):
        child = node.children.get(part)
        if child is None:
            child = Node()
            node.children[part] = child
        node = child
        if index == len(parts) - 1:
            node.is_file = True

def render(node, prefix=""):
    names = sorted(node.children)
    for idx, name in enumerate(names):
        child = node.children[name]
        last = idx == len(names) - 1
        connector = "`-- " if last else "|-- "
        label = name + ("/" if child.children and not child.is_file else "")
        print(prefix + connector + label)
        if child.children:
            extension = "    " if last else "|   "
            render(child, prefix + extension)

print(f"Scope: {pattern}")
render(root)
PY
)

contains_glob() {
    [[ "$1" == *\** || "$1" == *\?* || "$1" == *\[* ]]
}

list_matching_files() {
    local pattern="$1"
    local raw=()
    local path

    if [ "$pattern" = "." ]; then
        mapfile -t raw < <(git -C "$REPO_ROOT" ls-files --cached --others --exclude-standard)
    else
        mapfile -t raw < <(git -C "$REPO_ROOT" ls-files --cached --others --exclude-standard -- "$pattern")
    fi

    if [ ${#raw[@]} -eq 0 ]; then
        return 0
    fi

    for path in "${raw[@]}"; do
        local skip=false
        for exclude in "${EXCLUDE_PATTERNS[@]}"; do
            if [[ "$path" == *"$exclude"* ]]; then
                skip=true
                break
            fi
        done
        if [ "$skip" = true ]; then
            continue
        fi
        printf '%s\n' "$path"
    done
}

render_tree_from_list() {
    local pattern="$1"

    if [ -n "$PYTHON_BIN" ]; then
        "$PYTHON_BIN" -c "$PYTHON_TREE_SCRIPT" "$pattern"
    else
        echo "Scope: $pattern"
        local paths=()
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            paths+=("$line")
        done

        if [ ${#paths[@]} -eq 0 ]; then
            echo "(no files)"
            return 0
        fi

        declare -A children_map
        declare -A last_added
        declare -A has_children
        local ROOT_KEY="__ROOT__"

        local path parts parent current total name key

        for path in "${paths[@]}"; do
            IFS='/' read -r -a parts <<< "$path"
            parent="$ROOT_KEY"
            current=""
            total=${#parts[@]}
            for ((i=0; i<total; i++)); do
                name="${parts[i]}"
                current="${current:+$current/}$name"
                key="$parent"
                if [[ "${last_added[$key]-}" != "$name" ]]; then
                    children_map[$key]+="${name}"$'\n'
                    last_added[$key]="$name"
                fi
                if (( i < total - 1 )); then
                    has_children[$current]=1
                fi
                parent="$current"
            done
        done

        print_branch() {
            local parent_key="$1"
            local prefix="$2"

            local child_list="${children_map[$parent_key]-}"
            [ -z "$child_list" ] && return 0

            local children=()
            while IFS= read -r child; do
                [ -z "$child" ] && continue
                children+=("$child")
            done <<< "$child_list"

            local count=${#children[@]}
            local idx child child_path connector next_prefix suffix

            for ((idx=0; idx<count; idx++)); do
                child="${children[idx]}"
                local is_last=0
                if [ $idx -eq $((count - 1)) ]; then
                    is_last=1
                fi

                if [ "$parent_key" = "$ROOT_KEY" ]; then
                    connector=$'|-- '
                    if [ $is_last -eq 1 ]; then
                        next_prefix="${prefix}    "
                    else
                        next_prefix="${prefix}|   "
                    fi
                elif [ $is_last -eq 1 ]; then
                    connector=$'`-- '
                    next_prefix="${prefix}    "
                else
                    connector=$'|-- '
                    next_prefix="${prefix}|   "
                fi

                if [ "$parent_key" = "$ROOT_KEY" ]; then
                    child_path="$child"
                else
                    child_path="$parent_key/$child"
                fi

                suffix=""
                if [[ -n "${has_children[$child_path]+x}" ]]; then
                    suffix="/"
                fi

                printf '%s%s%s%s\n' "$prefix" "$connector" "$child" "$suffix"
                print_branch "$child_path" "$next_prefix"
            done
        }

        print_branch "$ROOT_KEY" ""
    fi
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

show_help() {
    sed -n '/^# PURPOSE:/,/^################################################################################$/p' "$0" | sed 's/^# \?//'
    exit 0
}

error() {
    echo "ERROR: $1" >&2
    exit 1
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            ;;
        --deep)
            DEEP_MODE=true
            shift
            ;;
        --max-file-size=*)
            MAX_FILE_SIZE="${1#*=}"
            shift
            ;;
        --max-lines=*)
            MAX_LINES="${1#*=}"
            shift
            ;;
        --no-line-numbers)
            SHOW_LINE_NUMBERS=false
            shift
            ;;
        --exclude=*)
            EXCLUDE_PATTERNS+=("${1#*=}")
            shift
            ;;
        --output=*)
            OUTPUT_FILE="${1#*=}"
            shift
            ;;
        -*)
            error "Unknown option: $1"
            ;;
        *)
            if [ -z "$PATH_PATTERN" ]; then
                PATH_PATTERN="$1"
            else
                error "Multiple path patterns specified. Only one is allowed."
            fi
            shift
            ;;
    esac
done

PATH_PATTERN="${PATH_PATTERN:-.}"

# ============================================================================
# MAIN EXECUTION
# ============================================================================

generate_tree() {
    cd "$REPO_ROOT"

    local pattern="$PATH_PATTERN"
    local clean_path="${pattern%/}"
    if [ -z "$clean_path" ]; then
        clean_path="."
    fi

    local has_glob=false
    if contains_glob "$clean_path"; then
        has_glob=true
    fi

    if [ "$has_glob" = false ] && [ ! -e "$clean_path" ]; then
        error "Path does not exist: $clean_path"
    fi

    if command -v tree >/dev/null 2>&1 && [ "$has_glob" = false ]; then
        local tree_args=("-I" ".git")
        if tree --help 2>&1 | grep -q -- '--gitignore'; then
            tree_args+=("--gitignore")
        fi
        tree "${tree_args[@]}" "$clean_path"
        return 0
    fi

    local matched_files=()
    mapfile -t matched_files < <(list_matching_files "$pattern")

    if [ ${#matched_files[@]} -eq 0 ]; then
        echo "No files found"
        return 0
    fi

    printf '%s\n' "${matched_files[@]}" | sort | render_tree_from_list "$pattern"
}

generate_deep_map() {
    cd "$REPO_ROOT"

    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "                              CODE MAP - DEEP ANALYSIS"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "Path: $PATH_PATTERN"
    echo ""

    local all_files=()
    mapfile -t all_files < <(list_matching_files "$PATH_PATTERN")

    if [ ${#all_files[@]} -eq 0 ]; then
        echo "No files found"
        return 0
    fi

    echo "Found ${#all_files[@]} files"
    echo ""

    echo "─────────────────────────────────────────────────────────────────────────────"
    echo "DIRECTORY STRUCTURE"
    echo "─────────────────────────────────────────────────────────────────────────────"
    echo ""

    printf '%s\n' "${all_files[@]}" | sort | render_tree_from_list "$PATH_PATTERN"

    echo ""
    echo "─────────────────────────────────────────────────────────────────────────────"
    echo "FILE CONTENTS"
    echo "─────────────────────────────────────────────────────────────────────────────"

    for filepath in "${all_files[@]}"; do
        if [ ! -f "$filepath" ]; then
            continue
        fi

        local skip=false
        for pattern in "${EXCLUDE_PATTERNS[@]}"; do
            if [[ "$filepath" == *"$pattern"* ]]; then
                skip=true
                break
            fi
        done

        if [ "$skip" = true ]; then
            continue
        fi

        local filesize
        filesize=$(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath" 2>/dev/null)
        if [ "$filesize" -gt "$MAX_FILE_SIZE" ]; then
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "FILE: $filepath"
            echo "SKIPPED: File too large ($(( filesize / 1024 ))KB)"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            continue
        fi

        local linecount
        linecount=$(wc -l < "$filepath" 2>/dev/null || echo 0)

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "FILE: $filepath"
        echo "SIZE: $filesize bytes | LINES: $linecount"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        if [ $MAX_LINES -gt 0 ]; then
            if [ "$SHOW_LINE_NUMBERS" = true ]; then
                head -n "$MAX_LINES" "$filepath" | cat -n
            else
                head -n "$MAX_LINES" "$filepath"
            fi

            if [ "$linecount" -gt "$MAX_LINES" ]; then
                echo ""
                echo "... (showing first $MAX_LINES of $linecount lines) ..."
            fi
        else
            if [ "$SHOW_LINE_NUMBERS" = true ]; then
                cat -n "$filepath"
            else
                cat "$filepath"
            fi
        fi
    done

    echo ""
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "SUMMARY: ${#all_files[@]} files analyzed"
    echo "═══════════════════════════════════════════════════════════════════════════════"
}

# ============================================================================
# EXECUTE
# ============================================================================

if [ -n "$OUTPUT_FILE" ]; then
    if [ "$DEEP_MODE" = true ]; then
        generate_deep_map > "$OUTPUT_FILE" 2>&1
    else
        generate_tree > "$OUTPUT_FILE" 2>&1
    fi
    echo "Output written to: $OUTPUT_FILE"
else
    if [ "$DEEP_MODE" = true ]; then
        generate_deep_map
    else
        generate_tree
    fi
fi
