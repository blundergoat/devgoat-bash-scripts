<?php

/**
 * AWS dashboard UI renderer.
 *
 * Kept separate from aws.php so the UI can evolve without touching the
 * report execution backend or API helpers.
 */

function serveAwsDashboardUi(): void
{
    header('Content-Type: text/html; charset=UTF-8');

    $projectTitle = htmlspecialchars(PROJECT_NAME, ENT_QUOTES);
    $envLabel = htmlspecialchars(ENV_NAME, ENT_QUOTES);
    $reportsJson = json_encode(getAwsReportRegistry(), JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    if (!is_string($reportsJson)) {
        $reportsJson = '{}';
    }
    $envSummaryJson = json_encode(getAwsEnvSummary(), JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    if (!is_string($envSummaryJson)) {
        $envSummaryJson = '{}';
    }

    echo '<!DOCTYPE html>';
    echo '<html lang="en" data-theme="light">';
    echo '<head>';
    echo '<meta charset="UTF-8">';
    echo '<meta name="viewport" content="width=device-width, initial-scale=1.0">';
    echo '<title>AWS Reports - ' . $projectTitle . '</title>';
    echo '<script>document.documentElement.setAttribute("data-theme", localStorage.getItem("devex_dash_theme") || "light");</script>';
    echo <<<'CSS'
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body { min-height: 100%; }
body {
    font-family: var(--font-sans);
    background: var(--c-bg);
    color: var(--c-text-primary);
}
[data-theme="dark"] body {
    background: var(--c-bg);
    color: var(--c-text-primary);
}
:root, [data-theme="light"] {
    --font-sans: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    --font-mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace;
    --c-bg: #f8fafc;
    --c-surface: #ffffff;
    --c-surface-hover: #f8fafc;
    --c-text-primary: #0f172a;
    --c-text-secondary: #334155;
    --c-text-muted: #64748b;
    --c-text-faint: #94a3b8;
    --c-border: rgba(148,163,184,0.28);
    --c-scrollbar: rgba(148,163,184,0.45);
    --c-accent: #2563eb;
    --c-accent-hover: #1d4ed8;
    --c-badge-bg: rgba(37,99,235,0.1);
    --c-badge-border: rgba(37,99,235,0.25);
    --c-badge-text: #1d4ed8;
    --c-green: #16a34a;
    --c-red: #dc2626;
    --c-yellow: #d97706;
    --c-blue: #2563eb;
    --c-terminal-bg: #f8fafc;
    --shadow-sm: 0 1px 2px rgba(15,23,42,0.05);
    --shadow: 0 1px 2px rgba(15,23,42,0.06), 0 1px 1px rgba(15,23,42,0.04);

    --bg-panel: var(--c-surface);
    --bg-soft: var(--c-surface-hover);
    --bg-muted: var(--c-bg);
    --border: var(--c-border);
    --text-main: var(--c-text-primary);
    --text-muted: var(--c-text-muted);
    --text-faint: var(--c-text-faint);
    --accent: var(--c-accent);
    --accent-strong: var(--c-accent);
    --good: var(--c-green);
    --warn: var(--c-yellow);
    --bad: var(--c-red);
    --blue: var(--c-blue);
    --mono-bg: var(--c-terminal-bg);
}
[data-theme="dark"] {
    --c-bg: #020617;
    --c-surface: #0f172a;
    --c-surface-hover: #111827;
    --c-text-primary: #e2e8f0;
    --c-text-secondary: #cbd5e1;
    --c-text-muted: #94a3b8;
    --c-text-faint: #64748b;
    --c-border: rgba(148,163,184,0.2);
    --c-scrollbar: rgba(148,163,184,0.35);
    --c-accent: #60a5fa;
    --c-accent-hover: #3b82f6;
    --c-badge-bg: rgba(96,165,250,0.14);
    --c-badge-border: rgba(96,165,250,0.3);
    --c-badge-text: #93c5fd;
    --c-green: #4ade80;
    --c-red: #fb7185;
    --c-yellow: #f59e0b;
    --c-blue: #89b4fa;
    --c-terminal-bg: #020617;
    --shadow-sm: 0 1px 2px rgba(2,6,23,0.45);
    --shadow: 0 1px 2px rgba(2,6,23,0.45), 0 1px 1px rgba(2,6,23,0.3);

    --bg-panel: var(--c-surface);
    --bg-soft: var(--c-surface-hover);
    --bg-muted: var(--c-bg);
    --border: var(--c-border);
    --text-main: var(--c-text-primary);
    --text-muted: var(--c-text-muted);
    --text-faint: var(--c-text-faint);
    --accent: var(--c-accent);
    --accent-strong: var(--c-accent);
    --good: var(--c-green);
    --warn: var(--c-yellow);
    --bad: var(--c-red);
    --blue: var(--c-blue);
    --mono-bg: var(--c-terminal-bg);
}
::-webkit-scrollbar { width: 6px; height: 6px; }
::-webkit-scrollbar-thumb { background: var(--c-scrollbar); border-radius: 3px; }
.aws-shell {
    width: 100%;
    margin: 0;
    padding: 16px;
}
.aws-results-shell,
.aws-overview-card,
.aws-panel,
.aws-output-shell,
.aws-table-shell {
    border: 1px solid var(--border);
    background: var(--bg-panel);
    box-shadow: var(--shadow);
}
.aws-header {
    display: flex;
    justify-content: space-between;
    gap: 14px;
    align-items: flex-start;
    padding: 0 0 12px;
    margin-bottom: 12px;
    border-bottom: 1px solid var(--c-border);
}
.aws-header-copy { min-width: 0; }
.aws-back {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    text-decoration: none;
    color: var(--c-text-muted);
    min-height: 30px;
    font-size: 11px;
    font-weight: 600;
    margin-bottom: 6px;
    padding: 0 10px;
    border-radius: 8px;
    border: 1px solid var(--c-border);
    background: var(--c-surface);
    box-shadow: var(--shadow-sm);
}
.aws-back:hover { color: var(--c-text-primary); border-color: var(--c-accent); background: var(--c-surface-hover); }
.aws-eyebrow {
    font-family: var(--font-mono);
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: var(--c-text-muted);
    margin-bottom: 6px;
}
.aws-header h1 {
    font-size: clamp(0.95rem, 1.3vw, 1.1rem);
    font-weight: 600;
    letter-spacing: -0.025em;
    line-height: 1.1;
    margin-bottom: 4px;
}
.aws-header p {
    max-width: 720px;
    color: var(--c-text-muted);
    line-height: 1.5;
    font-size: 12px;
}
.aws-header-actions {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 6px;
}
.aws-chip-row {
    display: flex;
    flex-wrap: wrap;
    justify-content: flex-end;
    gap: 6px;
}
.aws-chip {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    min-height: 24px;
    padding: 0 8px;
    border-radius: 999px;
    background: var(--c-badge-bg);
    border: 1.5px solid var(--c-badge-border);
    color: var(--c-badge-text);
    font-size: 10px;
    font-weight: 600;
}
.aws-chip strong { font-weight: 600; }
.aws-chip.bad {
    color: var(--c-red);
    border-color: var(--c-red);
    background: rgba(220,38,38,0.08);
}
.aws-chip.good {
    color: var(--c-green);
    border-color: rgba(22,163,74,0.35);
    background: rgba(22,163,74,0.08);
}
.aws-header-buttons {
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
}
.theme-toggle {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
    border: 1px solid var(--c-border);
    border-radius: 8px;
    background: var(--c-surface-hover);
    color: var(--c-text-muted);
    padding: 0;
    cursor: pointer;
    transition: all 0.15s;
    box-shadow: var(--shadow-sm);
}
.ghost-link,
.action-btn {
    border: 1px solid var(--c-border);
    border-radius: 8px;
    background: var(--c-surface-hover);
    color: var(--c-text-secondary);
    text-decoration: none;
    min-height: 30px;
    padding: 0 10px;
    font-size: 11px;
    font-family: inherit;
    line-height: 1.2;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s;
    box-shadow: var(--shadow-sm);
}
.theme-toggle:hover { color: var(--c-text-primary); background: var(--c-surface-hover); }
.ghost-link:hover,
.action-btn:hover {
    background: var(--c-bg);
    color: var(--c-text-primary);
    border-color: var(--c-accent);
}
.aws-overview {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 12px;
    margin-bottom: 12px;
}
.aws-overview-card {
    border-radius: 16px;
    padding: 14px;
    min-width: 0;
}
.aws-card-header {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    align-items: flex-start;
}
.aws-card-title h2 {
    font-size: 14px;
    font-weight: 600;
    letter-spacing: -0.02em;
    margin-bottom: 2px;
}
.aws-card-title p {
    color: var(--c-text-muted);
    font-size: 11px;
    line-height: 1.45;
}
.aws-card-icon {
    width: 24px;
    height: 24px;
    border-radius: 7px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--c-badge-bg);
    color: var(--c-badge-text);
    flex-shrink: 0;
    font-family: var(--font-mono);
    font-size: 11px;
    font-weight: 600;
}
.aws-card-body { margin-top: 12px; }
.field-label {
    display: block;
    margin-bottom: 6px;
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: var(--c-text-muted);
}
.field-input,
.field-select,
.field-textarea,
.field-static {
    width: 100%;
    border: 1px solid var(--c-border);
    border-radius: 8px;
    background: var(--c-bg);
    color: var(--c-text-primary);
    padding: 8px 10px;
    font-size: 12px;
    font-family: inherit;
    line-height: 1.35;
}
.field-input,
.field-textarea,
.field-static {
    font-family: var(--font-mono);
}
.field-static.muted { color: var(--c-text-muted); }
.field-textarea {
    min-height: 88px;
    resize: vertical;
}
.inline-row {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
}
.inline-row .field-select,
.inline-row .field-input {
    flex: 1;
    min-width: 0;
}
.card-button {
    border: 1px solid var(--c-border);
    border-radius: 8px;
    background: var(--c-surface-hover);
    color: var(--c-text-secondary);
    min-height: 30px;
    padding: 0 10px;
    font-size: 11px;
    font-family: inherit;
    line-height: 1.2;
    font-weight: 600;
    cursor: pointer;
    white-space: nowrap;
    transition: all 0.15s;
    box-shadow: var(--shadow-sm);
}
.card-button:hover {
    background: var(--c-bg);
    color: var(--c-text-primary);
    border-color: var(--c-accent);
}
.card-button.primary {
    background: var(--c-accent);
    color: #fff;
    border-color: var(--c-accent);
}
.card-button.primary:hover {
    background: var(--c-accent-hover);
    color: #fff;
}
.card-button:disabled,
.action-btn:disabled { opacity: 0.6; cursor: wait; }
.card-footnote,
.helper-copy {
    margin-top: 8px;
    color: var(--c-text-muted);
    font-size: 11px;
    line-height: 1.5;
}
.aws-results-shell {
    border-radius: 16px;
    overflow: hidden;
}
.aws-tabs {
    display: flex;
    align-items: center;
    gap: 6px;
    flex-wrap: wrap;
    padding: 8px 12px 0;
    border-bottom: 1px solid var(--border);
}
.tab-btn {
    border: none;
    border-bottom: 2px solid transparent;
    background: transparent;
    color: var(--c-text-muted);
    padding: 8px 8px 9px;
    font-size: 11px;
    font-family: inherit;
    line-height: 1.2;
    font-weight: 600;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    gap: 6px;
}
.tab-btn.active {
    color: var(--c-text-primary);
    border-bottom-color: var(--c-accent);
}
.tab-btn.running { color: var(--c-accent); }
.tab-badge {
    min-width: 18px;
    height: 18px;
    padding: 0 6px;
    border-radius: 999px;
    background: var(--c-badge-bg);
    color: var(--c-badge-text);
    font-family: var(--font-mono);
    font-size: 10px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
}
.aws-results { padding: 14px; }
.results-toolbar {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    align-items: flex-start;
    margin-bottom: 12px;
}
.results-toolbar h2 {
    font-size: 16px;
    font-weight: 600;
    letter-spacing: -0.03em;
    margin-bottom: 4px;
}
.results-toolbar p {
    color: var(--c-text-muted);
    line-height: 1.5;
    font-size: 12px;
}
.toolbar-actions {
    display: flex;
    align-items: center;
    gap: 6px;
    flex-wrap: wrap;
}
.spinner {
    width: 12px;
    height: 12px;
    border-radius: 50%;
    border: 1.8px solid currentColor;
    border-right-color: transparent;
    animation: spin 0.8s linear infinite;
    flex-shrink: 0;
}
@keyframes spin {
    to { transform: rotate(360deg); }
}
.aws-panel {
    border-radius: 16px;
    padding: 12px;
    margin-bottom: 12px;
}
.panel-head {
    display: flex;
    justify-content: space-between;
    gap: 10px;
    align-items: center;
    margin-bottom: 10px;
}
.panel-head h3 {
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: var(--c-text-muted);
    font-family: var(--font-sans);
}
.panel-head span {
    font-size: 11px;
    color: var(--c-text-muted);
}
.control-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap: 12px;
}
.control-stack { display: grid; gap: 12px; }
.quick-actions {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
    margin-top: 8px;
}
.chip {
    border: 1px solid var(--c-border);
    background: var(--c-bg);
    color: var(--c-text-secondary);
    border-radius: 999px;
    padding: 3px 8px;
    font-size: 10px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s;
}
.chip:hover {
    border-color: var(--c-accent);
    color: var(--c-text-primary);
}
.summary-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
    gap: 10px;
    margin-bottom: 12px;
}
.summary-card {
    border-radius: 14px;
    padding: 12px;
    background: var(--c-surface-hover);
    border: 1px solid var(--c-border);
}
.summary-card strong {
    display: block;
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--c-text-muted);
    margin-bottom: 6px;
}
.summary-card span {
    font-size: 16px;
    font-weight: 600;
    line-height: 1.3;
}
.summary-card .summary-value-text {
    font-size: 13px;
    font-weight: 500;
    line-height: 1.45;
    word-break: break-word;
}
.summary-card.good span { color: var(--good); }
.summary-card.warn span { color: var(--warn); }
.summary-card.bad span { color: var(--bad); }
.run-banner {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 10px;
    padding: 10px 12px;
    margin-bottom: 12px;
    border: 1px solid var(--c-badge-border);
    border-radius: 14px;
    background: var(--c-badge-bg);
}
.run-banner-copy {
    display: flex;
    align-items: center;
    gap: 10px;
    min-width: 0;
}
.run-banner-text strong {
    display: block;
    font-size: 12px;
    font-weight: 600;
    margin-bottom: 2px;
}
.run-banner-text span {
    display: block;
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--c-text-muted);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}
.run-banner-time {
    font-size: 12px;
    font-weight: 700;
    white-space: nowrap;
}
.aws-table-shell,
.aws-output-shell {
    border-radius: 16px;
    overflow: hidden;
    margin-bottom: 16px;
}
.table-head,
.shell-header {
    display: flex;
    justify-content: space-between;
    gap: 10px;
    align-items: center;
    padding: 10px 12px;
    border-bottom: 1px solid var(--border);
    background: var(--c-surface);
}
.table-head h3 {
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: var(--c-text-muted);
    font-family: var(--font-sans);
}
.table-head span,
.shell-meta {
    color: var(--c-text-muted);
    font-size: 11px;
}
.shell-header code {
    font-family: var(--font-mono);
    font-size: 11px;
    word-break: break-word;
}
.table-wrap { overflow: auto; background: var(--bg-panel); }
table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12px;
}
th, td {
    padding: 10px 12px;
    border-bottom: 1px solid var(--border);
    text-align: left;
}
th {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--c-text-muted);
    white-space: nowrap;
}
td.numeric,
th.numeric {
    text-align: right;
    white-space: nowrap;
}
.table-wrap tr:last-child td { border-bottom: none; }
.table-wrap tbody tr:hover { background: rgba(148,163,184,0.06); }
.shell-output {
    padding: 12px;
    overflow: auto;
    max-height: 620px;
    font-family: var(--font-mono);
    font-size: 12px;
    line-height: 1.5;
    white-space: pre-wrap;
    word-break: break-word;
    background: var(--c-terminal-bg);
}
.empty-state {
    border: 1px dashed var(--c-border);
    border-radius: 12px;
    padding: 28px 20px;
    text-align: center;
    color: var(--c-text-muted);
    background: var(--c-surface);
    font-size: 12px;
}
.identity-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap: 10px;
    margin-bottom: 12px;
}
.identity-card {
    border: 1px solid var(--c-border);
    border-radius: 14px;
    padding: 12px;
    background: var(--c-surface-hover);
}
.identity-card strong {
    display: block;
    margin-bottom: 8px;
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--c-text-muted);
    font-family: var(--font-sans);
}
.identity-card code,
.identity-card span {
    font-family: var(--font-mono);
    font-size: 12px;
    color: var(--c-text-primary);
    word-break: break-word;
}
.ansi-bold { font-weight: 700; }
.ansi-dim { opacity: 0.65; }
.ansi-black { color: #64748b; }
.ansi-red { color: var(--c-red); }
.ansi-green { color: var(--c-green); }
.ansi-yellow { color: var(--c-yellow); }
.ansi-blue { color: #60a5fa; }
.ansi-magenta { color: #c084fc; }
.ansi-cyan { color: #22d3ee; }
.ansi-white { color: var(--c-text-primary); }
@media (max-width: 1180px) {
    .aws-overview { grid-template-columns: repeat(2, minmax(0, 1fr)); }
}
@media (max-width: 820px) {
    .aws-shell { padding: 10px; }
    .aws-header,
    .results-toolbar,
    .panel-head { flex-direction: column; }
    .aws-header-actions { align-items: flex-start; }
    .aws-chip-row { justify-content: flex-start; }
    .aws-overview { grid-template-columns: 1fr; }
    .toolbar-actions,
    .aws-header-buttons { width: 100%; }
    .theme-toggle { width: 32px; }
    .ghost-link,
    .action-btn { width: 100%; text-align: center; }
}

/* ── Shared UI patterns ──────────────────────────────────────── */
.status-badge {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    font-size: 11px;
    font-weight: 600;
    line-height: 1;
}
.status-badge .dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    flex-shrink: 0;
}
.status-badge.success .dot { background: var(--c-green); }
.status-badge.success { color: var(--c-green); }
.status-badge.error .dot { background: var(--c-red); }
.status-badge.error { color: var(--c-red); }

.summary-card.hero {
    border-left: 3px solid var(--c-accent);
}
.summary-card.hero span {
    font-size: 24px;
    font-weight: 700;
    font-family: var(--font-mono);
}

td.numeric {
    position: relative;
    font-family: var(--font-mono);
    font-variant-numeric: tabular-nums;
}
td.numeric .bar {
    position: absolute;
    top: 2px;
    bottom: 2px;
    left: 0;
    border-radius: 3px;
    background: var(--c-accent);
    opacity: 0.07;
    pointer-events: none;
    transition: width 0.3s ease;
}
.table-wrap tbody tr:hover td.numeric .bar { opacity: 0.12; }

.aws-overview-card {
    transition: box-shadow 0.15s ease, border-color 0.15s ease;
}
.aws-overview-card:hover {
    box-shadow: 0 2px 8px rgba(15,23,42,0.08);
    border-color: rgba(148,163,184,0.4);
}
[data-theme="dark"] .aws-overview-card:hover {
    box-shadow: 0 2px 8px rgba(2,6,23,0.5);
    border-color: rgba(148,163,184,0.3);
}
.aws-overview-card.card-active {
    border-color: var(--c-accent);
    box-shadow: 0 0 0 1px rgba(37,99,235,0.12), var(--shadow);
}
[data-theme="dark"] .aws-overview-card.card-active {
    border-color: var(--c-accent);
    box-shadow: 0 0 0 1px rgba(96,165,250,0.15), var(--shadow);
}

button:focus-visible,
input:focus-visible,
select:focus-visible,
textarea:focus-visible {
    outline: 2px solid var(--c-accent);
    outline-offset: 2px;
}
</style>
CSS;
    echo '</head>';
    echo '<body>';
    echo '<div class="aws-shell">';
    echo '  <header class="aws-header">';
    echo '    <div class="aws-header-copy">';
    echo '      <a class="aws-back" href="/">&larr; Back to Dashboard</a>';
    echo '      <div class="aws-eyebrow">AWS Operations Console</div>';
    echo '      <h1>AWS Reports</h1>';
    echo '      <p>Run validation, cost analysis, rightsizing, security scans, and direct CLI calls from one page. Each tab keeps its own last result so you can compare reports without losing context.</p>';
    echo '    </div>';
    echo '    <div class="aws-header-actions">';
    echo '      <div class="aws-chip-row">';
    echo '        <span class="aws-chip"><strong>Project</strong>&nbsp;' . $projectTitle . '</span>';
    echo '        <span class="aws-chip"><strong>Env</strong>&nbsp;' . $envLabel . '</span>';
    echo '        <span class="aws-chip" id="envSummaryPill"></span>';
    echo '      </div>';
    echo '      <div class="aws-header-buttons">';
    echo '        <button class="ghost-link" type="button" onclick="setAwsTab(\'cli\')">AWS CLI</button>';
    echo '        <button class="theme-toggle" type="button" onclick="toggleTheme()" title="Toggle theme" aria-label="Toggle theme"><svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M21 12.79A9 9 0 1111.21 3 7 7 0 0021 12.79z"/></svg></button>';
    echo '      </div>';
    echo '    </div>';
    echo '  </header>';
    echo '  <section class="aws-overview" id="overviewGrid"></section>';
    echo '  <section class="aws-results-shell">';
    echo '    <div class="aws-tabs" id="reportTabs"></div>';
    echo '    <div class="aws-results" id="awsContent"></div>';
    echo '  </section>';
    echo '</div>';
    echo '<script>';
    echo 'const AWS_REPORTS = ' . $reportsJson . ';';
    echo 'const AWS_ENV_SUMMARY = ' . $envSummaryJson . ';';
    echo <<<'JS'
const AWS_TABS = {
    validation: { label: 'Validation', description: 'Credentials and identity check', backend: 'cli' },
    costs: { label: 'Costs', description: 'Service costs and resource inventory', backend: 'costs' },
    rightsizing: { label: 'Rightsizing', description: 'CloudWatch utilisation analysis', backend: 'rightsizing' },
    security: { label: 'Security', description: 'WAF, IAM, groups and data protection', backend: 'security' },
    cli: { label: 'AWS CLI', description: 'Wrapped CLI runner', backend: 'cli' },
};

const AWS_STATE_STORAGE_KEY = 'devex_dash_aws_reports_v2';
const awsState = {
    active: 'costs',
    running: false,
    runningTab: null,
    startedAt: 0,
    timerId: null,
    pendingCommand: '',
    results: {},
    inputs: {
        cost_preset: 'last_2_months',
        costs: { start_month: '', end_month: '' },
        rightsizing: { days: '7' },
        cli: { command: 'sts get-caller-identity' },
    },
};

function escapeHtml(value) {
    const div = document.createElement('div');
    div.textContent = value ?? '';
    return div.innerHTML;
}

function formatDuration(ms) {
    if (ms < 1000) return `${ms}ms`;
    const secs = (ms / 1000).toFixed(ms < 10000 ? 1 : 0);
    return `${secs}s`;
}

function formatElapsed(ms) {
    const totalSeconds = Math.max(0, Math.floor(ms / 1000));
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return minutes > 0 ? `${minutes}m ${String(seconds).padStart(2, '0')}s` : `${totalSeconds}s`;
}

function formatRunTimestamp(value) {
    if (!value) return 'No cached run';
    const parsed = new Date(value);
    if (Number.isNaN(parsed.getTime())) return value;
    return parsed.toLocaleString([], {
        month: 'short',
        day: 'numeric',
        hour: 'numeric',
        minute: '2-digit',
    });
}

function monthOffsetValue(offset) {
    const d = new Date();
    d.setDate(1);
    d.setMonth(d.getMonth() + offset);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

function applyCostPreset(preset) {
    awsState.inputs.cost_preset = preset;
    const monthsBack = {
        current_month: 0,
        last_1_month: 1,
        last_2_months: 2,
        last_5_months: 5,
    }[preset] ?? 2;
    awsState.inputs.costs.start_month = monthOffsetValue(-monthsBack);
    awsState.inputs.costs.end_month = monthOffsetValue(0);
}

function getElapsedMs() {
    return awsState.startedAt ? Date.now() - awsState.startedAt : 0;
}

function normalizeResult(result, fallbackLabel = 'Report') {
    return {
        label: result?.label || fallbackLabel,
        command: result?.command || '',
        exit_code: Number.isFinite(result?.exit_code) ? result.exit_code : 1,
        duration_ms: Number.isFinite(result?.duration_ms) ? result.duration_ms : 0,
        html: typeof result?.html === 'string' ? result.html : '',
        text: typeof result?.text === 'string' ? result.text : '',
        ran_at: result?.ran_at || new Date().toISOString(),
        summary: {
            headline: result?.summary?.headline || 'Completed',
            alerts: Number.isFinite(result?.summary?.alerts) ? result.summary.alerts : 0,
            warnings: Number.isFinite(result?.summary?.warnings) ? result.summary.warnings : 0,
            oks: Number.isFinite(result?.summary?.oks) ? result.summary.oks : 0,
        },
    };
}

function serializeAwsState() {
    return {
        active: awsState.active,
        inputs: awsState.inputs,
        results: awsState.results,
    };
}

function persistAwsState() {
    try {
        localStorage.setItem(AWS_STATE_STORAGE_KEY, JSON.stringify(serializeAwsState()));
    } catch (_) {}
}

function restoreAwsState() {
    try {
        const raw = localStorage.getItem(AWS_STATE_STORAGE_KEY);
        if (!raw) {
            applyCostPreset(awsState.inputs.cost_preset);
            return;
        }
        const parsed = JSON.parse(raw);
        if (parsed && typeof parsed === 'object') {
            if (typeof parsed.active === 'string' && AWS_TABS[parsed.active]) {
                awsState.active = parsed.active;
            }
            if (parsed.inputs && typeof parsed.inputs === 'object') {
                awsState.inputs = {
                    ...awsState.inputs,
                    ...parsed.inputs,
                    costs: { ...awsState.inputs.costs, ...(parsed.inputs.costs || {}) },
                    rightsizing: { ...awsState.inputs.rightsizing, ...(parsed.inputs.rightsizing || {}) },
                    cli: { ...awsState.inputs.cli, ...(parsed.inputs.cli || {}) },
                };
            }
            if (parsed.results && typeof parsed.results === 'object') {
                awsState.results = parsed.results;
            }
        }
    } catch (_) {}
    if (!awsState.inputs.costs.start_month || !awsState.inputs.costs.end_month) {
        applyCostPreset(awsState.inputs.cost_preset || 'last_2_months');
    }
}

function startRunTimer() {
    stopRunTimer();
    awsState.timerId = window.setInterval(renderAll, 1000);
}

function stopRunTimer() {
    if (awsState.timerId !== null) {
        window.clearInterval(awsState.timerId);
        awsState.timerId = null;
    }
}

function parseValidationDetails(result) {
    const details = { account: 'Unknown', arn: 'Unavailable', userId: 'Unavailable' };
    try {
        const parsed = JSON.parse(result?.text || '{}');
        if (parsed?.Account) details.account = parsed.Account;
        if (parsed?.Arn) details.arn = parsed.Arn;
        if (parsed?.UserId) details.userId = parsed.UserId;
    } catch (_) {}
    return details;
}

function parseFindingsCount(result) {
    const headline = result?.summary?.headline || '';
    const match = headline.match(/([0-9]+)/);
    if (match) return Number(match[1]);
    return (result?.summary?.alerts || 0) + (result?.summary?.warnings || 0);
}

function parseRightsizingAnalysis(result) {
    const text = result?.text || '';
    return {
        period: text.match(/Period:\s*(.+)$/mi)?.[1] || '',
        findings: parseFindingsCount(result),
        alerts: result?.summary?.alerts || 0,
        warnings: result?.summary?.warnings || 0,
        oks: result?.summary?.oks || 0,
    };
}

function parseSecurityAnalysis(result) {
    const text = result?.text || '';
    return {
        region: text.match(/Region:\s*(.+)$/mi)?.[1] || AWS_ENV_SUMMARY.region || 'Unknown',
        findings: parseFindingsCount(result),
        alerts: result?.summary?.alerts || 0,
        warnings: result?.summary?.warnings || 0,
        oks: result?.summary?.oks || 0,
    };
}

function extractReportSection(text, startHeading, endHeadings = []) {
    const lines = String(text || '').split('\n');
    const stopHeadings = new Set(endHeadings);
    let startIndex = -1;

    for (let index = 0; index < lines.length; index += 1) {
        if (lines[index].trim() === startHeading) {
            startIndex = index + 1;
            break;
        }
    }

    if (startIndex === -1) {
        return [];
    }

    const section = [];
    for (let index = startIndex; index < lines.length; index += 1) {
        const trimmed = lines[index].trim();
        if (stopHeadings.has(trimmed)) {
            break;
        }
        section.push(lines[index]);
    }

    return section;
}

function parseCostAnalysis(result) {
    const text = result?.text || '';
    const periodMatch = text.match(/Period:\s*([0-9-]+)\s*->\s*([0-9-]+)/i);
    const lines = extractReportSection(text, 'COSTS BY SERVICE', [
        'EC2 - OTHER BREAKDOWN',
        'RESOURCE INVENTORY',
        'INVENTORY SUMMARY',
    ]).map((line) => line.trimEnd()).filter(Boolean);
    const headerLine = lines.find((line) => line.includes('Service')) || '';
    const monthColumns = [...headerLine.matchAll(/\d{4}-\d{2}/g)].map((match) => match[0]);
    const totalLine = lines.find((line) => line.trimStart().startsWith('TOTAL')) || '';
    const totalValue = [...totalLine.matchAll(/\$([0-9,.]+)/g)].reduce((sum, match) => {
        const parsed = Number((match[1] || '0').replace(/,/g, ''));
        return Number.isFinite(parsed) ? sum + parsed : sum;
    }, 0);
    const rows = [];

    for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith('Service') || /^[-\u2500]+$/.test(trimmed) || trimmed.startsWith('TOTAL')) {
            continue;
        }
        const amounts = [...trimmed.matchAll(/\$[0-9,.]+/g)].map((match) => match[0].replace('$', ''));
        if (amounts.length === 0) continue;
        const name = trimmed.replace(/\$[0-9,.]+/g, '').replace(/\s{2,}/g, ' ').trim();
        if (!name) continue;
        rows.push({ name, amounts });
    }

    const inventoryLines = extractReportSection(text, 'INVENTORY SUMMARY');
    const resourceCount = inventoryLines.reduce((sum, line) => {
        if (/\$/.test(line)) return sum;
        const match = line.match(/([0-9]+)\s*$/);
        return match ? sum + Number(match[1]) : sum;
    }, 0);

    let columns = [];
    if (rows[0]) {
        if (monthColumns.length > 0 && rows[0].amounts.length === monthColumns.length + 1) {
            columns = [...monthColumns, 'Total'];
        } else if (monthColumns.length > 0 && rows[0].amounts.length === monthColumns.length) {
            columns = [...monthColumns];
        } else if (rows[0].amounts.length === 1) {
            columns = ['Amount'];
        } else {
            columns = rows[0].amounts.map((_, index) => `Value ${index + 1}`);
        }
    }

    return {
        start: periodMatch?.[1] || '',
        end: periodMatch?.[2] || '',
        total: totalLine ? totalValue.toFixed(2) : '',
        serviceCount: rows.length,
        resourceCount,
        topService: rows[0]?.name || '',
        columns,
        rows,
    };
}

function tabBadgeCount(tabId) {
    const result = awsState.results[tabId];
    if (!result) return '';
    if (tabId === 'costs') {
        const analysis = parseCostAnalysis(result);
        return analysis.serviceCount > 0 ? String(analysis.serviceCount) : '';
    }
    if (tabId === 'rightsizing' || tabId === 'security') {
        const findings = parseFindingsCount(result);
        return findings > 0 ? String(findings) : '';
    }
    return '';
}

function contentSummary(tabId, result) {
    if (!result) return AWS_TABS[tabId].description;
    if (tabId === 'validation') {
        const details = parseValidationDetails(result);
        return result.exit_code === 0 ? `Validated against account ${details.account}` : result.summary.headline;
    }
    if (tabId === 'costs') {
        const analysis = parseCostAnalysis(result);
        if (analysis.total) {
            return `${analysis.start} to ${analysis.end} | ${analysis.serviceCount} services, $${analysis.total} total`;
        }
    }
    if (tabId === 'rightsizing') {
        const analysis = parseRightsizingAnalysis(result);
        return `${analysis.period || 'Utilisation review'} | ${analysis.findings} findings`;
    }
    if (tabId === 'security') {
        const analysis = parseSecurityAnalysis(result);
        return `${analysis.region} | ${analysis.findings} findings`;
    }
    return result.summary.headline;
}

function buildOutputShell(result) {
    return `
        <div class="aws-output-shell">
            <div class="shell-header">
                <code>${escapeHtml(result.command || '')}</code>
                <span class="shell-meta">${escapeHtml(result.ran_at || '')}</span>
            </div>
            <div class="shell-output">${result.html || '<span class="ansi-dim">No output captured.</span>'}</div>
        </div>
    `;
}

function buildValidationBody(result) {
    const details = parseValidationDetails(result || {});
    const statusLabel = result ? (result.exit_code === 0 ? 'Validated successfully' : 'Validation failed') : 'Not yet validated';
    return `
        <div class="summary-grid">
            <div class="summary-card ${result && result.exit_code === 0 ? 'good' : result ? 'bad' : ''}">
                <strong>Status</strong>
                <span>${escapeHtml(statusLabel)}</span>
            </div>
            <div class="summary-card">
                <strong>AWS Region</strong>
                <span>${escapeHtml(AWS_ENV_SUMMARY.region)}</span>
            </div>
            <div class="summary-card ${AWS_ENV_SUMMARY.has_env_file ? 'good' : 'bad'}">
                <strong>.env File</strong>
                <span>${AWS_ENV_SUMMARY.has_env_file ? 'Present' : 'Missing'}</span>
            </div>
            <div class="summary-card ${AWS_ENV_SUMMARY.has_secret ? 'good' : 'bad'}">
                <strong>Secret Key</strong>
                <span>${AWS_ENV_SUMMARY.has_secret ? 'Configured' : 'Missing'}</span>
            </div>
        </div>
        <div class="identity-grid">
            <div class="identity-card"><strong>Access Key</strong><code>${escapeHtml(AWS_ENV_SUMMARY.access_key_preview)}</code></div>
            <div class="identity-card"><strong>Account</strong><code>${escapeHtml(details.account)}</code></div>
            <div class="identity-card"><strong>ARN</strong><span>${escapeHtml(details.arn)}</span></div>
            <div class="identity-card"><strong>User ID</strong><code>${escapeHtml(details.userId)}</code></div>
        </div>
        ${result ? buildOutputShell(result) : ''}
    `;
}

function buildCostBody(result) {
    const analysis = parseCostAnalysis(result);
    if (!analysis.rows.length) {
        return `
            <div class="summary-grid">
                <div class="summary-card">
                    <strong>Status</strong>
                    <span>${escapeHtml(result.summary.headline)}</span>
                </div>
                <div class="summary-card">
                    <strong>Duration</strong>
                    <span>${formatDuration(result.duration_ms)}</span>
                </div>
            </div>
            ${buildOutputShell(result)}
        `;
    }

    const headerCopy = analysis.start && analysis.end
        ? `${analysis.start} to ${analysis.end} | ${analysis.serviceCount} services, $${analysis.total || '0.00'} total`
        : `${analysis.serviceCount} services, $${analysis.total || '0.00'} total`;
    const headCells = analysis.columns.map((column) => `<th class="numeric">${escapeHtml(column)}</th>`).join('');
    const columnMaxes = analysis.columns.map((_, ci) =>
        Math.max(...analysis.rows.map(r => { const v = parseFloat((r.amounts[ci] || '0').replace(/,/g, '')); return isNaN(v) ? 0 : v; }))
    );
    const rowsHtml = analysis.rows.map((row) => `
        <tr>
            <td>${escapeHtml(row.name)}</td>
            ${row.amounts.map((amount, ci) => {
                const numVal = parseFloat((amount || '0').replace(/,/g, ''));
                const max = columnMaxes[ci] || 1;
                const pct = Math.round((isNaN(numVal) ? 0 : numVal) / max * 100);
                return `<td class="numeric"><span class="bar" style="width:${pct}%"></span>$${escapeHtml(amount)}</td>`;
            }).join('')}
        </tr>
    `).join('');

    return `
        <div class="aws-panel">
            <div class="panel-head">
                <h3>Snapshot</h3>
                <span>${escapeHtml(headerCopy)}</span>
            </div>
            <div class="summary-grid">
                <div class="summary-card hero"><strong>Total Cost</strong><span>$${escapeHtml(analysis.total || '0.00')}</span></div>
                <div class="summary-card"><strong>Services</strong><span>${analysis.serviceCount}</span></div>
                <div class="summary-card"><strong>Resources</strong><span>${analysis.resourceCount}</span></div>
                <div class="summary-card"><strong>Top Service</strong><span>${escapeHtml(analysis.topService || 'N/A')}</span></div>
            </div>
        </div>
        <div class="aws-table-shell">
            <div class="table-head">
                <h3>Service Breakdown</h3>
                <span>${escapeHtml(formatRunTimestamp(result.ran_at))}</span>
            </div>
            <div class="table-wrap">
                <table>
                    <thead>
                        <tr>
                            <th>Service</th>
                            ${headCells}
                        </tr>
                    </thead>
                    <tbody>${rowsHtml}</tbody>
                </table>
            </div>
        </div>
        ${buildOutputShell(result)}
    `;
}

function buildFindingsBody(result, analysis, label) {
    return `
        <div class="summary-grid">
            <div class="summary-card"><strong>${label}</strong><span class="summary-value-text">${escapeHtml(label === 'Region' ? analysis.region : analysis.period || 'Unknown')}</span></div>
            <div class="summary-card ${analysis.findings > 0 ? 'bad' : 'good'}"><strong>Findings</strong><span>${analysis.findings}</span></div>
            <div class="summary-card ${analysis.alerts > 0 ? 'bad' : 'good'}"><strong>Alerts</strong><span>${analysis.alerts}</span></div>
            <div class="summary-card ${analysis.warnings > 0 ? 'warn' : ''}"><strong>Warnings</strong><span>${analysis.warnings}</span></div>
            <div class="summary-card good"><strong>Checks OK</strong><span>${analysis.oks}</span></div>
            <div class="summary-card"><strong>Duration</strong><span>${formatDuration(result.duration_ms)}</span></div>
        </div>
        ${buildOutputShell(result)}
    `;
}

function buildCliBody(result) {
    return `
        <div class="summary-grid">
            <div class="summary-card"><strong>Status</strong><span>${escapeHtml(result.summary.headline)}</span></div>
            <div class="summary-card ${result.exit_code === 0 ? 'good' : 'bad'}"><strong>Exit Code</strong><span>${result.exit_code}</span></div>
            <div class="summary-card"><strong>Duration</strong><span>${formatDuration(result.duration_ms)}</span></div>
            <div class="summary-card"><strong>Last Run</strong><span>${escapeHtml(formatRunTimestamp(result.ran_at))}</span></div>
        </div>
        ${buildOutputShell(result)}
    `;
}

function buildInlineControls(tabId) {
    if (tabId === 'validation') {
        return `
            <div class="aws-panel">
                <div class="panel-head">
                    <h3>Credential Check</h3>
                    <span>${AWS_ENV_SUMMARY.saved_at ? `Saved: ${escapeHtml(AWS_ENV_SUMMARY.saved_at)}` : 'No .env file detected'}</span>
                </div>
                <div class="inline-row">
                    <button class="card-button primary" type="button" onclick="runValidation()" ${awsState.running ? 'disabled' : ''}>Validate Credentials</button>
                    <span class="helper-copy">Runs <code>sts get-caller-identity</code> through the wrapped AWS CLI.</span>
                </div>
            </div>
        `;
    }
    if (tabId === 'costs') {
        return `
            <div class="aws-panel">
                <div class="panel-head">
                    <h3>Period</h3>
                    <span>Use presets above or fine-tune the month range here.</span>
                </div>
                <div class="control-grid">
                    <div>
                        <label class="field-label" for="costStartMonth">Start Month</label>
                        <input class="field-input" id="costStartMonth" type="month" value="${escapeHtml(awsState.inputs.costs.start_month)}" onchange="setCostMonthRange()" />
                    </div>
                    <div>
                        <label class="field-label" for="costEndMonth">End Month</label>
                        <input class="field-input" id="costEndMonth" type="month" value="${escapeHtml(awsState.inputs.costs.end_month)}" onchange="setCostMonthRange()" />
                    </div>
                    <div>
                        <label class="field-label">&nbsp;</label>
                        <button class="card-button primary" type="button" onclick="runCosts()" ${awsState.running ? 'disabled' : ''}>Analyze Costs</button>
                    </div>
                </div>
            </div>
        `;
    }
    if (tabId === 'rightsizing') {
        return `
            <div class="aws-panel">
                <div class="panel-head">
                    <h3>Lookback Period</h3>
                    <span>Longer windows smooth spikes but take longer to fetch.</span>
                </div>
                <div class="inline-row">
                    <select class="field-select" id="rightsizingDays" onchange="setRightsizingDays(this.value)">
                        <option value="7" ${awsState.inputs.rightsizing.days === '7' ? 'selected' : ''}>Last 7 days</option>
                        <option value="14" ${awsState.inputs.rightsizing.days === '14' ? 'selected' : ''}>Last 14 days</option>
                        <option value="30" ${awsState.inputs.rightsizing.days === '30' ? 'selected' : ''}>Last 30 days</option>
                        <option value="60" ${awsState.inputs.rightsizing.days === '60' ? 'selected' : ''}>Last 60 days</option>
                    </select>
                    <button class="card-button primary" type="button" onclick="runRightsizing()" ${awsState.running ? 'disabled' : ''}>Analyze Rightsizing</button>
                </div>
            </div>
        `;
    }
    if (tabId === 'security') {
        return `
            <div class="aws-panel">
                <div class="panel-head">
                    <h3>Read-Only Scan</h3>
                    <span>Checks WAF rules, IAM users, security groups, S3 access blocks and secrets rotation.</span>
                </div>
                <div class="inline-row">
                    <button class="card-button primary" type="button" onclick="runSecurity()" ${awsState.running ? 'disabled' : ''}>Run Security Scan</button>
                </div>
            </div>
        `;
    }
    return `
        <div class="aws-panel">
            <div class="panel-head">
                <h3>AWS CLI</h3>
                <span>Run wrapped AWS CLI or Terraform commands with the shared auth loader.</span>
            </div>
            <div class="control-stack">
                <div>
                    <label class="field-label" for="awsCliCommand">Command</label>
                    <textarea class="field-textarea" id="awsCliCommand" spellcheck="false" oninput="setAwsCliCommand(this.value)">${escapeHtml(awsState.inputs.cli.command)}</textarea>
                    <div class="helper-copy">Enter the AWS subcommand only, for example <code>sts get-caller-identity</code> or <code>terraform version</code>.</div>
                </div>
                <div class="quick-actions">
                    <button class="chip" type="button" onclick="setAwsCliCommand('sts get-caller-identity'); renderAll()">Identity</button>
                    <button class="chip" type="button" onclick="setAwsCliCommand('s3 ls'); renderAll()">Buckets</button>
                    <button class="chip" type="button" onclick="setAwsCliCommand('ec2 describe-regions --all-regions'); renderAll()">Regions</button>
                    <button class="chip" type="button" onclick="setAwsCliCommand('terraform version'); renderAll()">Terraform</button>
                </div>
                <div>
                    <button class="card-button primary" type="button" onclick="runCli()" ${awsState.running ? 'disabled' : ''}>Run CLI Command</button>
                </div>
            </div>
        </div>
    `;
}

function buildContentBody(tabId, result) {
    if (!result) {
        return `
            <div class="empty-state">
                <p>No output yet for <strong>${escapeHtml(AWS_TABS[tabId].label)}</strong>.</p>
                <p style="margin-top:8px">Use the card above or the inline controls to run this report.</p>
            </div>
        `;
    }
    if (tabId === 'validation') return buildValidationBody(result);
    if (tabId === 'costs') return buildCostBody(result);
    if (tabId === 'rightsizing') return buildFindingsBody(result, parseRightsizingAnalysis(result), 'Window');
    if (tabId === 'security') return buildFindingsBody(result, parseSecurityAnalysis(result), 'Region');
    return buildCliBody(result);
}

function renderOverview() {
    const validationResult = awsState.results.validation ? normalizeResult(awsState.results.validation, 'Validation') : null;
    const costsResult = awsState.results.costs ? normalizeResult(awsState.results.costs, 'Costs') : null;
    const rightsizingResult = awsState.results.rightsizing ? normalizeResult(awsState.results.rightsizing, 'Rightsizing') : null;
    const securityResult = awsState.results.security ? normalizeResult(awsState.results.security, 'Security') : null;

    document.getElementById('envSummaryPill').className = `aws-chip ${AWS_ENV_SUMMARY.has_env_file ? 'good' : 'bad'}`;
    document.getElementById('envSummaryPill').textContent = AWS_ENV_SUMMARY.has_env_file ? '.env present' : '.env missing';

    document.getElementById('overviewGrid').innerHTML = `
        <article class="aws-overview-card ${awsState.active === 'validation' ? 'card-active' : ''}">
            <div class="aws-card-header">
                <div class="aws-card-title">
                    <h2>Credentials</h2>
                    <p>Enter and validate AWS access keys.</p>
                </div>
                <div class="aws-card-icon">K</div>
            </div>
            <div class="aws-card-body">
                <div class="inline-row">
                    <button class="card-button" type="button" onclick="setAwsTab('validation')">Open</button>
                    <button class="card-button primary" type="button" onclick="runValidation()" ${awsState.running ? 'disabled' : ''}>Validate</button>
                </div>
                <div class="card-footnote">${validationResult ? escapeHtml(contentSummary('validation', validationResult)) : `Saved: ${escapeHtml(AWS_ENV_SUMMARY.saved_at || 'Not saved yet')}`}</div>
            </div>
        </article>

        <article class="aws-overview-card ${awsState.active === 'costs' ? 'card-active' : ''}">
            <div class="aws-card-header">
                <div class="aws-card-title">
                    <h2>Cost Analysis</h2>
                    <p>Service costs, resource inventory and spend overview.</p>
                </div>
                <div class="aws-card-icon">$</div>
            </div>
            <div class="aws-card-body">
                <label class="field-label" for="overviewCostPreset">Period</label>
                <div class="inline-row">
                    <select class="field-select" id="overviewCostPreset" onchange="setCostPreset(this.value)">
                        <option value="current_month" ${awsState.inputs.cost_preset === 'current_month' ? 'selected' : ''}>Current month</option>
                        <option value="last_1_month" ${awsState.inputs.cost_preset === 'last_1_month' ? 'selected' : ''}>Last 1 month</option>
                        <option value="last_2_months" ${awsState.inputs.cost_preset === 'last_2_months' ? 'selected' : ''}>Last 2 months</option>
                        <option value="last_5_months" ${awsState.inputs.cost_preset === 'last_5_months' ? 'selected' : ''}>Last 5 months</option>
                    </select>
                    <button class="card-button primary" type="button" onclick="runCosts()" ${awsState.running ? 'disabled' : ''}>Analyze</button>
                </div>
                <div class="card-footnote">${costsResult ? escapeHtml(contentSummary('costs', costsResult)) : 'Queries Cost Explorer and enumerates infrastructure.'}</div>
            </div>
        </article>

        <article class="aws-overview-card ${awsState.active === 'rightsizing' ? 'card-active' : ''}">
            <div class="aws-card-header">
                <div class="aws-card-title">
                    <h2>Rightsizing</h2>
                    <p>CloudWatch metrics and utilisation analysis.</p>
                </div>
                <div class="aws-card-icon">R</div>
            </div>
            <div class="aws-card-body">
                <label class="field-label" for="overviewRightsizingDays">Lookback Period</label>
                <div class="inline-row">
                    <select class="field-select" id="overviewRightsizingDays" onchange="setRightsizingDays(this.value)">
                        <option value="7" ${awsState.inputs.rightsizing.days === '7' ? 'selected' : ''}>Last 7 days</option>
                        <option value="14" ${awsState.inputs.rightsizing.days === '14' ? 'selected' : ''}>Last 14 days</option>
                        <option value="30" ${awsState.inputs.rightsizing.days === '30' ? 'selected' : ''}>Last 30 days</option>
                        <option value="60" ${awsState.inputs.rightsizing.days === '60' ? 'selected' : ''}>Last 60 days</option>
                    </select>
                    <button class="card-button primary" type="button" onclick="runRightsizing()" ${awsState.running ? 'disabled' : ''}>Analyze</button>
                </div>
                <div class="card-footnote">${rightsizingResult ? escapeHtml(contentSummary('rightsizing', rightsizingResult)) : 'Fetches CloudWatch metrics for RDS, ECS, ALB, NAT, EC2 and logs.'}</div>
            </div>
        </article>

        <article class="aws-overview-card ${awsState.active === 'security' ? 'card-active' : ''}">
            <div class="aws-card-header">
                <div class="aws-card-title">
                    <h2>Security</h2>
                    <p>WAF, IAM, security groups and data protection.</p>
                </div>
                <div class="aws-card-icon">S</div>
            </div>
            <div class="aws-card-body">
                <label class="field-label">Run Scan</label>
                <div class="inline-row">
                    <button class="card-button" type="button" onclick="setAwsTab('security')">Open</button>
                    <button class="card-button primary" type="button" onclick="runSecurity()" ${awsState.running ? 'disabled' : ''}>Scan</button>
                </div>
                <div class="card-footnote">${securityResult ? escapeHtml(contentSummary('security', securityResult)) : 'Checks WAF rules, IAM users, security groups, S3 blocks and secrets rotation.'}</div>
            </div>
        </article>
    `;
}

function renderTabs() {
    document.getElementById('reportTabs').innerHTML = Object.keys(AWS_TABS).map((tabId) => {
        const badge = tabBadgeCount(tabId);
        const isRunning = awsState.running && awsState.runningTab === tabId;
        return `
            <button class="tab-btn ${awsState.active === tabId ? 'active' : ''} ${isRunning ? 'running' : ''}" type="button" onclick="setAwsTab('${tabId}')">
                <span>${escapeHtml(AWS_TABS[tabId].label)}</span>
                ${badge ? `<span class="tab-badge">${escapeHtml(badge)}</span>` : ''}
            </button>
        `;
    }).join('');
}

function renderContent() {
    const tabId = awsState.active;
    const result = awsState.results[tabId] ? normalizeResult(awsState.results[tabId], AWS_TABS[tabId].label) : null;
    const isRunningHere = awsState.running && awsState.runningTab === tabId;
    const runningLabel = awsState.running && awsState.runningTab ? AWS_TABS[awsState.runningTab].label : '';
    const runBanner = awsState.running ? `
        <div class="run-banner">
            <div class="run-banner-copy">
                <span class="spinner"></span>
                <div class="run-banner-text">
                    <strong>${isRunningHere ? `Running ${escapeHtml(AWS_TABS[tabId].label)}` : `${escapeHtml(runningLabel)} is running in the background`}</strong>
                    <span>${escapeHtml(awsState.pendingCommand || 'Preparing command')}</span>
                </div>
            </div>
            <div class="run-banner-time">${formatElapsed(getElapsedMs())}</div>
        </div>
    ` : '';

    const lastRunLine = !awsState.running && result ? `
        <div style="display:flex;align-items:center;gap:8px;margin-bottom:12px;font-size:11px;color:var(--c-text-faint)">
            <span class="status-badge ${result.exit_code === 0 ? 'success' : 'error'}">
                <span class="dot"></span>
                ${result.exit_code === 0 ? 'Completed' : 'Failed'}
            </span>
            <span style="font-family:var(--font-mono)">${escapeHtml(result.command || '')}</span>
            <span>\u00b7</span>
            <span>${formatDuration(result.duration_ms)}</span>
            <span>\u00b7</span>
            <span>${escapeHtml(formatRunTimestamp(result.ran_at))}</span>
        </div>
    ` : '';

    document.getElementById('awsContent').innerHTML = `
        <div class="results-toolbar">
            <div>
                <h2>${escapeHtml(AWS_TABS[tabId].label)}</h2>
                <p>${escapeHtml(contentSummary(tabId, result))}</p>
            </div>
            <div class="toolbar-actions">
                ${result ? '<button class="action-btn" type="button" onclick="copyActiveResultJson()">Copy JSON</button>' : ''}
                ${result ? '<button class="action-btn" type="button" onclick="exportActiveResultHtml()">Export HTML</button>' : ''}
            </div>
        </div>
        ${buildInlineControls(tabId)}
        ${runBanner}
        ${lastRunLine}
        ${buildContentBody(tabId, result)}
    `;
}

function renderAll() {
    renderOverview();
    renderTabs();
    renderContent();
}

function setAwsTab(tabId) {
    awsState.active = tabId;
    persistAwsState();
    renderAll();
}

function setCostPreset(value) {
    applyCostPreset(value);
    persistAwsState();
    renderAll();
}

function setCostMonthRange() {
    const start = document.getElementById('costStartMonth');
    const end = document.getElementById('costEndMonth');
    if (start) {
        awsState.inputs.costs.start_month = start.value;
    }
    if (end) {
        awsState.inputs.costs.end_month = end.value;
    }
    persistAwsState();
}

function setRightsizingDays(value) {
    awsState.inputs.rightsizing.days = value || '7';
    persistAwsState();
    renderAll();
}

function setAwsCliCommand(command) {
    awsState.inputs.cli.command = command;
    persistAwsState();
}

async function executeAwsRequest(tabId, backendReport, payload, pendingCommand) {
    if (awsState.running) return;

    awsState.active = tabId;
    awsState.running = true;
    awsState.runningTab = tabId;
    awsState.startedAt = Date.now();
    awsState.pendingCommand = pendingCommand;
    startRunTimer();
    renderAll();

    try {
        const response = await fetch('/api/aws/run', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ report: backendReport, ...payload }),
        });
        const data = await response.json();
        if (!response.ok && !data.html) {
            throw new Error(data.error || 'AWS request failed');
        }
        awsState.results[tabId] = normalizeResult(data, AWS_TABS[tabId].label);
        persistAwsState();
    } catch (error) {
        awsState.results[tabId] = normalizeResult({
            label: AWS_TABS[tabId].label,
            command: pendingCommand,
            exit_code: 1,
            duration_ms: 0,
            ran_at: new Date().toISOString(),
            html: `<span class="ansi-red ansi-bold">Error:</span> ${escapeHtml(String(error))}`,
            text: String(error),
            summary: { headline: 'Request failed', alerts: 1, warnings: 0, oks: 0 },
        }, AWS_TABS[tabId].label);
        persistAwsState();
    } finally {
        awsState.running = false;
        awsState.runningTab = null;
        awsState.startedAt = 0;
        awsState.pendingCommand = '';
        stopRunTimer();
        persistAwsState();
        renderAll();
    }
}

