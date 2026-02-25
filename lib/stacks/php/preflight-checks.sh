#!/usr/bin/env bash
# =============================================================================
# PHP Preflight Checks - Run all PHP quality gates before committing
# =============================================================================
# Usage: ./lib/stacks/php/preflight-checks.sh [--coverage-min=80] [--mutate]
# =============================================================================

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"

# ---- CONFIGURATION ----
PROJECT_NAME="${PROJECT_NAME:-my-project}"
SRC_DIR="${SRC_DIR:-src}"
TEMPLATES_DIR="${TEMPLATES_DIR:-templates}"
COMPLEXITY_SCRIPT="${COMPLEXITY_SCRIPT:-lib/stacks/php/check-complexity.php}"
MAX_COMPLEXITY="${MAX_COMPLEXITY:-20}"
COMPOSE_FILE_NAME="${COMPOSE_FILE_NAME:-docker-compose.yml}"
# ---- END CONFIGURATION ----

cd "$PROJECT_ROOT"

MIN_COVERAGE=80
RUN_MUTATE=false

for arg in "$@"; do
    case "$arg" in
        --mutate)
            RUN_MUTATE=true
            ;;
        --coverage-min=*)
            MIN_COVERAGE="${arg#*=}"
            ;;
    esac
done

if ! [[ "$MIN_COVERAGE" =~ ^[0-9]+$ ]] || ((MIN_COVERAGE < 0 || MIN_COVERAGE > 100)); then
    echo "Invalid --coverage-min value: '$MIN_COVERAGE' (expected integer 0-100)"
    exit 1
fi

# ── Checks ────────────────────────────────────────────────────────
header "Preflight Check (PHP) - ${PROJECT_NAME}"
echo -e "  ${DIM}$(date '+%Y-%m-%d %H:%M:%S')${RESET}"
echo ""

# 1. Composer validate
step "Composer validate"
t=$(date +%s%N)
if composer validate --strict 2>&1 | grep -q "is valid"; then
    pass "$(elapsed_since $t)"
else
    fail "Composer validate"
fi

# 2. Security audit
step "Security audit"
t=$(date +%s%N)
audit_output=$(composer audit 2>&1)
audit_exit=$?
if [[ $audit_exit -eq 0 ]]; then
    pass "$(elapsed_since $t)"
else
    vuln_count=$(echo "$audit_output" | grep -c "Advisory" || true)
    fail "Security audit (${vuln_count} advisories)"
    echo "$audit_output" | head -20 | while read -r line; do
        echo -e "    ${DIM}${line}${RESET}"
    done
fi

# 3. Code style (PHP-CS-Fixer)
step "Code style (PHP-CS-Fixer)"
t=$(date +%s%N)
if [[ -x vendor/bin/php-cs-fixer ]]; then
    cs_output=$(vendor/bin/php-cs-fixer fix --dry-run --diff 2>&1)
    cs_exit=$?
    if [[ $cs_exit -eq 0 ]]; then
        pass "$(elapsed_since $t)"
    else
        fix_count=$(echo "$cs_output" | grep -c "^   [0-9]*)" || true)
        fail "Code style (${fix_count} files need fixing - run composer cs:fix)"
    fi
else
    skip "php-cs-fixer not installed"
fi

# 4. Cyclomatic complexity
step "Cyclomatic complexity (max ${MAX_COMPLEXITY})"
t=$(date +%s%N)
complexity_script="$PROJECT_ROOT/${COMPLEXITY_SCRIPT}"
if [[ -f "$complexity_script" ]]; then
    complexity_output=$(php "$complexity_script" --path="${SRC_DIR}" --max="${MAX_COMPLEXITY}" 2>&1)
    complexity_exit=$?
    if [[ $complexity_exit -eq 0 ]]; then
        pass "$(elapsed_since $t)"
    else
        violation_count=$(echo "$complexity_output" | grep -c "^ - " || true)
        fail "Cyclomatic complexity (${violation_count} violations)"
        echo "$complexity_output" | head -20 | while read -r line; do
            echo -e "    ${DIM}${line}${RESET}"
        done
    fi
