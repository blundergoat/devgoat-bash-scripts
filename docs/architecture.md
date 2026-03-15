# Architecture - devgoat-bash-scripts

## What It Is

`devgoat-bash-scripts` is a Bash-first toolkit with a small PHP dashboard. Most functionality lives in standalone scripts under `lib/`. The repo has no package manager or build step; quality comes from shell linting, bats tests, smoke paths, and targeted PHP linting.

## Core Layout

```text
lib/
  ai-cli/       AI installer scripts plus _common.sh
  aws/          AWS wrappers plus _aws-common.sh
  codegen/      generated artefacts and repo inspection helpers
  docker/       Docker workflow helpers
  health/       host and service health checks
  maintenance/  repo maintenance helpers
  stacks/       stack setup/verify scripts plus _common.sh
  tools/        installer helpers for developer tools
  workflow/     repo entrypoints and workflow utilities
dashboard/      PHP UI for running scripts from a browser
docs/           architecture, footguns, lessons, workflow docs
scripts/        Codex workflow validation and preflight wrappers
tests/          bats suite
```

## Runtime Flows

1. Humans or agents run shell entrypoints directly, usually from `lib/`, `help.sh`, or `preflight-checks.sh`.
2. The dashboard launches shell scripts and parses some human-readable output back into UI cards and tables.
3. Three domains share helper libraries: `lib/ai-cli/_common.sh`, `lib/stacks/_common.sh`, and `lib/aws/_aws-common.sh`.
4. Repo verification is split:
   - `preflight-checks.sh` checks `lib/**/*.sh`
   - `scripts/preflight-checks.sh` adds Codex workflow assets, root shell entrypoints, dashboard PHP linting, and workflow validation

## Constraints

- Template `# ---- CONFIGURATION ----` blocks are public interfaces, not placeholders to "fix".
- Helper sourcing is domain-specific; `ai-cli`, `stacks`, and `aws` do not share one pattern.
- Only `ai-cli/_common.sh` sanitises WSL PATH; other domains use plain `command -v`.
- Some verify/preflight scripts intentionally omit `-e` so they can report multiple failures.
- The dashboard has cross-domain coupling to exact shell output headings, especially in AWS reports.

## Trade-Offs

- Keeping scripts largely standalone makes them portable, but conventions are enforced socially and through linting rather than a framework.
- Human-readable output is good for terminals and the dashboard, but it makes parsers sensitive to heading changes.
- Root preflight stays fast by focusing on `lib/`, so the Codex wrapper has to cover root and workflow files explicitly.
