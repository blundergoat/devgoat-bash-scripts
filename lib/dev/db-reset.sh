#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Database Reset - Drop, recreate, migrate, and seed a development database
# =============================================================================
# Usage:
#   ./scripts/db-reset.sh               # Interactive (prompts for confirmation)
#   ./scripts/db-reset.sh --force       # Skip confirmation
#   ./scripts/db-reset.sh --help        # Show help
#
# Supports PostgreSQL and MySQL, running locally or in Docker.
# =============================================================================

# ---- CONFIGURATION ----
# Customize these variables for your project, or set them as environment variables.
PROJECT_NAME="${PROJECT_NAME:-my-project}"
DB_ENGINE="${DB_ENGINE:-postgres}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-postgres}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-my_database}"
# Docker service name for the database (empty = use local client)
DOCKER_SERVICE="${DOCKER_SERVICE:-}"
# Migration command to run after creating the database
MIGRATION_CMD="${MIGRATION_CMD:-}"
# Seed command to run after migrations
SEED_CMD="${SEED_CMD:-}"
# ---- END CONFIGURATION ----

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

show_help() {
    echo ""
    echo -e "${BOLD}Database Reset${NC}"
    echo ""
    echo "Usage:"
    echo "  $0                  Interactive mode (prompts for confirmation)"
    echo "  $0 --force          Skip confirmation and reset immediately"
    echo "  $0 --help           Show this help"
    echo ""
    echo "This script will:"
    echo "  1. Drop the database (if it exists)"
    echo "  2. Create a fresh database"
    echo "  3. Run migrations (if MIGRATION_CMD is configured)"
    echo "  4. Run seed command (if SEED_CMD is configured)"
    echo ""
    echo "Configuration:"
    echo "  DB_ENGINE          postgres or mysql (default: postgres)"
    echo "  DOCKER_SERVICE     Docker Compose service name (empty = local client)"
    echo ""
}

FORCE=false

# Parse arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    --force|-f)
        FORCE=true
        ;;
    "")
        ;;
    *)
        echo -e "${RED}Unknown option: $1${NC}"
        show_help
        exit 1
        ;;
esac

# ── Helpers ─────────────────────────────────────────────────────────
log()     { echo -e "${BLUE}[db-reset]${NC} $*"; }
success() { echo -e "${GREEN}[db-reset]${NC} $*"; }
warn()    { echo -e "${YELLOW}[db-reset]${NC} $*"; }
error()   { echo -e "${RED}[db-reset]${NC} $*"; exit 1; }

# Run a SQL command against the database server
run_sql() {
    local sql="$1"
    local target_db="${2:-}"

    if [[ "$DB_ENGINE" == "postgres" ]]; then
        local pg_args=()
        if [[ -n "$target_db" ]]; then
            pg_args+=("-d" "$target_db")
        fi
        if [[ -n "$DOCKER_SERVICE" ]]; then
            docker compose exec -T "$DOCKER_SERVICE" psql -U "$DB_USER" "${pg_args[@]}" -c "$sql"
        else
            PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "${pg_args[@]}" -c "$sql"
        fi
    elif [[ "$DB_ENGINE" == "mysql" ]]; then
        local my_args=(-u "$DB_USER" -p"$DB_PASSWORD" -e "$sql")
        if [[ -n "$target_db" ]]; then
            my_args+=("$target_db")
        fi
        if [[ -n "$DOCKER_SERVICE" ]]; then
            docker compose exec -T "$DOCKER_SERVICE" mysql "${my_args[@]}"
        else
            mysql -h "$DB_HOST" -P "$DB_PORT" "${my_args[@]}"
        fi
    fi
}

# ── Prerequisite checks ────────────────────────────────────────────
log "Engine: ${BOLD}${DB_ENGINE}${NC}"
log "Database: ${BOLD}${DB_NAME}${NC}"
log "Host: ${BOLD}${DB_HOST}:${DB_PORT}${NC}"
if [[ -n "$DOCKER_SERVICE" ]]; then
    log "Docker service: ${BOLD}${DOCKER_SERVICE}${NC}"
fi
echo ""

# Check client availability
if [[ -n "$DOCKER_SERVICE" ]]; then
    if ! command -v docker &>/dev/null; then
        error "Docker not found"
    fi
    if ! docker compose ps "$DOCKER_SERVICE" 2>/dev/null | grep -q "Up"; then
        error "${DOCKER_SERVICE} container is not running. Start it with: docker compose up -d ${DOCKER_SERVICE}"
    fi
else
    case "$DB_ENGINE" in
        postgres)
            if ! command -v psql &>/dev/null; then
                error "psql not found. Install postgresql-client."
            fi
            ;;
        mysql)
            if ! command -v mysql &>/dev/null; then
                error "mysql client not found. Install mysql-client."
            fi
            ;;
        *)
            error "Unsupported DB_ENGINE: $DB_ENGINE (use postgres or mysql)"
            ;;
    esac
fi

# Test connection
log "Testing connection..."
case "$DB_ENGINE" in
    postgres)
        if ! run_sql "SELECT 1" postgres &>/dev/null; then
            error "Cannot connect to PostgreSQL"
        fi
        ;;
    mysql)
        if ! run_sql "SELECT 1" &>/dev/null; then
            error "Cannot connect to MySQL"
        fi
        ;;
esac
success "Connection OK"
echo ""

# ── Confirmation ────────────────────────────────────────────────────
if [[ "$FORCE" != true ]]; then
    echo -e "${YELLOW}WARNING: This will DROP the '${DB_NAME}' database and ALL its data!${NC}"
    echo ""
    read -r -p "Are you sure? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log "Aborted"
        exit 0
    fi
    echo ""
fi

# ── Drop database ──────────────────────────────────────────────────
log "Dropping database ${DB_NAME}..."
case "$DB_ENGINE" in
    postgres)
        # Terminate active connections first
        run_sql "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DB_NAME}' AND pid <> pg_backend_pid();" postgres &>/dev/null || true
        run_sql "DROP DATABASE IF EXISTS \"${DB_NAME}\";" postgres &>/dev/null
        ;;
    mysql)
        run_sql "DROP DATABASE IF EXISTS \`${DB_NAME}\`;" &>/dev/null
        ;;
esac
success "Database dropped"

# ── Create database ────────────────────────────────────────────────
log "Creating database ${DB_NAME}..."
case "$DB_ENGINE" in
    postgres)
        run_sql "CREATE DATABASE \"${DB_NAME}\";" postgres &>/dev/null
        ;;
    mysql)
        run_sql "CREATE DATABASE \`${DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" &>/dev/null
        ;;
esac
success "Database created"

# ── Migrations ─────────────────────────────────────────────────────
if [[ -n "$MIGRATION_CMD" ]]; then
    log "Running migrations..."
    cd "$PROJECT_ROOT" || exit 1
    if eval "$MIGRATION_CMD"; then
        success "Migrations complete"
    else
        error "Migration failed"
    fi
else
    log "${DIM}No MIGRATION_CMD configured — skipping migrations${NC}"
fi

# ── Seed ───────────────────────────────────────────────────────────
if [[ -n "$SEED_CMD" ]]; then
    log "Seeding database..."
    cd "$PROJECT_ROOT" || exit 1
    if eval "$SEED_CMD"; then
        success "Seed complete"
    else
        error "Seed failed"
    fi
else
    log "${DIM}No SEED_CMD configured — skipping seed${NC}"
fi

# ── Summary ────────────────────────────────────────────────────────
echo ""
success "Database reset complete!"
echo ""
