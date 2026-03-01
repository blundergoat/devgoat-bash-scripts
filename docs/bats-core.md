# Bats Test Suite

Automated tests for devgoat-bash-scripts using [bats-core](https://github.com/bats-core/bats-core) (Bash Automated Testing System).

## Quick Start

```bash
# Install bats (pick one)
./lib/tools/install-bats-core.sh
sudo apt install bats           # Debian/Ubuntu package for bats-core
brew install bats-core          # macOS
npm install -g bats             # fallback

# Run all tests
bats tests/ --recursive

# Run a specific test file
bats tests/conventions/shellcheck.bats

# Run a specific test directory
bats tests/common/
```

## Test Structure

```
tests/
├── test_helper.bash              # Shared setup: REPO_ROOT, discover_scripts(), exception lists
├── common/                       # Unit tests for _common.sh libraries
│   ├── ai-cli-common.bats       # lib/ai-cli/_common.sh functions
│   └── stacks-common.bats       # lib/stacks/_common.sh functions
├── conventions/                  # Repo-wide convention checks (mirrors preflight-checks.sh)
│   ├── shebang.bats             # #!/usr/bin/env bash on all scripts
│   ├── strict-mode.bats         # set -euo pipefail (or -uo for exceptions)
│   ├── executable-bit.bats      # chmod +x on all .sh files
│   ├── syntax.bats              # bash -n syntax check
│   ├── shellcheck.bats          # shellcheck -S warning
│   ├── help-flag.bats           # --help exits 0 and prints usage text
│   └── template-config.bats     # CONFIGURATION blocks are matched and use ${VAR:-default}
└── scripts/                      # Script-specific functional tests
    ├── codegen.bats              # generate-code-map.sh
    ├── maintenance.bats          # make-scripts-executable.sh, remove-zone-identifier.sh, lint-all.sh
    └── preflight.bats            # scripts/preflight-checks.sh
```

### test_helper.bash

Loaded by every test file via `load ../test_helper`. Provides:

- **`REPO_ROOT`** — Absolute path to the repository root.
- **`discover_scripts`** — Finds all `.sh` files under `lib/`. Used by convention tests to iterate over every script.
- **`STRICT_EXCEPTIONS`** — Scripts that intentionally use `set -uo pipefail` (no `-e`). Mirrors the list in `scripts/preflight-checks.sh` and `docs/footguns.md`.
- **`LIBRARY_FILES`** — Shared libraries (`_common.sh`) that don't need their own strict mode line.
- **`is_strict_exception`** / **`is_library_file`** — Lookup helpers.

### Convention tests vs. preflight-checks.sh

The `tests/conventions/` tests cover the same ground as `scripts/preflight-checks.sh`. The difference:

| | `preflight-checks.sh` | `tests/conventions/` |
|---|---|---|
| Runner | Standalone script | bats |
| Use case | Pre-commit gate, CI | Development, CI |
| Output | Colored summary | TAP format |
| Secrets check | Yes | No (git-dependent) |

Both should stay in sync. When adding a new exception to one, update the other.

### Common tests

Unit tests for the two `_common.sh` shared libraries. These source the library directly and test individual functions in isolation.

**ai-cli-common.bats** tests:
- Color variable definitions
- `detect_platform()` — sets `GOAT_OS`, `GOAT_IS_WSL`, `GOAT_IS_GITBASH`
- `command_exists()` — finds real commands, rejects missing ones
- `sanitize_path_for_wsl()` — strips `/mnt/*` entries on WSL, no-op elsewhere
- `block_gitbash()` — exits 1 when Git Bash detected
- `confirm_or_auto()` — auto-proceeds in non-interactive mode
- `print_platform()` — outputs platform info

**stacks-common.bats** tests:
- Color and symbol variable definitions
- Counter initialization (`TOTAL`, `PASSED`, `FAILED`, etc.)
- `step()`, `pass()`, `fail()`, `skip()`, `warn()` helpers
- `elapsed_since()` timing
- `header()`, `section()`, `divider()` formatting
- `log_info()`, `log_ok()`, `log_warn()`, `log_error()` helpers
- Double-source guard (`_STACKS_COMMON_LOADED`)
- `.env` auto-loading

### Script tests

Functional tests for scripts that are safe to run in a test environment. These call the actual script with `--help`, `--dry-run`, or other safe flags and check exit codes and output.

## Writing New Tests

### Adding a convention test

Convention tests iterate over all scripts via `discover_scripts` and check a single property. Follow the existing pattern:

```bash
#!/usr/bin/env bats

setup() {
    load ../test_helper
}

@test "all scripts have some property" {
    local failures=()
    while IFS= read -r file; do
        rel="${file#"$REPO_ROOT/"}"
        # ... check the property ...
        if [[ some_condition_failed ]]; then
            failures+=("$rel")
        fi
    done < <(discover_scripts)

    if [[ ${#failures[@]} -gt 0 ]]; then
        printf 'Description of failure:\n'
        printf '  %s\n' "${failures[@]}"
        return 1
    fi
}
```

### Adding a _common.sh unit test

Source the library in `setup()` and test one function per `@test` block:

```bash
setup() {
    load ../test_helper
    source "$REPO_ROOT/lib/stacks/_common.sh"
}

@test "my_function does the right thing" {
    run my_function "arg"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"expected"* ]]
}
```

### Adding a script test

Only test scripts that have safe execution paths (`--help`, `--dry-run`, flag validation):

```bash
@test "my-script.sh --help exits 0" {
    run bash "$REPO_ROOT/lib/domain/my-script.sh" --help
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Usage"* ]]
}
```

Do **not** run scripts that modify system state (install packages, delete files, call AWS APIs) without proper isolation.

## Keeping Tests in Sync

When you add or modify scripts, check:

1. **New exception script** (omits `-e`) — Add to `STRICT_EXCEPTIONS` in `test_helper.bash`, `scripts/preflight-checks.sh`, and `docs/footguns.md`.
2. **New `_common.sh` library** — Add to `LIBRARY_FILES` in `test_helper.bash` and `scripts/preflight-checks.sh`.
3. **New script with `show_help()`** — Already covered by `help-flag.bats` automatically.
4. **New template script** — Already covered by `template-config.bats` automatically.