else
    skip "${COMPLEXITY_SCRIPT} not found"
fi

# 5. Mess detector (PHPMD)
step "Mess detector (PHPMD)"
t=$(date +%s%N)
if [[ -x vendor/bin/phpmd ]]; then
    if [[ -f phpmd.xml ]]; then
        phpmd_output=$(vendor/bin/phpmd "${SRC_DIR}" text phpmd.xml 2>&1)
    else
        phpmd_output=$(vendor/bin/phpmd "${SRC_DIR}" text codesize,design,unusedcode 2>&1)
    fi
    phpmd_exit=$?
    if [[ $phpmd_exit -eq 0 ]]; then
        pass "$(elapsed_since $t)"
    else
        violation_count=$(echo "$phpmd_output" | grep -c "." || true)
        fail "Mess detector (${violation_count} violations)"
        echo "$phpmd_output" | head -10 | while read -r line; do
            echo -e "    ${DIM}${line}${RESET}"
        done
    fi
else
    skip "phpmd not installed"
fi

# 6. PHPStan
step "Static analysis (PHPStan L10)"
t=$(date +%s%N)
if [[ -x vendor/bin/phpstan ]]; then
    if [[ -f phpstan.neon || -f phpstan.neon.dist ]]; then
        stan_output=$(vendor/bin/phpstan analyse --no-progress --error-format=raw 2>&1)
    else
        stan_output=$(vendor/bin/phpstan analyse "${SRC_DIR}" --no-progress --error-format=raw 2>&1)
    fi
    stan_exit=$?
    if [[ $stan_exit -eq 0 ]]; then
        pass "$(elapsed_since $t)"
    else
        err_count=$(echo "$stan_output" | grep -cE "^/" || true)
        fail "Static analysis (${err_count} errors)"
        echo "$stan_output" | grep -E "^/" | head -10 | while read -r line; do
            echo -e "    ${DIM}${line}${RESET}"
        done
    fi
else
    skip "phpstan not installed"
fi

