# TODO Scripts Plan

## 1. Goal

Restructure `devgoat-bash-scripts/lib/` so it is:

- workflow-first (easy to find by task, not only by language)
- reusable across mixed stacks (Go, Rust, PHP, Python, Node)
- safe by default (idempotent checks, explicit `--dry-run` for risky actions)
- generic enough for drop-in usage while keeping config conventions project-owned

Source projects reviewed:

- `/srv/docker-server/projects/deploy/devgoat-bash-scripts`
- `/srv/docker-server/projects/deploy/blundergoat-platform/scripts`
- `/srv/docker-server/projects/deploy/devex-dashboard/scripts`
- `/srv/docker-server/projects/deploy/sus-form-detector/scripts`
- `/srv/docker-server/projects/deploy/the-summit-chatroom/scripts`
- `/srv/docker-server/projects/deploy/ambient-scribe/scripts`
- `/srv/docker-server/projects/deploy/blunderlab/scripts`
- `/srv/docker-server/projects/deploy/healthkit/scripts`

---

## 2. Repeated Workflow Patterns (Observed)

## 2.1 Core loops

1. Initial bootstrap (`setup-initial.sh`)
2. Daily startup (`start-dev.sh`)
3. Post-branch dependency sync (`dependencies-install.sh`)
4. Smart/full rebuild (`smart-rebuild.sh`, `run-full-rebuild.sh`)
5. DB rebuild/migrate/seed (`rebuild-database.sh`, `run-database-rebuild.sh`)
6. Preflight gate before push (`preflight-checks.sh`)
7. Local + remote diagnostics (`health-check-*`, `run-check-*`)
8. Deploy + post-deploy checks (`deploy.sh`, `terraform.sh`, cloud health checks)

## 2.2 High-value patterns to extract

- `env-detect.sh` style environment/container autodetection
- stateful rebuild skipping via `.rebuild-state`
- aggregate health report runner (`health-check-report.sh`)
- API auth diagnostics (OAuth + JWT probe scripts)
- lock-based shared DB operations to prevent race conditions
- WSL-focused recovery (PATH, DNS, mount, network healing)

---

## 3. Current-State Constraints and Known Gaps

## 3.1 Structure mismatch

Current `lib/` mixes domain and operation concerns (`aws`, `stacks`, `dev`, `tools`, `maintenance`).

## 3.2 Docs/help drift risk

Docs and helper indexes must be treated as part of refactor scope. Any path move or deletion must include same-change updates for:

- `README.md`
- `docs/code-map.md`
- `help.sh`

## 3.3 Explicit deletion/deprecation set (authoritative)

Already removed in the current branch (verified):

1. `lib/codegen/generate-api-client.sh`
2. `lib/dev/dev-logs.sh`
3. `lib/maintenance/update-all.sh`
4. `lib/maintenance/verify-checksums.sh`
5. `lib/tools/install-bats.sh`

Planned removals in this refactor (must be executed explicitly, not by omission):

6. `lib/aws/amplify-health-check.sh`
7. `lib/aws/amplify-variables-get.sh`
8. `lib/aws/amplify-variables-set.sh`

Note: earlier drafts treated 10 items as deletions; in this plan, `start-dev.sh` and `health-check-remote.sh` are migrations, so the authoritative deletion set is 8.

Not deletions (migrations):

- `lib/dev/sync-env.sh` -> `lib/workflow/sync-env.sh`
- `lib/dev/start-dev.sh` -> `lib/workflow/start-dev.sh`
- `lib/dev/health-check-remote.sh` -> `lib/health/check-remote.sh`
- `lib/aws/deploy-ecr-ecs.sh` -> `lib/aws/deploy.sh`

If additional scripts are proposed for deletion, they must be added here with explicit rationale and migration/no-migration status before implementation.

---

## 4. Target `lib/` Architecture (Workflow-First, Lightweight Core)

