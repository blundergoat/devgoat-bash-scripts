# /preflight — Preflight Checks for Shell Scripts

Run validation checks on all modified shell scripts before declaring work complete.

## Instructions

### MUST (cannot skip)

1. **Find all modified `.sh` files** in the current working tree:
   ```bash
   git diff --name-only HEAD 2>/dev/null
   git diff --name-only --cached 2>/dev/null
   git ls-files --others --exclude-standard '*.sh' 2>/dev/null
   ```
   Combine and deduplicate. Only process `.sh` files.

2. **Run `bash -n`** on each modified script. Report any failures.

3. **Run `shellcheck -x`** on each modified script. Fix all errors before declaring complete.

4. **Verify shebang and strict mode:**
   - `#!/usr/bin/env bash` on line 1
   - `set -euo pipefail` near the top
   - Exception: scripts listed in `docs/footguns.md` strict mode exceptions — note as acceptable

5. **Verify `-h`/`--help`** via `show_help()` on user-facing scripts.

### SHOULD (skip only with reason)

6. **Run `bats tests/ --recursive`** — full test suite.

7. **Check executable bit** — all `.sh` files should be `chmod +x`.

8. **Check logging paradigm** matches sibling scripts in the same directory.

### MAY (skip during debugging)

9. **Dependency audit** — check for outdated or insecure dependencies in scripts that install tools.

## Output Format

```
## Preflight Results

| Script | bash -n | shellcheck | shebang | strict mode | help flag |
|--------|---------|------------|---------|-------------|-----------|
| path   | ✅/❌   | ✅/❌ (N)  | ✅/❌   | ✅/❌       | ✅/❌/N/A |

Bats: ✅/❌ (N tests)
```

If any MUST checks fail, fix the issues and re-run. Do not declare complete until all MUST items pass.
