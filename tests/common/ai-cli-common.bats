#!/usr/bin/env bats
# Unit tests for lib/ai-cli/_common.sh

setup() {
    load ../test_helper
    SCRIPT_DIR="$REPO_ROOT/lib/ai-cli"
    source "$SCRIPT_DIR/_common.sh"
}

# ── Color variables ─────────────────────────────────────────────

@test "color variables are defined" {
    [[ -n "$RED" ]]
    [[ -n "$GREEN" ]]
    [[ -n "$YELLOW" ]]
    [[ -n "$CYAN" ]]
    [[ -n "$NC" ]]
}

# ── Platform detection ──────────────────────────────────────────

@test "detect_platform sets GOAT_OS" {
    detect_platform
    [[ -n "$GOAT_OS" ]]
    # Must be one of the known values
    [[ "$GOAT_OS" =~ ^(macOS|Linux|Windows|Unknown)$ ]]
}

@test "detect_platform sets GOAT_IS_WSL" {
    detect_platform
    [[ "$GOAT_IS_WSL" =~ ^(true|false)$ ]]
}

@test "detect_platform sets GOAT_IS_GITBASH" {
    detect_platform
    [[ "$GOAT_IS_GITBASH" =~ ^(true|false)$ ]]
}

@test "detect_platform exports all variables" {
    detect_platform
    # Check they are exported
    run bash -c 'source "'"$SCRIPT_DIR/_common.sh"'" && echo "$GOAT_OS"'
    [[ -n "$output" ]]
}

# ── command_exists ──────────────────────────────────────────────

@test "command_exists returns 0 for bash" {
    command_exists bash
}

@test "command_exists returns 1 for nonexistent command" {
    ! command_exists this_command_definitely_does_not_exist_xyz
}

# ── sanitize_path_for_wsl ──────────────────────────────────────

@test "sanitize_path_for_wsl is a no-op on non-WSL" {
    GOAT_IS_WSL="false"
    local original_path="$PATH"
    sanitize_path_for_wsl
    [[ "$PATH" == "$original_path" ]]
}

@test "sanitize_path_for_wsl removes /mnt/ entries on WSL" {
    GOAT_IS_WSL="true"
    PATH="/usr/bin:/mnt/c/Windows:/usr/local/bin:/mnt/c/Program Files"
    sanitize_path_for_wsl
    [[ "$PATH" == "/usr/bin:/usr/local/bin" ]]
}

# ── block_gitbash ───────────────────────────────────────────────

@test "block_gitbash exits 1 when GOAT_IS_GITBASH is true" {
    GOAT_IS_GITBASH="true"
    run block_gitbash "TestTool"
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"not supported in Git Bash"* ]]
}

@test "block_gitbash does nothing when GOAT_IS_GITBASH is false" {
    GOAT_IS_GITBASH="false"
    run block_gitbash "TestTool"
    [[ "$status" -eq 0 ]]
}

# ── confirm_or_auto ─────────────────────────────────────────────

@test "confirm_or_auto auto-proceeds in non-interactive mode" {
    # Pipe input makes stdin non-interactive
    run bash -c 'source "'"$SCRIPT_DIR/_common.sh"'" && confirm_or_auto "Test?"'
    [[ "$status" -eq 0 ]]
}

# ── print_platform ──────────────────────────────────────────────

@test "print_platform outputs detected platform" {
    detect_platform
    run print_platform
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Detected platform"* ]]
}
