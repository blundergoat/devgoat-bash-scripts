# Dashboard Decoupling Plan

Port the devdex dashboard (a PHP-based script runner web UI) into `dashboard/` as a generic, project-agnostic tool.

## Phases

| Phase | Scope | Outcome |
|-------|-------|---------|
| **Phase 1 — Decouple** | Copy PHP files, remove hardcoded branding, wire env vars, add runtime checks | A working generic dashboard that any project can adopt |
| **Phase 2 — WSL Path Selector** | Add project-switching UI so one dashboard instance targets any local project | Multi-project workflow from a single browser tab |
| **Side — Rename `lib/setup/` → `lib/tools/`** | Rename directory, move `sync-env.sh` to `lib/dev/` | Cleaner directory naming |
| **Side — Prune dead scripts** | Delete 5 low-value scripts across `setup/`, `maintenance/`, `dev/`, `codegen/` | Less dead weight in the repo |
| **Side — Starship** | Add install/uninstall scripts to `lib/tools/` | Starship prompt available as a drop-in tool script |

Phase 1 is the migration. Phase 2 is a feature addition that depends on Phase 1 being complete. The side milestones are independent and can be done at any time (Starship depends on the rename being done first, or adjust paths). The prune and rename milestones should be done together since both touch the same files.

## Source Files

| File | Lines | Role |
|------|-------|------|
| `index.php` | 446 | Router, API handlers, script execution, process management |
| `frontend.php` | 599 | Single-page HTML/CSS/JS UI (inline, no build step) |
| `config.php` | 62 | Script registry / whitelist (category → scripts array) |

**Total:** ~1,100 lines of PHP across 3 files.

## How It Works

- PHP built-in server (`php -S localhost:8899 index.php`) serves a single-page app.
- `config.php` defines a whitelist of runnable scripts with categories, descriptions, and optional prompts/confirmations.
- `index.php` routes API calls (`/api/run`, `/api/stream/{id}`, `/api/stop/{id}`, `/api/status`, `/api/scripts`, `/api/timings`).
- Scripts run via `script(1)` for PTY emulation; output streams to the browser via SSE.
- `frontend.php` renders the full UI inline — sidebar, ANSI-to-HTML converter, dark/light theme toggle.
- Security: localhost-only guard rejects any `REMOTE_ADDR` that isn't `127.0.0.1` or `::1`.

## Security Model

**The dashboard will error out if the request is not from localhost.** This is enforced at the PHP level before any routing occurs:

```php
// index.php lines 18-23 — first thing that runs on every request
$remote = $_SERVER['REMOTE_ADDR'] ?? '';
if (!in_array($remote, ['127.0.0.1', '::1'], true)) {
    http_response_code(403);
    echo 'Forbidden — dashboard is local-dev only';
    exit(1);
}
```

This guard returns HTTP 403 and kills the request immediately — no API handlers, no script execution, no routing. It fires before anything else in the file.

Additional layers:
- `start.sh` binds PHP's built-in server to `127.0.0.1` only (`php -S 127.0.0.1:PORT`), so the server never listens on external interfaces. Even if the PHP guard were somehow bypassed, the OS-level socket binding prevents network access.
- The script whitelist (`config.php`) is the only execution surface — arbitrary commands cannot be injected. `handleApiRun()` looks up the script ID in the whitelist and rejects anything not registered.
- `script(1)` provides PTY emulation but runs as the current user with no privilege escalation.
- The WSL path selector (Phase 2) is also safe because it only changes the `cwd` for script execution — same security boundary as the user running `cd /some/path && bash script.sh` in their terminal. All paths resolve on the local filesystem only. Path traversal (e.g., `../../../../etc`) must be mitigated by resolving to `realpath()` and rejecting any result outside allowed base directories.

**Rule: never remove the localhost guard. Never bind to `0.0.0.0`.**

---

## Phase 1 — Decouple

### Decoupling Checklist: index.php

