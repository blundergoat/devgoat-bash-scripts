# ai-cli — Local Warnings

- **WSL PATH:** Only this domain sanitises PATH for WSL. `sanitize_path_for_wsl()` and `command_exists()` in `_common.sh` reject `/mnt/*` binaries. Other domains do NOT do this.
- **Source pattern:** Same-directory: `source "${SCRIPT_DIR}/_common.sh"`. Do NOT use parent traversal (`../`) — that's the stacks pattern.
- **Logging:** Direct `echo -e` with color constants. No `[tag]` prefixes. No `step`/`pass`/`fail` helpers.
- **Ask First:** Changes to `_common.sh` affect all installers in this directory.