function runValidation() {
    executeAwsRequest('validation', 'cli', { command: 'sts get-caller-identity' }, 'aws sts get-caller-identity');
}

function runCosts() {
    setCostMonthRange();
    executeAwsRequest('costs', 'costs', { ...awsState.inputs.costs }, `bash ${AWS_REPORTS.costs.script}`);
}

function runRightsizing() {
    executeAwsRequest('rightsizing', 'rightsizing', { days: awsState.inputs.rightsizing.days }, `bash ${AWS_REPORTS.rightsizing.script} --days ${awsState.inputs.rightsizing.days}`);
}

function runSecurity() {
    executeAwsRequest('security', 'security', {}, `bash ${AWS_REPORTS.security.script}`);
}

function runCli() {
    const textarea = document.getElementById('awsCliCommand');
    awsState.inputs.cli.command = textarea ? textarea.value : awsState.inputs.cli.command;
    persistAwsState();
    executeAwsRequest('cli', 'cli', { command: awsState.inputs.cli.command }, `aws ${awsState.inputs.cli.command}`);
}

function copyActiveResultJson() {
    const result = awsState.results[awsState.active];
    if (!result) return;
    navigator.clipboard.writeText(JSON.stringify(result, null, 2));
}

function exportActiveResultHtml() {
    const result = awsState.results[awsState.active];
    if (!result) return;
    const html = `<!DOCTYPE html><html><head><meta charset="UTF-8"><title>${escapeHtml(AWS_TABS[awsState.active].label)}</title></head><body style="font-family:IBM Plex Sans,Arial,sans-serif;padding:24px;background:#f8fafc;color:#111827"><h1>${escapeHtml(AWS_TABS[awsState.active].label)}</h1><p>${escapeHtml(contentSummary(awsState.active, result))}</p><div>${result.html}</div></body></html>`;
    const blob = new Blob([html], { type: 'text/html;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = `aws-${awsState.active}-report.html`;
    anchor.click();
    URL.revokeObjectURL(url);
}

function toggleTheme() {
    const next = document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', next);
    localStorage.setItem('devex_dash_theme', next);
}

restoreAwsState();
renderAll();
JS;
    echo '</script>';
    echo '</body>';
    echo '</html>';
}