- [ ] **Branding** (line 3): hardcoded project name in docblock → read from `PROJECT_NAME` env var or default to `DevEx Dashboard`
- [ ] **Temp dir** (line 29): hardcoded `/tmp/{old-project}-dashboard` → `/tmp/{PROJECT_NAME}-dashboard` with fallback to `/tmp/devex-dashboard`
- [ ] **ENV_NAME detection** (line 36): `basename(dirname(PROJECT_ROOT))` assumes a specific path structure → make configurable via `ENV_NAME` env var with the path-based detection as fallback
- [ ] **SITE_URL** (line 37): hardcoded domain URL → read from `SITE_URL` env var, default to empty (hide link when unset)
- [ ] **SCRIPTS_DIR resolution** (line 30-31): `dirname(__DIR__)` assumes dashboard lives inside `scripts/` → resolve from `SCRIPTS_DIR` env var or auto-detect. **Invariant:** `SCRIPTS_DIR` is always an absolute path by the time PHP uses it. `start.sh` resolves it to absolute before exporting; `index.php` reads via `getenv()` and must not re-relativize it. Both Bash and PHP must resolve to the same absolute path

### Decoupling Checklist: frontend.php

- [ ] **Title** (line 39): hardcoded project name in `<title>` → `{env} — {PROJECT_NAME} Dashboard`
- [ ] **Heading** (line 248): hardcoded project name in `<h1>` → `{PROJECT_NAME} Dashboard`
- [ ] **Accent color map** (lines 13-29): hardcoded `envColors` array mapping env names to hex colors → replace with a single neutral default (e.g., indigo/blue). Users who want per-env colors can set them via a `DASHBOARD_ACCENT` env var (hex value)
- [ ] **localStorage key** (line 41, 301): hardcoded theme storage key → generic key like `devex_dash_theme`
- [ ] **Login URL link** (lines 251-252): hardcoded domain link → show only when `SITE_URL` is set, hide otherwise

### Decoupling Checklist: config.php

- [ ] **Ship as `config.example.php`** with generic placeholder entries (e.g., `help`, `health-check`) instead of project-specific scripts
- [ ] **Document the config schema** inline in the example file:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `id` | yes | string | Unique identifier used in API calls |
| `name` | yes | string | Display label in the sidebar |
| `cmd` | yes | string | Script filename — always relative to `SCRIPTS_DIR` (never absolute) |
| `desc` | yes | string | One-line description shown below the name |
| `args` | no | string[] | Fixed CLI arguments appended to the command |
| `confirm` | no | bool | Show confirmation dialog before running |
| `estimatedMins` | no | int | Default duration estimate shown in confirm dialog |
| `prompt` | no | object | Ask for user input before running: `{label, type, options?}` |

### Decoupling Checklist: start.sh

`start.sh` is the glue file — it validates prerequisites, resolves paths, exports env vars, and launches PHP. It has the most moving parts during decoupling.

- [ ] **SCRIPTS_DIR export** — resolve to absolute path before exporting: `SCRIPTS_DIR="$(cd "${SCRIPTS_DIR}" && pwd)"`. This ensures the invariant that PHP always receives an absolute path
- [ ] **PHP version gate** — after checking `command -v php`, verify version is 8.1+. Error with: `"PHP 8.1+ required, found {version}"`
- [ ] **script(1) check** — verify `command -v script`. Error with: `"script command not found — install util-linux"`
- [ ] **config.php check** — already implemented, keep as-is
- [ ] **index.php check** — already implemented, keep as-is
- [ ] **show_help() content** — must document all CONFIGURATION vars, the `--port` flag, and at least one usage example. Already implemented — verify it stays in sync after decoupling changes
- [ ] **No hardcoded paths** — all project-specific values come from the CONFIGURATION block or env vars. Verify no residual absolute paths after decoupling

### Prerequisites

- PHP 8.1+ with `posix` extension (for `posix_kill()` in stop handler)
- `script(1)` command (standard on Linux/macOS, available via `util-linux` on minimal images)
- A `config.php` defining the script registry for the consuming project

### Runtime Checks

| Check | Where | Error message |
|-------|-------|---------------|
| PHP installed | `start.sh` | `"PHP not found. Install PHP 8.1+ to use the dashboard."` |
| PHP >= 8.1 | `start.sh` | `"PHP 8.1+ required, found {version}"` |
| `script(1)` installed | `start.sh` | `"script command not found — install util-linux"` |
| `config.php` exists | `start.sh` | `"Cannot start without config.php"` (with hint to copy example) |
| `index.php` exists | `start.sh` | `"index.php not found — PHP dashboard files not yet ported"` |
| `posix` extension loaded | `index.php` | `"posix extension required — install php-posix or enable it in php.ini"` |

### Platform Notes

