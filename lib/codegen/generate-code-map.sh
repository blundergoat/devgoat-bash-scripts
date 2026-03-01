#!/usr/bin/env bash

################################################################################
# CODE MAP GENERATOR
################################################################################
#
# PURPOSE:
# Generates a code map for a given path pattern.
# Default: Annotated tree structure (`path/ = description`)
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Use the git root of the cwd (set by the dashboard to the selected project),
# falling back to two levels up from the script (repo root from lib/codegen/).
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || { cd "$SCRIPT_DIR/../.." && pwd; })"

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

annotation_for_path() {
    local rel_path="$1"
    local is_dir="$2"
    local name="${rel_path##*/}"
    local annotation=""

    case "$rel_path" in
        ai-cli) annotation="CLI installer/uninstaller scripts for coding assistants" ;;
        assets) annotation="scss, javascript, typescript" ;;
        aws) annotation="AWS automation and deployment helper scripts" ;;
        bin) annotation="doctrine and database scripts, base data sql" ;;
        codegen) annotation="code generation utilities" ;;
        config) annotation="yaml config for packages, site params, routing, services" ;;
        dev) annotation="local development workflow scripts" ;;
        docs) annotation="most important docs specific to this project (guidelines, overviews, processes)" ;;
        maintenance) annotation="repo maintenance and housekeeping scripts" ;;
        migrations) annotation="database migrations" ;;
        public/apps) annotation="telehealth apps for sites without CDN (often a webroot symlink target)" ;;
        public/build) annotation="compiled css/js assets uploaded to CDN" ;;
        public/bundles) annotation="composer package asset files uploaded to CDN" ;;
        public/static) annotation="static assets for localdev or CDN" ;;
        setup) annotation="tool installation and environment bootstrap scripts" ;;
        src) annotation="main project source files" ;;
        stacks) annotation="language-specific project setup and quality gates" ;;
        stacks/go) annotation="Go stack scripts" ;;
        stacks/node) annotation="Node.js stack scripts" ;;
        stacks/php) annotation="PHP stack scripts" ;;
        stacks/python) annotation="Python stack scripts" ;;
        templates) annotation="template/view files (twig, blade, etc.)" ;;
        tests) annotation="unit/integration test suites" ;;
        var) annotation="runtime logs and cache" ;;
        vendor) annotation="third-party dependencies" ;;
        lib) annotation="reusable shell scripts organized by domain" ;;
    esac
    if [ -n "$annotation" ]; then
        echo "$annotation"
        return 0
    fi

    case "$name" in
        index.php|index_dev.php|index_prod.php|index_local.php)
            echo "webroot entrypoint selected by environment"
            return 0
            ;;
    esac

    if [[ "$is_dir" == "true" ]]; then
        case "$name" in
            docs) annotation="project documentation" ;;
            config) annotation="application configuration" ;;
            migrations) annotation="database schema changes" ;;
            templates) annotation="template files" ;;
            tests) annotation="automated tests" ;;
            vendor) annotation="third-party dependencies" ;;
            src) annotation="application source code" ;;
        esac
    fi

    if [ -n "$annotation" ]; then
        echo "$annotation"
    fi
}