```text
lib/
  _core/
    common.sh          # shared logging/colors/safe helpers
    platform.sh        # linux/macos/wsl/gitbash detection
    locks.sh           # flock wrappers + lock helpers

  workflow/
    help-index.sh
    setup-initial.sh
    setup-verify.sh
    start-dev.sh
    stop-dev.sh
    sync-env.sh
    rebuild-smart.sh
    rebuild-full.sh
    switch-mode.sh

  deps/
    install.sh         # orchestrates package-manager installs
    update.sh
    composer.sh
    npm.sh
    pip.sh
    cargo.sh

  docker/
    up.sh
    down.sh
    restart.sh
    logs-tail.sh
    prune.sh           # replaces docker-cleanup semantics
    network-heal.sh
    mount-doctor.sh

  db/
    rebuild.sh
    migrate.sh
    rollback.sh
    seed.sh
    ensure-databases.sh

  health/
    check-local.sh
    check-remote.sh
    check-aws.sh
    check-api-auth.sh
    check-gpu.sh
    port-check.sh
    load-test.sh
    report.sh

  quality/
    preflight.sh
    lint-shell.sh
    lint-stack.sh
    patch-lint.sh

  aws/
    aws-cli.sh
    terraform.sh
    deploy.sh
    s3-sync.sh
    cloudfront-invalidate.sh
    secrets-manager-get.sh
    secrets-manager-set.sh
    secrets-manager-health-check.sh

  stacks/
    _common.sh
    go/
    node/
    php/
    python/
    rust/

  ai-cli/
    _common.sh
    install-*.sh
    uninstall-*.sh

  maintenance/
    make-scripts-executable.sh
    remove-zone-identifier.sh
    git-cleanup.sh
    scan-secrets.sh

  codegen/
    generate-code-map.sh

  tools/
    install-bats-core.sh
    install-ollama.sh
    uninstall-ollama.sh
    install-starship.sh
    uninstall-starship.sh

```

## 4.1 Ownership boundaries (single source of truth)

- `stacks/*` stays the canonical language implementation layer.
- `workflow/*` is orchestration only; it calls `stacks/*` and shared modules.
- `deps/*` provides package-manager primitives only (composer/npm/pip/cargo helpers).
- `stacks/*/dependencies-install.sh` and `stacks/*/dependencies-update.sh` remain the user-facing stack entrypoints.
- stack dependency scripts may call `deps/*`, but dependency decision logic lives in `stacks/*` to avoid drift.
- `quality/preflight.sh` is cross-repo gate logic; stack-specific checks remain in `stacks/*/preflight-checks.sh`.
- `quality/lint-stack.sh` is a dispatcher only; actual app lint commands stay stack-specific (`stacks/*`).
- no global `.devgoat.env` contract: each project keeps its own env/config format and loading rules.
- Keep `ai-cli/_common.sh` and `stacks/_common.sh` separate (no forced merge).

## 4.2 Script discovery contract

- root `help.sh` stays stable for users and CI docs.
- `lib/workflow/help-index.sh` powers categorized output by workflow area (`setup`, `deps`, `docker`, `db`, `health`, `quality`, `deploy`).
- support `help.sh <keyword>` search mode (substring match on script name + short description).
- every user-facing script must provide `--help` with: purpose, required env/config keys, examples.

---

## 5. Migration Strategy and Sequencing

## 5.1 Non-breaking rule

For every moved/renamed script:

- create new path
- add old-path wrapper in same commit
- preserve CLI interface and exit codes
- print deprecation notice with migration target

Do not defer wrappers to a later phase.

## 5.2 Wrapper deprecation horizon

- wrapper introduction target: `v1.2.0`
- earliest wrapper removal target: `v1.4.0` and no earlier than `2026-06-01`
- removal trigger (all required):
  - old path documented as deprecated in 2 consecutive minor releases
  - new path documented in `README.md`, `docs/code-map.md`, `help.sh`
  - wrapper contract checks remain green through both minor releases

## 5.3 Corrected migration map

| Current | Proposed |
|---|---|
| `lib/dev/start-dev.sh` | `lib/workflow/start-dev.sh` |
| `lib/dev/db-reset.sh` | `lib/db/rebuild.sh` |
| `lib/dev/docker-logs.sh` | `lib/docker/logs-tail.sh` |
| `lib/dev/docker-cleanup.sh` | `lib/docker/prune.sh` |
| `lib/dev/port-check.sh` | `lib/health/port-check.sh` |
| `lib/dev/gpu-check.sh` | `lib/health/check-gpu.sh` |
| `lib/dev/sync-env.sh` | `lib/workflow/sync-env.sh` |
| `lib/dev/health-check-localdev.sh` | `lib/health/check-local.sh` |
| `lib/dev/health-check-remote.sh` | `lib/health/check-remote.sh` |
| `lib/dev/api-load-test.sh` | `lib/health/load-test.sh` |
| `lib/aws/deploy-ecr-ecs.sh` | `lib/aws/deploy.sh` |
| `lib/aws/s3-sync.sh` | `lib/aws/s3-sync.sh` (keep) |
| `lib/aws/cloudfront-invalidate.sh` | `lib/aws/cloudfront-invalidate.sh` (keep) |
| `lib/aws/amplify-health-check.sh` | remove (deprecated, no replacement) |
| `lib/aws/amplify-variables-get.sh` | remove (deprecated, no replacement) |
| `lib/aws/amplify-variables-set.sh` | remove (deprecated, no replacement) |
| `lib/stacks/php/check-complexity.php` | keep in `lib/stacks/php/check-complexity.php` |
| root `help.sh` | keep root entrypoint, delegate to `lib/workflow/help-index.sh` |
| root `preflight-checks.sh` | keep root entrypoint, delegate to `lib/quality/preflight.sh` |