`script(1)` differs between Linux (GNU util-linux) and macOS (BSD):
- Linux: `script -qfc "command" logfile`
- macOS: `script -q logfile command`

The current implementation uses the Linux invocation (line 176). To support macOS, detect the platform and branch the `$wrapper` construction. This is a stretch goal — the primary target is WSL/Linux.

### Coexistence

The original source project retains its own copy of the dashboard files. During the transition:
- This repo (`dashboard/`) becomes the canonical upstream.
- The source project can either symlink to this repo's `dashboard/` directory or keep its copy and stop maintaining it.
- No changes are made to the source project as part of this plan — that's the source project's decision.

### Migration Steps

1. **Copy** the 3 PHP files into `dashboard/`
2. **Rename** `config.php` → `config.example.php`
3. **Decouple** each item in the four checklists above (index.php, frontend.php, config.php, start.sh)
4. **Env var wiring** — `start.sh` already exports `PROJECT_NAME`, `SCRIPTS_DIR`, `SITE_URL`, `ENV_NAME`. Verify `index.php` reads them via `getenv()` and that `SCRIPTS_DIR` resolves to the same absolute path in both Bash and PHP
5. **Test** — see Phase 1 acceptance criteria below
6. **Document** in README: prerequisites, config schema, usage

### Phase 1 Acceptance Criteria

- [ ] `./dashboard/start.sh --help` exits 0 and shows usage, all CONFIGURATION vars, `--port` flag, and examples
- [ ] `./dashboard/start.sh` starts the server (with config.php and index.php present)
- [ ] No hardcoded project names appear in any dashboard output or HTML source
- [ ] Dashboard loads with zero env vars set (all defaults work)
- [ ] `curl http://localhost:8899/` returns 200 with HTML
- [ ] `curl` from localhost with spoofed headers (`X-Forwarded-For: 1.2.3.4`) still returns 200 — the guard checks `REMOTE_ADDR` at the socket level, not request headers, so header spoofing has no effect with PHP's built-in server
- [ ] Non-whitelisted script ID via `POST /api/run` returns 400
- [ ] `posix` extension missing → clear error message at startup
- [ ] `script(1)` missing → clear error message from `start.sh`
- [ ] PHP < 8.1 → clear error message from `start.sh`
- [ ] `SCRIPTS_DIR` resolves to the same absolute path in both `start.sh` (Bash) and `index.php` (PHP)

---

## Phase 2 — WSL Path Selector

**Depends on:** Phase 1 complete.

**Goal:** Run dashboard scripts against any project on the local WSL filesystem, not just the one the dashboard was started from.

### How It Works

A dropdown or combobox in the dashboard header that lets you pick a project directory. When you select a path, the dashboard changes the working directory (`cwd`) for all subsequent script executions to that path. This means any script in the whitelist runs as if you had `cd`-ed into that project first.

### UI

- **Location:** Header bar, between the heading and the env badge (or replacing the env badge when a path is selected).
- **Type:** Combobox — a dropdown of known project paths with a text input for typing custom paths.
- **Persistence:** Selected path stored in `localStorage` so it survives page reloads.
- **Visual feedback:** Show the selected project path (or basename) in the header so you always know which project you're targeting.

### Backend

- [ ] **New API endpoint** `GET /api/projects` — returns the list of known project directories. Source: a `projects` array in `config.php` or a `DASHBOARD_PROJECTS` env var (comma-separated paths). Example:
  ```php
  // config.php
  'projects' => [
      '/srv/docker-server/projects/deploy/my-app',
      '/srv/docker-server/projects/deploy/my-api',
      '/srv/docker-server/projects/deploy/my-site',
  ],
  ```
- [ ] **New API endpoint** `POST /api/project` — sets the active project path. Validates the path exists on disk and is a directory. **Session model:** the active path is sent by the client on each `/api/run` request (as a `project` field in the JSON body) rather than stored server-side. This avoids shared-state conflicts when multiple browser tabs are open — each tab tracks its own selected project in `localStorage` and sends it per-request
- [ ] **Modify `handleApiRun()`** — when a `project` field is present in the request body, resolve `cmd` relative to that project's scripts directory and set `cwd` to the project root when spawning the process. `SCRIPTS_DIR` is always relative to the project root: the command becomes `cd {project_path} && bash {SCRIPTS_DIR}/{cmd}`
- [ ] **Path validation** — resolve the client-provided path via `realpath()` and reject any result that: doesn't exist, isn't a directory, or falls outside allowed base directories (e.g., must be under `/srv/`, `/home/`, or `/mnt/` on WSL). This mitigates path traversal (`../../../../etc`) and prevents accidental foot-guns