render_tree_from_list() {
    local root_label="$1"
    local paths=()
    declare -A explicit_dirs
    local line
    while IFS= read -r line; do
        local is_explicit_dir="false"
        if [[ "$line" == */ ]]; then
            is_explicit_dir="true"
        fi
        line="${line#./}"
        line="${line%/}"
        [ -z "$line" ] && continue
        paths+=("$line")
        if [[ "$is_explicit_dir" == "true" ]]; then
            explicit_dirs["$line"]=1
        fi
    done

    if [ -n "$root_label" ]; then
        echo "$root_label"
    fi

    if [ ${#paths[@]} -eq 0 ]; then
        echo "(no files)"
        return 0
    fi

    declare -A children_map
    declare -A seen_child
    declare -A has_children
    local ROOT_KEY="__ROOT__"

    local path parent current total part node_key i
    for path in "${paths[@]}"; do
        IFS='/' read -r -a parts <<< "$path"
        parent="$ROOT_KEY"
        current=""
        total=${#parts[@]}
        for ((i=0; i<total; i++)); do
            part="${parts[i]}"
            current="${current:+$current/}$part"
            node_key="${parent}|${part}"
            if [[ -z "${seen_child[$node_key]+x}" ]]; then
                children_map["$parent"]+="${part}"$'\n'
                seen_child["$node_key"]=1
            fi
            if (( i < total - 1 )); then
                has_children["$current"]=1
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
        mapfile -t children < <(printf '%s' "$child_list" | sed '/^$/d' | sort)

        local idx child child_path connector next_prefix is_dir display_name annotation
        for ((idx=0; idx<${#children[@]}; idx++)); do
            child="${children[idx]}"
            if [ $idx -eq $(( ${#children[@]} - 1 )) ]; then
                connector="└── "
                next_prefix="${prefix}    "
            else
                connector="├── "
                next_prefix="${prefix}│   "
            fi

            if [ "$parent_key" = "$ROOT_KEY" ]; then
                child_path="$child"
            else
                child_path="$parent_key/$child"
            fi

            is_dir="false"
            if [[ -n "${has_children[$child_path]+x}" ]] || [[ -n "${explicit_dirs[$child_path]+x}" ]]; then
                is_dir="true"
            fi

            display_name="$child"
            if [[ "$is_dir" == "true" ]]; then
                display_name="${display_name}/"
            fi

            annotation=$(annotation_for_path "$child_path" "$is_dir")
            if [ -n "$annotation" ]; then
                printf '%s%s%-20s = %s\n' "$prefix" "$connector" "$display_name" "$annotation"
            else
                printf '%s%s%s\n' "$prefix" "$connector" "$display_name"
            fi

            if [[ "$is_dir" == "true" ]]; then
                print_branch "$child_path" "$next_prefix"
            fi
        done
    }

    print_branch "$ROOT_KEY" ""
}

render_tree_for_pattern() {
    local pattern="$1"
    local directories_only="${2:-false}"
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

    local matched_files=()
    mapfile -t matched_files < <(list_matching_files "$pattern")
    if [ ${#matched_files[@]} -eq 0 ]; then
        echo "No files found"
        return 0
    fi

    if [ "$has_glob" = false ] && [ -f "$clean_path" ]; then
        local single_file="${clean_path##*/}"
        local single_annotation
        single_annotation=$(annotation_for_path "$clean_path" "false")
        if [ -n "$single_annotation" ]; then
            printf '%s = %s\n' "$single_file" "$single_annotation"
        else
            echo "$single_file"
        fi
        return 0
    fi

    local root_label
    if [ "$has_glob" = true ]; then
        root_label="Scope: $pattern"
    elif [ "$clean_path" = "." ]; then
        root_label="$(pwd)/"
    else
        local resolved_root
        resolved_root="$(cd "$clean_path" && pwd)"
        root_label="$resolved_root/"
    fi

    local display_files=()
    local file
    if [ "$has_glob" = false ] && [ "$clean_path" != "." ]; then
        for file in "${matched_files[@]}"; do
            if [[ "$file" == "$clean_path/"* ]]; then
                display_files+=("${file#"$clean_path"/}")
            elif [[ "$file" == "$clean_path" ]]; then
                display_files+=("${file##*/}")
            fi
        done
    else
        display_files=("${matched_files[@]}")
    fi

    if [ "$directories_only" = true ]; then
        declare -A dir_map
        local entry dir
        for entry in "${display_files[@]}"; do
            entry="${entry#./}"
            entry="${entry%/}"
            [ -z "$entry" ] && continue

            if [[ "$entry" == */* ]]; then
                dir="${entry%/*}"
            else
                continue
            fi

            while [ -n "$dir" ] && [ "$dir" != "." ]; do
                dir_map["$dir"]=1
                if [[ "$dir" == */* ]]; then
                    dir="${dir%/*}"
                else
                    break
                fi
            done
        done

        display_files=()
        local map_dir
        for map_dir in "${!dir_map[@]}"; do
            display_files+=("${map_dir}/")
        done

        if [ ${#display_files[@]} -eq 0 ]; then
            echo "No directories found"
            return 0
        fi
    fi

    printf '%s\n' "${display_files[@]}" | sort | render_tree_from_list "$root_label"
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
    render_tree_for_pattern "$PATH_PATTERN" "true"
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

    render_tree_for_pattern "$PATH_PATTERN"

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

        if [ "$MAX_LINES" -gt 0 ]; then
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
