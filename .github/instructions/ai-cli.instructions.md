---
applyTo: "lib/ai-cli/**"
---

# ai-cli Domain

Scripts for installing and uninstalling AI coding assistants. All are **drop-in** (no CONFIGURATION block needed).

## Shared Library: `_common.sh`

Source pattern (same-directory):
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"
```

### Platform Detection (runs on source)
- `GOAT_OS` — `macOS` | `Linux` | `Windows` | `Unknown`
- `GOAT_IS_WSL` — `true` | `false`
- `GOAT_IS_GITBASH` — `true` | `false`

### Key Functions
| Function | Purpose |
|----------|---------|
| `command_exists CMD` | WSL-aware: rejects `/mnt/*` paths |
| `sanitize_path_for_wsl` | Strips `/mnt/*` entries from PATH |
| `require_npm` | Ensures native npm is on PATH (calls `sanitize_path_for_wsl`) |
| `require_node_or_install` | Checks for Node.js, offers auto-install per platform |
| `verify_native_binary CMD` | Post-install check: rejects Windows shims in WSL |
| `block_gitbash NAME` | Exits with error if running in Git Bash/MSYS |
| `confirm_or_auto MSG` | Interactive prompt; auto-proceeds in non-interactive mode |
| `remove_dir_prompt DIR` | Prompted `rm -rf` with non-interactive fallback |
| `npm_prefix_warning` | Warns about multiple npm-related PATH entries |

### Color Constants
`RED`, `GREEN`, `YELLOW`, `CYAN`, `WHITE`, `NC` (no reset — uses `NC`)

## Install Script Pattern
1. Source `_common.sh`
2. `block_gitbash` (if tool doesn't support Git Bash)
3. `print_platform`
4. `require_node_or_install` (for npm-based tools)
5. Install via npm/curl/binary download
6. `verify_native_binary`
7. `npm_prefix_warning`

## Uninstall Script Pattern
1. Source `_common.sh`
2. `require_npm`
3. `npm uninstall -g <package>`
4. Optional `remove_dir_prompt` for config dirs

## Logging Style
Direct `echo -e` with color variables. **No prefix tags** (no `[INFO]`, `[OK]`, etc.). This differs from stacks and standalone scripts.