### Frontend

- [ ] **Header combobox** — `frontend.php` renders a `<select>` with an "other" option that reveals a text input. Populated from `/api/projects` on page load.
- [ ] **Active project indicator** — show the basename of the selected path as a badge in the header (e.g., `my-app`, `my-api`).
- [ ] **Reload sidebar on project switch** — after changing the project, re-fetch `/api/scripts` in case a project-local config override exists.
- [ ] **Per-request project field** — `runScript()` in JS includes `project: localStorage.getItem('devex_dash_project')` in the JSON body sent to `/api/run`.

### Security Notes

The WSL path selector does not weaken the security model:
- The dashboard is localhost-only — changing the `cwd` is equivalent to the user running `cd /path && bash script.sh` in their own terminal.
- The script whitelist still applies — you can only run commands listed in `config.php`, regardless of which project path is selected.
- Path validation uses `realpath()` to resolve symlinks and `..` segments, then checks the result against allowed base directories. This is a defense-in-depth measure — the real security boundary is localhost-only + whitelist.

### Phase 2 Acceptance Criteria

- [ ] WSL path selector: selecting a project path changes the cwd for the next script run
- [ ] WSL path selector: typing a non-existent path shows an error
- [ ] WSL path selector: path traversal attempts (e.g., `../../../../etc/passwd`) are rejected
- [ ] WSL path selector: two browser tabs can target different projects simultaneously without conflicts
- [ ] WSL path selector: selected project persists across page reloads via `localStorage`

---

## Side Milestone — Rename `lib/setup/` → `lib/tools/` and Reorganize

**Independent of the dashboard work.** The current `lib/setup/` name implies one-time project setup, but its scripts are standalone tool installers/uninstallers. Rename to `lib/tools/` for clarity.

### Changes

| Action | File | Reason |
|--------|------|--------|
| **Rename** | `lib/setup/` → `lib/tools/` | All remaining scripts are tool installers — `tools/` is a more accurate name |
| **Move** | `lib/setup/sync-env.sh` → `lib/dev/sync-env.sh` | `sync-env.sh` is a project-level dev workflow template (copies `.env.example` → `.env`), not a tool installer. Belongs with `start-dev.sh`, `db-reset.sh`, etc. |

After reorganization, `lib/tools/` contains only tool installers:
- `install-bats-core.sh`
- `install-ollama.sh` / `uninstall-ollama.sh`
- `install-starship.sh` / `uninstall-starship.sh` (new, see below)

### Files to Update

Every reference to `lib/setup/` must change to `lib/tools/`.

- [ ] `CLAUDE.md` — Context Router table
- [ ] `.github/instructions/dev.instructions.md` — `applyTo` glob, Template vs Drop-in table
- [ ] `docs/code-map.md` — tree listing, count
- [ ] `README.md` — Directory Overview table, `### setup` section (rename to `### tools`)
- [ ] `CHANGELOG.md` — add rename and move entries
- [ ] `help.sh` — Setup section (rename to Tools)
- [ ] `AGENTS.md` / `GEMINI.md` — if they reference `lib/setup/`

### Acceptance Criteria

- [ ] `lib/setup/` no longer exists
- [ ] `lib/tools/` contains: `install-bats-core.sh`, `install-ollama.sh`, `uninstall-ollama.sh` (+ Starship scripts when added)
- [ ] `lib/dev/sync-env.sh` exists and passes `bash -n`
- [ ] `grep -r 'lib/setup' .` returns zero matches (excluding `.git/`)

---

## Side Milestone — Prune Dead Scripts

**Independent of the dashboard work. Best done alongside the rename milestone** since both touch the same doc files.

Remove 5 low-value scripts that are dead weight — deprecated shims, scripts with no backing data, thin wrappers, and tightly coupled templates.

### Scripts to Delete

