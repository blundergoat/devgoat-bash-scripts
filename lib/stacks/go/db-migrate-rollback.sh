#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Database Migration Rollback Script
# =============================================================================
# Safe migration rollback with confirmation and optional backup.
#
# Usage:
#   ./lib/stacks/go/db-migrate-rollback.sh           # Rollback last migration
#   ./lib/stacks/go/db-migrate-rollback.sh -n 2      # Rollback last 2 migrations
#   ./lib/stacks/go/db-migrate-rollback.sh --backup  # Create backup before rollback
#   ./lib/stacks/go/db-migrate-rollback.sh --dry-run # Show what would be rolled back
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
MIGRATIONS_SUBDIR="${MIGRATIONS_SUBDIR:-sql/schema}"
# ---- END CONFIGURATION ----

API_DIR="$PROJECT_ROOT/$APP_DIR_NAME"
MIGRATIONS_DIR="$API_DIR/$MIGRATIONS_SUBDIR"
BACKUP_DIR="$PROJECT_ROOT/backups"

DATABASE_URL="${DATABASE_URL:-postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=${DB_SSLMODE}}"

# Default options
ROLLBACK_COUNT=1
CREATE_BACKUP=false
DRY_RUN=false
FORCE=false

show_help() {
    echo ""
    echo -e "${BLUE}Database Migration Rollback Script${NC}"
    echo ""
    echo "Usage:"
    echo "  $0 [options]"
    echo ""
    echo "Options:"
    echo "  -n, --count NUM    Number of migrations to rollback (default: 1)"
    echo "  -b, --backup       Create a database backup before rollback"
    echo "  -d, --dry-run      Show what would be rolled back without executing"
    echo "  -f, --force        Skip confirmation prompt"
    echo "  -h, --help         Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                 # Rollback the last migration"
    echo "  $0 -n 2            # Rollback the last 2 migrations"
    echo "  $0 --backup        # Create backup before rollback"
    echo "  $0 --dry-run       # Preview rollback without executing"
    echo ""
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--count)
            ROLLBACK_COUNT="$2"
            shift 2
            ;;
        -b|--backup)
            CREATE_BACKUP=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check for migrate tool
check_migrate() {
    local migrate_path
    migrate_path="$(go env GOPATH)/bin/migrate"

    if [ ! -x "$migrate_path" ]; then
        log_error "migrate tool not found at $migrate_path"
        log_info "Install with: go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest"
        exit 1
    fi

    echo "$migrate_path"
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

# Get current migration version
get_current_version() {
    local migrate_path="$1"
    "$migrate_path" -path "$MIGRATIONS_DIR" -database "$DATABASE_URL" version 2>&1 || echo "0"
}

# Get migration file name by version
get_migration_name() {
    local version="$1"
    local padded_version
    padded_version=$(printf "%04d" "$version")

    local migration_file
    migration_file=$(ls "$MIGRATIONS_DIR"/${padded_version}_*.up.sql 2>/dev/null | head -1)

    if [ -n "$migration_file" ]; then
        basename "$migration_file" | sed 's/\.up\.sql$//' | sed 's/^[0-9]*_//'
    else
        echo "unknown"
    fi
}

# Create database backup
create_backup() {
    mkdir -p "$BACKUP_DIR"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/pre_rollback_${timestamp}.sql"

    log_info "Creating backup to $backup_file..."
    if pg_dump "$DATABASE_URL" > "$backup_file" 2>/dev/null; then
        log_ok "Backup created: $backup_file"
    else
        log_error "Failed to create backup"
        exit 1
    fi
}

# Main
main() {
    echo ""
    echo -e "${BLUE}=============================================="
    echo "  ${PROJECT_NAME} - Migration Rollback"
    echo "==============================================${NC}"
    echo ""

    local migrate_path
    migrate_path=$(check_migrate)
    check_connection

    # Get current version
    local current_version
    current_version=$(get_current_version "$migrate_path")

    if [ "$current_version" = "0" ] || [ "$current_version" = "no migration" ]; then
        log_warn "No migrations have been applied"
        exit 0
    fi

    log_info "Current migration version: ${CYAN}$current_version${NC}"

    # Calculate target version
    local target_version=$((current_version - ROLLBACK_COUNT))
    if [ "$target_version" -lt 0 ]; then
        target_version=0
    fi

    # Show what will be rolled back
    echo ""
    log_info "Migrations to rollback:"
    for ((v=current_version; v>target_version; v--)); do
        local name
        name=$(get_migration_name "$v")
        echo -e "  ${RED}↓${NC} $v: $name"
    done
    echo ""
    log_info "Target version: ${CYAN}$target_version${NC}"

    if [ "$DRY_RUN" = true ]; then
        echo ""
        log_warn "DRY RUN - No changes made"
        exit 0
    fi

    # Confirm rollback
    if [ "$FORCE" = false ]; then
        echo ""
        log_warn "This will rollback $ROLLBACK_COUNT migration(s)"
        echo -n "Are you sure? [y/N] "
        read -r response

        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Rollback cancelled"
            exit 0
        fi
    fi

    # Create backup if requested
    if [ "$CREATE_BACKUP" = true ]; then
        create_backup
    fi

    # Perform rollback
    echo ""
    log_info "Rolling back $ROLLBACK_COUNT migration(s)..."

    if "$migrate_path" -path "$MIGRATIONS_DIR" -database "$DATABASE_URL" down "$ROLLBACK_COUNT"; then
        echo ""
        log_ok "Rollback completed successfully!"

        # Show new version
        local new_version
        new_version=$(get_current_version "$migrate_path")
        log_info "New migration version: ${CYAN}$new_version${NC}"
    else
        log_error "Rollback failed!"
        if [ "$CREATE_BACKUP" = true ]; then
            log_info "Restore from backup if needed:"
            echo "  psql \"\$DATABASE_URL\" < $BACKUP_DIR/pre_rollback_*.sql"
        fi
        exit 1
    fi

    echo ""
}

main "$@"
