# Footguns

Cross-domain gotchas discovered in this codebase. When you cause a bug that spans multiple domains, append it here using the format below.

---

## Footgun: Strict mode exceptions

**Symptoms:** Script exits immediately on a non-zero return code that was expected to be handled. Or: adding `set -e` to a script that previously worked causes it to abort mid-run.

**Why it happens:** Seven scripts intentionally omit `-e` from their strict mode line (`set -uo pipefail` instead of `set -euo pipefail`) because they must continue past individual check failures to report a full summary:

| Script | Reason |
|--------|--------|
| `lib/stacks/php/verify.sh` | Runs all prerequisite checks, reports summary at end |
| `lib/stacks/python/verify.sh` | Same pattern as PHP verify |
| `lib/stacks/php/preflight-checks.sh` | Runs quality gates, must report all failures (no explicit `set` — relies on sourced _common.sh) |
| `lib/stacks/python/preflight-checks.sh` | Same pattern as PHP preflight (no explicit `set`) |
| `lib/dev/gpu-check.sh` | Probes multiple GPU backends, some will always fail |
| `lib/dev/health-check-localdev.sh` | Checks multiple services, reports combined health status |
| `lib/dev/start-dev.sh` | Manages multiple background processes with custom cleanup |

**Prevention:** Before adding `set -e` to any script, check if it uses `step`/`pass`/`fail` patterns or accumulates failures in an array. If it does, omitting `-e` is intentional.

---

## Footgun: WSL PATH pollution

**Symptoms:** A script resolves a Windows binary (e.g., `/mnt/c/Program Files/nodejs/npm`) instead of the native Linux one. Commands appear to exist but produce wrong output or fail cryptically.

**Why it happens:** Only `lib/ai-cli/_common.sh` sanitizes PATH for WSL (via `sanitize_path_for_wsl()` and `command_exists()`). Scripts in other domains (`aws/`, `dev/`, `stacks/`) use bare `command -v` checks, which can resolve Windows binaries leaking into WSL's PATH through `/mnt/*` entries.

**Prevention:** When writing scripts that run on WSL and depend on native Linux binaries (node, npm, python, aws, docker), either source `ai-cli/_common.sh` or add an explicit `/mnt/*` rejection check. At minimum, document the WSL assumption.

---

## Footgun: Three logging paradigms

**Symptoms:** A new script's output looks inconsistent with its sibling scripts. Log lines use a different prefix style, different colors, or different symbols than other scripts in the same directory.

**Why it happens:** The codebase uses three distinct logging paradigms:

1. **ai-cli style** — Direct `echo -e` with color constants (`$RED`, `$GREEN`, etc.). No prefix tags. Used by all `lib/ai-cli/` scripts via `_common.sh`.
2. **stacks style** — Structured `step`/`pass`/`fail`/`skip`/`warn` helpers with Unicode symbols (`✔`, `✘`, `○`, `▸`) plus `log_info`/`log_ok`/`log_warn`/`log_error` with `[INFO]`/`[OK]` prefix tags. Used by all `lib/stacks/` scripts via `_common.sh`.
3. **standalone style** — Inline `log()`/`success()`/`warn()`/`error()` functions with `[tag]` prefixes. Each script defines its own. Used by `lib/aws/`, `lib/dev/`, `lib/maintenance/`, `lib/setup/`, `lib/codegen/`.

**Prevention:** Before writing a new script, read one sibling script in the same directory and match its logging pattern exactly. Never mix paradigms within a directory.

---

## Footgun: `_common.sh` source patterns are not interchangeable

**Symptoms:** `source: No such file or directory` when running a script, or the wrong `_common.sh` gets loaded.

**Why it happens:** The two shared libraries use different source patterns:

- **ai-cli** uses same-directory resolution:
  ```bash
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "${SCRIPT_DIR}/_common.sh"
  ```
- **stacks** uses parent-directory traversal:
  ```bash
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"
  ```

These patterns are tied to the directory structure. Copying a stacks script into a flat directory (or an ai-cli script into a subdirectory) breaks the source path.

**Prevention:** When copying scripts out of this repo, verify the `source` line resolves correctly in the target directory structure. When creating a new script under `stacks/`, always use the `../` traversal pattern. Under `ai-cli/`, always use the same-directory pattern.

---

## Footgun: Template default values are intentional placeholders

**Symptoms:** An AI or contributor "fixes" placeholder values like `my-project`, `us-east-1`, or `8081` in a template script's CONFIGURATION block, breaking the template for all users.

**Why it happens:** Template scripts use generic defaults (e.g., `PROJECT_NAME="${PROJECT_NAME:-my-project}"`) as placeholders that users fill in when copying the script into their project. These look like incomplete code to automated tools or reviewers unfamiliar with the template pattern.

**Prevention:** Never modify values inside a `# ---- CONFIGURATION ----` / `# ---- END CONFIGURATION ----` block unless you are intentionally changing the template interface. The `${VAR:-default}` pattern means the value is overridable via environment variables — the literal default is the fallback, not a mistake.