# 7. Twig lint
step "Twig templates lint"
t=$(date +%s%N)
if [[ -d "${TEMPLATES_DIR}" ]]; then
    twig_errors=0
    for f in "${TEMPLATES_DIR}"/*.html.twig; do
        if [[ -f "$f" ]]; then
            open_blocks=$(grep -cE '\{%\s*block\s' "$f" 2>/dev/null || echo "0")
            close_blocks=$(grep -cE '\{%\s*endblock' "$f" 2>/dev/null || echo "0")
            if [[ "$open_blocks" != "$close_blocks" ]]; then
                twig_errors=$((twig_errors + 1))
            fi
        fi
    done
    if [[ $twig_errors -eq 0 ]]; then
        twig_count=$(ls "${TEMPLATES_DIR}"/*.html.twig 2>/dev/null | wc -l)
        pass "${twig_count} templates $(elapsed_since $t)"
    else
        fail "Twig templates (${twig_errors} files with unclosed blocks)"
    fi
else
    skip "no ${TEMPLATES_DIR}/ directory"
fi

# 8. Docker Compose validate
step "Docker Compose config"
t=$(date +%s%N)
compose_file="$PROJECT_ROOT/${COMPOSE_FILE_NAME}"
if [[ -f "$compose_file" ]] && command -v docker &>/dev/null; then
    compose_output=$(docker compose -f "$compose_file" config --quiet 2>&1)
    compose_exit=$?
    if [[ $compose_exit -eq 0 ]]; then
        service_count=$(docker compose -f "$compose_file" config --services 2>/dev/null | wc -l)
        pass "${service_count} services $(elapsed_since $t)"
    else
        fail "Docker Compose config"
        echo "$compose_output" | head -5 | while read -r line; do
            echo -e "    ${DIM}${line}${RESET}"
        done
    fi
elif [[ ! -f "$compose_file" ]]; then
    skip "no ${COMPOSE_FILE_NAME}"
else
    skip "docker not available"
fi

# 9. PHPUnit
step "Tests (PHPUnit)"
t=$(date +%s%N)
if [[ ! -x vendor/bin/phpunit ]]; then
    skip "phpunit not installed"
elif [[ ! -f phpunit.xml && ! -f phpunit.xml.dist ]]; then
    skip "no phpunit.xml config"
else
    test_output=$(vendor/bin/phpunit 2>&1)
    test_exit=$?
    if [[ $test_exit -eq 0 ]]; then
        test_summary=$(echo "$test_output" | grep -oE '[0-9]+ tests, [0-9]+ assertions' || echo "")
        if [[ -z "$test_summary" ]]; then
            test_summary=$(echo "$test_output" | grep -oE 'No tests executed' || echo "no tests")
        fi
        pass "${test_summary} $(elapsed_since $t)"
    else
        fail_count=$(echo "$test_output" | grep -oE '[0-9]+ failure' | grep -oE '[0-9]+' || echo "?")
        fail "Tests (${fail_count} failures)"
        echo "$test_output" | grep -A2 "^[0-9]*)" | head -15 | while read -r line; do
            echo -e "    ${DIM}${line}${RESET}"
        done
    fi
fi

# 10. Coverage
step "Coverage (PHPUnit)"
t=$(date +%s%N)
if [[ ! -f phpunit.xml && ! -f phpunit.xml.dist ]]; then
    skip "no phpunit.xml config"
elif ! php -m 2>/dev/null | grep -qi "xdebug\|pcov"; then
    skip "no coverage driver (install xdebug or pcov)"
elif [[ ! -x vendor/bin/phpunit ]]; then
    skip "phpunit not installed"
else
    coverage_output=$(XDEBUG_MODE=coverage vendor/bin/phpunit --coverage-clover=coverage.xml 2>&1)
    coverage_exit=$?

    if [[ $coverage_exit -ne 0 ]]; then
        fail "Coverage run failed"
        echo "$coverage_output" | tail -20 | while read -r line; do
            echo -e "    ${DIM}${line}${RESET}"
        done
    else
        coverage_stats=$(php -r '
            $xml = @simplexml_load_file("coverage.xml");
            if ($xml === false || !isset($xml->project->metrics)) {
                exit(1);
            }
            $metrics = $xml->project->metrics;
            $statements = (float) ($metrics["statements"] ?? 0);
            $covered = (float) ($metrics["coveredstatements"] ?? 0);
            if ($statements <= 0.0) {
                echo "0.00|0|0";
                exit(0);
            }
            echo number_format(($covered / $statements) * 100, 2, ".", "") . "|" . (int) $covered . "|" . (int) $statements;
        ' 2>/dev/null)
        parse_exit=$?
        IFS='|' read -r coverage_pct covered_lines total_lines <<< "$coverage_stats"

        if [[ $parse_exit -ne 0 || -z "$coverage_pct" ]]; then
            fail "Coverage parse failed (coverage.xml)"
            echo "$coverage_output" | tail -10 | while read -r line; do
                echo -e "    ${DIM}${line}${RESET}"
            done
        elif awk "BEGIN {exit !($coverage_pct >= $MIN_COVERAGE)}"; then
            pass "${coverage_pct}% line coverage (${covered_lines}/${total_lines}, min ${MIN_COVERAGE}%) $(elapsed_since $t)"
        else
            fail "Coverage ${coverage_pct}% < ${MIN_COVERAGE}% (${covered_lines}/${total_lines} lines)"
            echo -e "    ${DIM}coverage.xml analyzed successfully; threshold not met${RESET}"
            echo -e "    ${DIM}Tip: run 'composer test:coverage' and inspect lowest-covered classes${RESET}"
        fi
    fi
fi

# 11. Mutation testing (optional)
if [[ "$RUN_MUTATE" == true ]]; then
    step "Mutation testing (Infection)"
    t=$(date +%s%N)
    if [[ ! -x vendor/bin/infection ]]; then
        fail "Mutation testing (infection not installed)"
    elif ! php -m 2>/dev/null | grep -qi "xdebug\|pcov"; then
        fail "Mutation testing (no coverage driver - install xdebug or pcov)"
    else
        mutate_output=$(XDEBUG_MODE=coverage vendor/bin/infection --threads=4 --show-mutations=0 2>&1)
        mutate_exit=$?
        if [[ $mutate_exit -eq 0 ]]; then
            msi=$(echo "$mutate_output" | grep -oE 'Covered Code MSI: [0-9]+%' | grep -oE '[0-9]+%' || echo "")
            killed=$(echo "$mutate_output" | grep -oE '[0-9]+ mutants were killed' | grep -oE '[0-9]+' || echo "")
            total_m=$(echo "$mutate_output" | grep -oE '[0-9]+ mutations were generated' | grep -oE '[0-9]+' || echo "")
            pass "${killed:+${killed}/${total_m} killed }${msi:+(${msi} MSI) }$(elapsed_since $t)"
        else
            msi=$(echo "$mutate_output" | grep -oE 'MSI:[[:space:]]*[0-9]+%' | head -1 | grep -oE '[0-9]+%' || echo "")
            covered_msi=$(echo "$mutate_output" | grep -oE 'Covered Code MSI:[[:space:]]*[0-9]+%' | head -1 | grep -oE '[0-9]+%' || echo "")
            killed=$(echo "$mutate_output" | grep -oE '[0-9]+ mutants were killed' | head -1 | grep -oE '[0-9]+' || echo "")
            total_m=$(echo "$mutate_output" | grep -oE '[0-9]+ mutations were generated' | head -1 | grep -oE '[0-9]+' || echo "")
            not_covered=$(echo "$mutate_output" | grep -oE '[0-9]+ (mutants )?were not covered by tests' | head -1 | grep -oE '[0-9]+' || echo "")
            not_detected=$(echo "$mutate_output" | grep -oE '[0-9]+ .*mutants were not detected' | head -1 | grep -oE '[0-9]+' || echo "")

            detail_parts=()
            [[ -n "$killed" && -n "$total_m" ]] && detail_parts+=("${killed}/${total_m} killed")
            [[ -n "$covered_msi" ]] && detail_parts+=("Covered MSI ${covered_msi}")
            [[ -n "$msi" && "$msi" != "$covered_msi" ]] && detail_parts+=("MSI ${msi}")
            [[ -n "$not_covered" ]] && detail_parts+=("${not_covered} not covered")
            [[ -n "$not_detected" ]] && detail_parts+=("${not_detected} escaped")

            if [[ ${#detail_parts[@]} -gt 0 ]]; then
                detail_text=$(printf '%s; ' "${detail_parts[@]}")
                detail_text="${detail_text%; }"
                fail "Mutation testing (${detail_text})"
            else
                fail "Mutation testing"
            fi

            mutate_context=$(echo "$mutate_output" | grep -E 'MSI|mutations were generated|mutants? were killed|not covered|not detected|Escaped|Fatal|Exception|minimum|Min' | head -12)
            if [[ -n "$mutate_context" ]]; then
                echo "$mutate_context" | while read -r line; do
                    echo -e "    ${DIM}${line}${RESET}"
                done
            else
                echo "$mutate_output" | tail -20 | while read -r line; do
                    echo -e "    ${DIM}${line}${RESET}"
                done
            fi
        fi
    fi
else
    TOTAL=$((TOTAL + 1))
    printf "  ${ARROW} %-40s" "Mutation testing (Infection)"
    skip "use --mutate to enable"
fi

summary
