<?php
/**
 * Dashboard script registry.
 *
 * Each entry defines a script the dashboard can run. Only scripts listed here
 * are executable - this file is the whitelist.
 *
 * Auto-copied to config.php on first run. Edit config.php to match your project.
 *
 * Schema (script entries):
 *   id            (required) Unique identifier used in API calls
 *   name          (required) Display label in the sidebar
 *   cmd           (required) Script filename - always relative to SCRIPTS_DIR (never absolute)
 *   desc          (required) One-line description shown below the name
 *   args          (optional) Array of fixed CLI arguments appended to the command
 *   confirm       (optional) true → show confirmation dialog before running
 *   estimatedMins (optional) Default duration estimate shown in confirm dialog
 *   prompt        (optional) Ask for user input before running:
 *                   ['label' => '...', 'type' => 'text']
 *                   ['label' => '...', 'type' => 'text', 'optional' => true]  ← allow empty
 *                   ['label' => '...', 'type' => 'select', 'options' => ['a', 'b']]
 *
 * WSL Path Selector (optional):
 *   Add a 'projects' entry to list known project directories. The dashboard
 *   header will show a dropdown for switching between projects. Each script
 *   then runs with cwd set to the selected project directory.
 *   Alternatively, set the DASHBOARD_PROJECTS env var (comma-separated paths).
 *
 * NOTE: All cmd paths are relative to SCRIPTS_DIR (default: project root).
 * The examples below reference drop-in scripts that ship with devgoat-bash-scripts
 * and work out of the box on any machine.
 */

return [
    [
        'category' => 'devgoat-bash-scripts',
        'scripts' => [
            ['id' => 'help',      'name' => 'Help',      'cmd' => 'help.sh',              'desc' => 'List all available scripts'],
            ['id' => 'preflight', 'name' => 'Preflight', 'cmd' => 'preflight-checks.sh',  'desc' => 'Repo-wide quality gate (syntax, shellcheck, bats)', 'confirm' => true, 'estimatedMins' => 1],
        ],
    ],
    [
        'category' => 'Quick Info',
        'scripts' => [
            ['id' => 'git-status',   'name' => 'Git Status',   'cmd' => 'lib/workflow/git-status.sh',            'desc' => 'Branch, recent commits, and working tree status'],
            ['id' => 'git-checkout', 'name' => 'Git Checkout', 'cmd' => 'lib/workflow/git-change-branch.sh',          'desc' => 'Switch to a branch', 'prompt' => ['label' => 'Branch name', 'type' => 'text']],
            ['id' => 'port-check',   'name' => 'Port Check',   'cmd' => 'lib/health/port-check.sh',          'desc' => 'Show what is listening on common ports', 'prompt' => ['label' => 'Ports (comma-separated, or leave empty for defaults)', 'type' => 'text', 'optional' => true]],
            ['id' => 'code-map',     'name' => 'Code Map',     'cmd' => 'lib/codegen/generate-code-map.sh', 'desc' => 'Generate annotated directory tree'],
        ],
    ],
    [
        'category' => 'Maintenance',
        'scripts' => [
            ['id' => 'chmod',        'name' => 'Fix Permissions',  'cmd' => 'lib/maintenance/make-scripts-executable.sh', 'desc' => 'Restore chmod +x on all .sh files'],
            ['id' => 'zone-id',      'name' => 'Zone.Identifier',  'cmd' => 'lib/maintenance/remove-zone-identifier.sh', 'desc' => 'Remove Windows Zone.Identifier ADS files', 'args' => ['.']],
            ['id' => 'scan-secrets', 'name' => 'Scan Secrets',     'cmd' => 'lib/maintenance/scan-secrets.sh',           'desc' => 'Scan for accidentally committed secrets'],
        ],
    ],
    // WSL Path Selector: known project directories (optional)
    // Uncomment and add your project paths to enable the project switcher.
    // [
    //     'projects' => [
    //         '/srv/docker-server/projects/deploy/my-app',
    //         '/srv/docker-server/projects/deploy/my-api',
    //     ],
    // ],
];
