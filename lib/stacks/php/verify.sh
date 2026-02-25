#!/usr/bin/env bash
# =============================================================================
# PHP Verify Setup - Checks that PHP dependencies and config are installed
# =============================================================================
# Usage: ./lib/stacks/php/verify.sh
#
# Run after setup.sh (or any time) to confirm the PHP development environment
# is complete and ready. Checks system tools, Composer packages, and PHP
# dev tooling (PHPUnit, PHPStan, PHP-CS-Fixer, PHPMD).
# =============================================================================

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"

# ---- CONFIGURATION ----
PROJECT_NAME="${PROJECT_NAME:-my-project}"
# Env vars to verify exist in .env (space-separated)
REQUIRED_ENV_VARS="${REQUIRED_ENV_VARS:-APP_SECRET}"
# PHPStan config file
PHPSTAN_CONFIG="${PHPSTAN_CONFIG:-$PROJECT_ROOT/phpstan.neon}"
# PHPUnit config file
PHPUNIT_CONFIG="${PHPUNIT_CONFIG:-$PROJECT_ROOT/phpunit.xml.dist}"
# PHP CS Fixer config file
CS_FIXER_CONFIG="${CS_FIXER_CONFIG:-$PROJECT_ROOT/.php-cs-fixer.php}"
# ---- END CONFIGURATION ----

REPO_ROOT="$PROJECT_ROOT"

# ═════════════════════════════════════════════════════════════════════
header "${PROJECT_NAME} - PHP Verification"

# ── System Tools ────────────────────────────────────────────────────
section "System tools"

step "PHP 8.2+"
if command -v php &>/dev/null; then
    php_version=$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION . "." . PHP_RELEASE_VERSION;')
    php_major=$(php -r 'echo PHP_MAJOR_VERSION;')
    php_minor=$(php -r 'echo PHP_MINOR_VERSION;')
    if [[ "$php_major" -gt 8 ]] || { [[ "$php_major" -eq 8 ]] && [[ "$php_minor" -ge 2 ]]; }; then
        pass "v${php_version}"
    else
        fail "v${php_version} - need 8.2+"
    fi
else
    fail "not found"
fi

step "Composer"
if command -v composer &>/dev/null; then
    composer_version=$(composer --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    pass "v${composer_version}"
else
    fail "not found"
fi

step "Docker"
if command -v docker &>/dev/null; then
    docker_version=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    pass "v${docker_version}"
else
    warn "not found - needed for docker compose up"
fi

step "Docker Compose"
if docker compose version &>/dev/null 2>&1; then
    compose_version=$(docker compose version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    pass "v${compose_version}"
else
    warn "not found - needed for docker compose up"
fi

# ── Project Files ───────────────────────────────────────────────────
section "Project files"

step ".env"
if [[ -f "$REPO_ROOT/.env" ]]; then
    pass
else
    fail "missing - run: cp .env.example .env"
fi

for env_var in $REQUIRED_ENV_VARS; do
    step ".env has ${env_var}"
    if [[ -f "$REPO_ROOT/.env" ]] && grep -q "^${env_var}=" "$REPO_ROOT/.env"; then
        pass
    else
        fail "${env_var} not set in .env"
    fi
done

step "docker-compose.yml"
if [[ -f "$REPO_ROOT/docker-compose.yml" ]]; then
    pass
else
    fail "missing"
fi

# ── PHP Dependencies ───────────────────────────────────────────────
section "PHP dependencies (Composer)"

step "vendor/ directory"
if [[ -d "$REPO_ROOT/vendor" ]]; then
    pass
else
    fail "missing - run: composer install"
fi

step "vendor/autoload.php"
if [[ -f "$REPO_ROOT/vendor/autoload.php" ]]; then
    pass
else
    fail "missing - run: composer install"
fi

step "composer.json valid"
if cd "$REPO_ROOT" && composer validate 2>&1 | grep -q "is valid"; then
    pass
else
    fail "composer.json invalid - run: composer validate"
fi

step "phpunit"
if [[ -x "$REPO_ROOT/vendor/bin/phpunit" ]]; then
    phpunit_version=$("$REPO_ROOT/vendor/bin/phpunit" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
    pass "v${phpunit_version}"
else
    fail "not installed"
fi

step "phpstan"
if [[ -x "$REPO_ROOT/vendor/bin/phpstan" ]]; then
    phpstan_version=$("$REPO_ROOT/vendor/bin/phpstan" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
    pass "v${phpstan_version}"
else
    fail "not installed"
fi

step "php-cs-fixer"
if [[ -x "$REPO_ROOT/vendor/bin/php-cs-fixer" ]]; then
    csfixer_version=$("$REPO_ROOT/vendor/bin/php-cs-fixer" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
    pass "v${csfixer_version}"
else
    fail "not installed"
fi

step "phpmd"
if [[ -x "$REPO_ROOT/vendor/bin/phpmd" ]]; then
    pass
else
    fail "not installed"
fi

# ── Smoke Tests ──────────────────────────────────────────────────
section "Smoke tests"

step "PHPUnit runs"
if [[ -x "$REPO_ROOT/vendor/bin/phpunit" ]]; then
    test_output=$("$REPO_ROOT/vendor/bin/phpunit" --configuration "$PHPUNIT_CONFIG" 2>&1)
    test_exit=$?
    if [[ $test_exit -eq 0 ]]; then
        test_summary=$(echo "$test_output" | grep -oE '[0-9]+ tests, [0-9]+ assertions' || echo "ok")
        pass "$test_summary"
    else
        fail "tests failing"
    fi
else
    fail "phpunit not available"
fi

step "PHPStan clean"
if [[ -x "$REPO_ROOT/vendor/bin/phpstan" ]]; then
    stan_output=$("$REPO_ROOT/vendor/bin/phpstan" analyse --no-progress --configuration "$PHPSTAN_CONFIG" 2>&1)
    stan_exit=$?
    if [[ $stan_exit -eq 0 ]]; then
        pass
    else
        err_count=$(echo "$stan_output" | grep -cE "^/" || echo "?")
        fail "${err_count} error(s)"
    fi
else
    fail "phpstan not available"
fi

step "Code style clean"
if [[ -x "$REPO_ROOT/vendor/bin/php-cs-fixer" ]]; then
    cs_output=$("$REPO_ROOT/vendor/bin/php-cs-fixer" fix --dry-run --diff --config="$CS_FIXER_CONFIG" 2>&1)
    cs_exit=$?
    if [[ $cs_exit -eq 0 ]]; then
        pass
    else
        fix_count=$(echo "$cs_output" | grep -c "^   [0-9]*)" || echo "?")
        fail "${fix_count} file(s) need fixing"
    fi
else
    fail "php-cs-fixer not available"
fi

# ── Summary ────────────────────────────────────────────────────────
echo ""
divider
echo ""

if [[ $FAILED -eq 0 ]]; then
    msg="${PASSED}/${TOTAL} checks passed"
    if [[ $WARNINGS -gt 0 ]]; then
        msg="${msg}, ${WARNINGS} warning(s)"
    fi
    echo -e "  ${GREEN}${BOLD}${msg}${RESET}"
    echo ""
else
    echo -e "  ${RED}${BOLD}${FAILED}/${TOTAL} checks failed${RESET}"
    echo ""
    for f in "${FAILURES[@]}"; do
        echo -e "    ${FAIL}  ${f}"
    done
    echo ""
    echo -e "  ${DIM}Run lib/stacks/php/setup.sh to fix most issues${RESET}"
    echo ""
    exit 1
fi