| # | Script | Reason |
|---|--------|--------|
| 1 | `lib/setup/install-bats.sh` | Deprecated shim that redirects to `install-bats-core.sh`. Dead code |
| 2 | `lib/maintenance/verify-checksums.sh` | Verifies against a SHA-256 manifest, but no manifest file exists in the repo. Non-functional |
| 3 | `lib/maintenance/update-all.sh` | Does `git pull --rebase` then calls `make-scripts-executable.sh`. Two commands that don't need a script |
| 4 | `lib/dev/dev-logs.sh` | Tightly coupled to `start-dev.sh`'s service layout. Only works if the consuming project matches that exact structure |
| 5 | `lib/codegen/generate-api-client.sh` | 34-line `npx @openapitools/openapi-generator-cli` wrapper. Thin enough to be a one-liner in the project's own scripts |

### Files to Update

Every reference to the deleted scripts must be removed from documentation.

- [ ] `docs/code-map.md` — remove entries, update counts (maintenance: 7→5, dev: 10→9, codegen: 2→1, setup/tools: remove `install-bats.sh`)
- [ ] `README.md` — remove from tables in `### maintenance`, `### dev`, `### codegen`, `### setup`/`### tools`
- [ ] `CHANGELOG.md` — add `### Removed` entries
- [ ] `help.sh` — remove entries from Maintenance, Development, Code Generation sections
- [ ] `.github/instructions/dev.instructions.md` — remove from Template vs Drop-in tables and Notable Scripts if referenced

### Acceptance Criteria

- [ ] All 5 files deleted from disk
- [ ] `grep -r 'install-bats\.sh\|verify-checksums\|update-all\.sh\|dev-logs\.sh\|generate-api-client' .` returns zero matches (excluding `.git/`)
- [ ] Script counts in `docs/code-map.md` are correct after deletions

---

## Side Milestone — Starship Prompt Install/Uninstall

**Independent of the dashboard work. Depends on the `lib/tools/` rename being done first** (or adjust paths if done before).

[Starship](https://starship.rs) is a fast, cross-shell prompt written in Rust. It works on Bash, Zsh, Fish, PowerShell, and others.

### Scripts to Create

| File | Type | Description |
|------|------|-------------|
| `lib/tools/install-starship.sh` | Drop-in | Install Starship via the official `install.sh` curl script |
| `lib/tools/uninstall-starship.sh` | Drop-in | Remove Starship binary and optionally clean config |

### install-starship.sh

- `#!/usr/bin/env bash`, `set -euo pipefail`, `show_help()`, inline colors (standalone paradigm, matches `install-ollama.sh`)
- Check if Starship is already installed (`command -v starship`)
- Install via the official installer: `curl -sS https://starship.rs/install.sh | sh -s -- --yes`
- Verify binary is on PATH after install
- Print shell init instructions for the user's detected shell:
  - Bash: `eval "$(starship init bash)"` in `~/.bashrc`
  - Zsh: `eval "$(starship init zsh)"` in `~/.zshrc`
  - Fish: `starship init fish | source` in `~/.config/fish/config.fish`
- Optionally create a starter `~/.config/starship.toml` if one doesn't exist (with `--config` flag or skip by default)

### uninstall-starship.sh

- `#!/usr/bin/env bash`, `set -euo pipefail`, `show_help()`, inline colors
- Remove the Starship binary (default: `/usr/local/bin/starship`, or detect via `command -v`)
- Prompt before removing `~/.config/starship.toml` (with `--purge` flag to skip prompt)
- Remind user to remove the `eval "$(starship init ...)"` line from their shell rc file

### Documentation Updates

- [ ] Add both scripts to `docs/code-map.md` under `tools/` (update count)
- [ ] Add both scripts to `README.md` tools table
- [ ] Add to `CHANGELOG.md` under `### Added`
- [ ] Add to `help.sh` under the Tools section

### Acceptance Criteria

- [ ] `bash -n` and `shellcheck` pass on both scripts
- [ ] `./lib/tools/install-starship.sh --help` exits 0
- [ ] `./lib/tools/uninstall-starship.sh --help` exits 0
- [ ] Install succeeds on a clean system and `starship --version` works after
- [ ] Uninstall removes the binary and `command -v starship` fails after

---

## Target File Listing

```
dashboard/
├── start.sh                # Bash launcher (template, CONFIGURATION block)
├── index.php                # Router + API handlers + localhost guard
├── frontend.php             # Inline HTML/CSS/JS UI + WSL path selector (Phase 2)
└── config.example.php       # Sample script registry + projects list
```
