#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Rebuild Database Script
# =============================================================================
# Drops all tables, rebuilds the schema, and seeds all data.
# Useful for development when you want a clean slate.
#
# Usage:
#   ./lib/stacks/go/rebuild-database.sh          # Interactive (prompts for confirmation)
#   ./lib/stacks/go/rebuild-database.sh --force  # Skip confirmation prompt
#   ./lib/stacks/go/rebuild-database.sh --help   # Show help
# =============================================================================

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"

# ---- CONFIGURATION ----
PROJECT_NAME="${PROJECT_NAME:-my-project}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-postgres}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-my_database}"
DB_SSLMODE="${DB_SSLMODE:-disable}"
APP_DIR_NAME="${APP_DIR_NAME:-apps/api}"
SEED_SUBDIR="${SEED_SUBDIR:-sql/seed}"
MIGRATE_COMMAND="${MIGRATE_COMMAND:-go run ./cmd/api migrate up}"
FRONTEND_PORT="${FRONTEND_PORT:-3000}"
API_PORT="${API_PORT:-8080}"
# Seed files to load, in order (space-separated basenames)
SEED_FILES="${SEED_FILES:-seed_articles.sql seed_showcases.sql}"
# Tables to drop explicitly before the catch-all (space-separated, in dependency order)
DROP_TABLES="${DROP_TABLES:-schema_migrations article_tags tags articles showcases contact_submissions}"
# ---- END CONFIGURATION ----

API_DIR="$PROJECT_ROOT/$APP_DIR_NAME"
SEED_DIR="$API_DIR/$SEED_SUBDIR"

DATABASE_URL="${DATABASE_URL:-postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=${DB_SSLMODE}}"

# Parse DATABASE_URL to extract user and database name for docker exec
# Format: postgres://user:pass@host:port/dbname?options
parse_db_url() {
    local url="$DATABASE_URL"
    # Extract user (between :// and :)
    PARSED_DB_USER=$(echo "$url" | sed -n 's|.*://\([^:]*\):.*|\1|p')
    # Extract database name (between last / and ? or end)
    PARSED_DB_NAME=$(echo "$url" | sed -n 's|.*/\([^?]*\).*|\1|p')

    # Defaults if parsing fails
    PARSED_DB_USER="${PARSED_DB_USER:-$DB_USER}"
    PARSED_DB_NAME="${PARSED_DB_NAME:-$DB_NAME}"
}

# Run psql via docker compose
docker_psql() {
    docker compose exec -T postgres psql -U "$PARSED_DB_USER" -d "$PARSED_DB_NAME" "$@"
}

show_help() {
    echo ""
    echo -e "${BLUE}Rebuild Database Script${NC}"
    echo ""
    echo "Usage:"
    echo "  $0              Interactive mode (prompts for confirmation)"
    echo "  $0 --force      Skip confirmation and rebuild immediately"
    echo "  $0 --help       Show this help"
    echo ""
    echo "This script will:"
    echo "  1. Drop all existing tables"
    echo "  2. Run all migrations to rebuild schema"
    echo "  3. Seed all sample data"
    echo ""
    echo "Environment:"
    echo "  DATABASE_URL    PostgreSQL connection string"
    echo ""
}

# Check if docker is available and postgres container is running
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker not found"
        log_info "Please install Docker to use this script"
        exit 1
    fi

    if ! docker compose ps postgres 2>/dev/null | grep -q "Up"; then
        log_error "PostgreSQL container is not running"
        log_info "Start it with:"
        echo "  docker compose up -d postgres"
        exit 1
    fi
}

# Check database connection
check_connection() {
    log_info "Checking database connection..."
    parse_db_url
    if ! docker_psql -c "SELECT 1" &> /dev/null; then
        log_error "Cannot connect to database"
        log_info "Make sure PostgreSQL container is healthy:"
        echo "  docker compose ps postgres"
        exit 1
    fi
    log_ok "Database connected (user: $PARSED_DB_USER, db: $PARSED_DB_NAME)"
}

# Drop all tables
drop_tables() {
    log_info "Dropping all tables..."

    # Build DROP TABLE statements from the configured list
    local drop_stmts=""
    for table in $DROP_TABLES; do
        drop_stmts="${drop_stmts}DROP TABLE IF EXISTS ${table} CASCADE;"$'\n'
    done

    # Drop tables in reverse dependency order, then catch any remaining
    docker_psql <<EOF
${drop_stmts}
-- Drop any other tables that might exist
DO \$\$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
        EXECUTE 'DROP TABLE IF EXISTS ' || quote_ident(r.tablename) || ' CASCADE';
    END LOOP;
END \$\$;
EOF

    log_ok "All tables dropped"
}

# Run migrations
run_migrations() {
    log_info "Running migrations..."

    cd "$API_DIR"

    if ! $MIGRATE_COMMAND; then
        log_error "Migration failed"
        exit 1
    fi

    log_ok "Migrations complete"
}

# Seed all data
seed_data() {
    log_info "Seeding database..."

    # Find and run all seed files in order
    local seed_files_arr=()

    for seed_basename in $SEED_FILES; do
        if [ -f "$SEED_DIR/$seed_basename" ]; then
            seed_files_arr+=("$SEED_DIR/$seed_basename")
        fi
    done

    # Run each seed file
    for seed_file in "${seed_files_arr[@]}"; do
        local filename=$(basename "$seed_file")
        log_info "  Seeding: $filename"

        if docker_psql < "$seed_file"; then
            log_ok "  $filename seeded"
        else
            log_error "  Failed to seed $filename"
            exit 1
        fi
    done

    log_ok "All seed data loaded"
}

# Main rebuild function
rebuild() {
    drop_tables
    run_migrations
    seed_data
}

# Main
main() {
    echo ""
    echo -e "${BLUE}=============================================="
    echo "  ${PROJECT_NAME} - Rebuild Database"
    echo "==============================================${NC}"
    echo ""

    local force=false

    # Parse arguments
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --force|-f)
            force=true
            ;;
        "")
            # Interactive mode
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac

    check_docker
    check_connection

    # Confirm unless --force is used
    if [ "$force" = false ]; then
        echo -e "${YELLOW}WARNING: This will DELETE ALL DATA in the database!${NC}"
        echo ""
        echo "This includes all application tables and data."
        echo ""
        echo -n "Are you sure you want to continue? [y/N] "
        read -r response

        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Aborted"
            exit 0
        fi
        echo ""
    fi

    rebuild

    echo ""
    log_ok "Database rebuild complete!"
    echo ""
    echo "Your fresh database is ready with:"
    echo "  - Schema: All migrations applied"
    echo "  - Data:   All seed files loaded"
    echo ""
    echo "View your data:"
    echo "  -> http://localhost:${FRONTEND_PORT}"
    echo "  -> http://localhost:${API_PORT}/api"
    echo ""
}

main "$@"
