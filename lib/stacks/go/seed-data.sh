#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Seed Data Script
# =============================================================================
# Populates the database with sample data for development/demonstration.
#
# Usage:
#   ./lib/stacks/go/seed-data.sh           # Seed all data
#   ./lib/stacks/go/seed-data.sh --posts   # Seed posts only
#   ./lib/stacks/go/seed-data.sh --reset   # Clear and reseed all data
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
FRONTEND_PORT="${FRONTEND_PORT:-3000}"
API_PORT="${API_PORT:-8080}"
# Tables to truncate during --reset (space-separated)
RESET_TABLES="${RESET_TABLES:-articles tags showcases page_views}"
# ---- END CONFIGURATION ----

API_DIR="$PROJECT_ROOT/$APP_DIR_NAME"
SEED_DIR="$API_DIR/$SEED_SUBDIR"

DATABASE_URL="${DATABASE_URL:-postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=${DB_SSLMODE}}"

show_help() {
    echo ""
    echo -e "${BLUE}Seed Data Script${NC}"
    echo ""
    echo "Usage:"
    echo "  $0              Seed all sample data"
    echo "  $0 --articles   Seed articles only"
    echo "  $0 --reset      Clear all data and reseed"
    echo "  $0 --help       Show this help"
    echo ""
    echo "Environment:"
    echo "  DATABASE_URL    PostgreSQL connection string"
    echo ""
}

# Check if psql is available
check_psql() {
    if ! command -v psql &> /dev/null; then
        log_error "psql command not found"
        log_info "Install PostgreSQL client or use Docker:"
        echo "  docker compose exec postgres psql -U ${DB_USER} -d ${DB_NAME}"
        exit 1
    fi
}

# Check database connection
check_connection() {
    log_info "Checking database connection..."
    if ! psql "$DATABASE_URL" -c "SELECT 1" &> /dev/null; then
        log_error "Cannot connect to database"
        log_info "Make sure PostgreSQL is running:"
        echo "  docker compose up -d postgres"
        exit 1
    fi
    log_ok "Database connected"
}

# Seed tags (must run before articles)
seed_tags() {
    local seed_file="$SEED_DIR/seed_tags.sql"

    if [ ! -f "$seed_file" ]; then
        log_warn "Tags seed file not found: $seed_file (skipping)"
        return 0
    fi

    log_info "Seeding tags..."
    if psql "$DATABASE_URL" < "$seed_file"; then
        log_ok "Tags seeded successfully"
    else
        log_error "Failed to seed tags"
        exit 1
    fi
}

# Seed articles
seed_articles() {
    local seed_file="$SEED_DIR/seed_articles.sql"

    if [ ! -f "$seed_file" ]; then
        log_error "Seed file not found: $seed_file"
        exit 1
    fi

    log_info "Seeding articles..."
    if psql "$DATABASE_URL" < "$seed_file"; then
        log_ok "Articles seeded successfully"
    else
        log_error "Failed to seed articles"
        exit 1
    fi
}

# Seed article tags content
seed_article_tags_content() {
    local seed_file="$SEED_DIR/seed_article_tags_content.sql"

    if [ ! -f "$seed_file" ]; then
        log_warn "Article tags content seed file not found: $seed_file (skipping)"
        return 0
    fi

    log_info "Seeding article tags content..."
    if psql "$DATABASE_URL" < "$seed_file"; then
        log_ok "Article tags content seeded successfully"
    else
        log_error "Failed to seed article tags content"
        exit 1
    fi
}

# Seed showcases
seed_showcases() {
    local seed_file="$SEED_DIR/seed_showcases.sql"

    if [ ! -f "$seed_file" ]; then
        log_error "Seed file not found: $seed_file"
        exit 1
    fi

    log_info "Seeding showcases..."
    if psql "$DATABASE_URL" < "$seed_file"; then
        log_ok "Showcases seeded successfully"
    else
        log_error "Failed to seed showcases"
        exit 1
    fi
}

# Seed site settings
seed_site_settings() {
    local seed_file="$SEED_DIR/seed_site_settings.sql"

    if [ ! -f "$seed_file" ]; then
        log_warn "Site settings seed file not found: $seed_file (skipping)"
        return 0
    fi

    log_info "Seeding site settings..."
    if psql "$DATABASE_URL" < "$seed_file"; then
        log_ok "Site settings seeded successfully"
    else
        log_error "Failed to seed site settings"
        exit 1
    fi
}

# Seed page views (analytics data with referrers, devices, bots)
seed_page_views() {
    local seed_file="$SEED_DIR/seed_page_views.sql"

    if [ ! -f "$seed_file" ]; then
        log_warn "Page views seed file not found: $seed_file (skipping)"
        return 0
    fi

    log_info "Seeding page views..."
    if psql "$DATABASE_URL" < "$seed_file"; then
        log_ok "Page views seeded successfully"
    else
        log_error "Failed to seed page views"
        exit 1
    fi
}

# Seed all data
seed_all() {
    seed_tags                   # Tags must be seeded before articles
    seed_articles               # Articles (includes some article-tag associations)
    seed_article_tags_content   # Additional tags content
    seed_showcases
    seed_site_settings
    seed_page_views
}

# Reset database (clear and reseed)
reset_data() {
    log_warn "This will DELETE ALL existing data in the configured tables!"
    echo -n "Are you sure? [y/N] "
    read -r response

    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Aborted"
        exit 0
    fi

    log_info "Clearing data from tables..."
    for table in $RESET_TABLES; do
        if [[ ! "$table" =~ ^[a-zA-Z_][a-zA-Z0-9_.]*$ ]]; then
            log_warn "Skipping invalid table name: ${table}"
            continue
        fi
        psql "$DATABASE_URL" -c "TRUNCATE ${table} RESTART IDENTITY CASCADE;"
    done
    log_ok "Data cleared"

    seed_all
}

# Main
main() {
    echo ""
    echo -e "${BLUE}=============================================="
    echo "  ${PROJECT_NAME} - Seed Data"
    echo "==============================================${NC}"
    echo ""

    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --reset|-r)
            check_psql
            check_connection
            reset_data
            ;;
        --articles|-a)
            check_psql
            check_connection
            seed_articles
            ;;
        "")
            check_psql
            check_connection
            seed_all
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac

    echo ""
    log_ok "Seeding complete!"
    echo ""
    echo "View your data:"
    echo "  -> http://localhost:${FRONTEND_PORT}"
    echo "  -> http://localhost:${API_PORT}/api"
    echo ""
}

main "$@"
