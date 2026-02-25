# /preflight — Preflight Checks for Shell Scripts

Run validation checks on all modified shell scripts before declaring work complete.

## Instructions

1. **Find all modified `.sh` files** in the current working tree:
   ```bash
   git diff --name-only HEAD 2>/dev/null
   git diff --name-only --cached 2>/dev/null
   git ls-files --others --exclude-standard '*.sh' 2>/dev/null
   ```
   Combine and deduplicate the results. Only process `.sh` files.

2. **Run `bash -n` on each modified script** to catch syntax errors. Report any failures.

3. **Run `shellcheck` on each modified script.** Report warnings and errors. Fix all errors before declaring complete.

4. **Verify each script has the correct shebang and strict mode:**
   - `#!/usr/bin/env bash` on line 1
   - `set -euo pipefail` near the top
   - Exception: scripts that intentionally omit `-e` (e.g., `verify.sh`, `gpu-check.sh`) — note these as acceptable

5. **Verify each user-facing script has `-h`/`--help` support** via a `show_help()` function.

6. **Report results** in this format:
   ```
   ## Preflight Results

   | Script | bash -n | shellcheck | shebang | strict mode | help flag |
   |--------|---------|------------|---------|-------------|-----------|
   | path   | ✅/❌   | ✅/❌ (N)  | ✅/❌   | ✅/❌       | ✅/❌/N/A |
   ```

7. **If any checks fail**, fix the issues and re-run the failing checks. Do not declare complete until all checks pass.