---

## 6. Prioritized Backlog

## P0 (baseline)

- [ ] `lib/workflow/setup-initial.sh`
- [ ] `lib/workflow/setup-verify.sh`
- [ ] `lib/workflow/rebuild-smart.sh`
- [ ] `lib/workflow/rebuild-full.sh`
- [ ] `lib/docker/restart.sh`
- [ ] `lib/health/report.sh`

## P1 (high-value diagnostics and safety)

- [ ] `lib/health/check-api-auth.sh`
- [ ] `lib/health/check-aws.sh`
- [ ] `lib/docker/mount-doctor.sh`
- [ ] `lib/db/rebuild.sh` with lock support
- [ ] `lib/deps/install.sh` + `lib/deps/update.sh`
- [ ] `lib/workflow/switch-mode.sh`
- [ ] `lib/health/load-test.sh`

## P2 (advanced tooling)

- [ ] `lib/quality/patch-lint.sh`
- [ ] `lib/maintenance/make-dev-bundle.sh`
- [ ] `lib/maintenance/verify-dev-bundle.sh`

---

## 7. Phase Plan, Effort, and Gates

## Phase 0: Foundation correctness (1-2 days)

- [ ] finalize naming (`tools` compatibility wrappers, not hard break)
- [ ] add migration wrapper template and compatibility contract
- [ ] ensure doc/help drift checks in CI and local preflight

Gate:

- zero stale path references in `README.md`, `docs/code-map.md`, `help.sh`

## Phase 1: Core + setup flow (2-4 days)

- [ ] implement `_core` modules
- [ ] implement `workflow/setup-initial.sh`, `workflow/setup-verify.sh`
- [ ] ship wrappers for any moved scripts in same changes

Gate:

- wrappers pass interface contract checks (`--help`, exit-code parity)

## Phase 2: Rebuild/health/docker modules (3-5 days)

- [ ] implement `rebuild-smart`, `rebuild-full`, `docker/restart`, `health/report`
- [ ] implement `health/check-aws`, `health/check-api-auth`, `health/load-test`

Gate:

- Linux and WSL smoke matrix passes

## Phase 3: Packaging + adoption examples (2-3 days)

- [ ] implement bundle tooling scripts in `maintenance/` (no new `package/` dir yet)
- [ ] examples for Go/PHP/Python/Rust adoption
- [ ] migration guide

Gate:

- at least 4 sample projects run setup/start/preflight via generic scripts

---

## 8. Validation and Test Strategy

## 8.1 Contract tests (required)

- wrapper compatibility tests:
  - same args accepted
  - same success/failure exit code semantics
  - deprecation notice present

## 8.2 Script quality tests

- `bash -n` for changed scripts
- `shellcheck` for changed scripts
- `--help` availability tests for user-facing scripts

## 8.3 Runtime smoke matrix

- Linux smoke run for `setup-verify`, `rebuild-smart`, `health/report`
- WSL smoke run for path/Docker/network-sensitive scripts
- destructive ops guarded by `--dry-run` / explicit confirmation

## 8.4 CI integration requirements

- add CI job `scripts-contract` for wrapper/interface checks
- add CI job `scripts-lint` for `bash -n` + `shellcheck`
- add CI job `scripts-smoke-linux`

---

## 9. Objective Acceptance Criteria

Plan considered complete when all are true:

- [ ] 0 stale path references in `README.md`, `docs/code-map.md`, `help.sh`
- [ ] 100% of moved scripts have compatibility wrappers at old paths
- [ ] wrapper contract tests pass for all moved scripts
- [ ] `setup-initial`, `start-dev`, `rebuild-smart`, `preflight` succeed in Linux smoke run
- [ ] WSL smoke run passes for Docker/network-sensitive scripts
- [ ] 4 reference projects (Go, Rust, PHP, Python) run with project-specific config conventions unchanged

---

## 10. Immediate Next Execution Steps

1. Add migration wrapper template + contract test harness.
2. Implement `workflow/setup-verify.sh` and `workflow/rebuild-smart.sh`.
3. Implement `health/report.sh` and `docker/restart.sh`.
4. Update docs/help in every move commit (not as a later cleanup).
