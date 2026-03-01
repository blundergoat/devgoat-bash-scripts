<?php

/**
 * Frontend (HTML/CSS/JS)
 *
 * Renders the entire single-page dashboard as inline HTML/CSS/JS.
 * No external files or build step - everything is emitted by this function.
 *
 * Layout:
 *   Header     - project title, logo, project selector, env badge, theme toggle
 *   Sidebar    - categorized script buttons loaded from config.php
 *   Terminal   - ANSI-colored output streamed via SSE from /api/stream/{id}
 *   Modal      - confirmation dialogs and prompt inputs before running scripts
 *
 * Theme: light/dark toggle persisted in localStorage ('devex_dash_theme').
 * Project: target directory persisted in localStorage ('devex_dash_project').
 */

/**
 * @return void
 */
function serveDashboardHtml(): void
{
    header('Content-Type: text/html; charset=UTF-8');
    $env = htmlspecialchars(ENV_NAME, ENT_QUOTES);
    $projectTitle = htmlspecialchars(PROJECT_NAME, ENT_QUOTES);

    // Accent color: neutral indigo default, configurable via DASHBOARD_ACCENT env var (hex)
    $accent = getenv('DASHBOARD_ACCENT') ?: '#818cf8';
    $accentHover = '#6366f1';
    $colors = [
        'accent' => $accent, 'accent_hover' => $accentHover,
        'dark'  => ['badge_bg' => 'rgba(129,140,248,0.15)', 'badge_border' => 'rgba(129,140,248,0.4)',  'badge_text' => '#a5b4fc'],
        'light' => ['badge_bg' => 'rgba(99,102,241,0.12)',  'badge_border' => 'rgba(99,102,241,0.35)',  'badge_text' => '#4f46e5'],
    ];
    $dark   = $colors['dark'];
    $light  = $colors['light'];

    echo '<!DOCTYPE html>';
    echo '<html lang="en" data-theme="light">';
    echo '<head>';
    echo '<meta charset="UTF-8">';
    echo '<meta name="viewport" content="width=device-width, initial-scale=1.0">';
    echo '<title>' . $env . ' — ' . $projectTitle . '</title>';
    echo '<link rel="icon" href="data:image/svg+xml,<svg xmlns=\'http://www.w3.org/2000/svg\' viewBox=\'0 0 100 100\'><text y=\'.9em\' font-size=\'90\'>&#x2699;&#xfe0f;</text></svg>">';
    echo '<script>document.documentElement.setAttribute("data-theme", localStorage.getItem("devex_dash_theme") || "light");</script>';
    echo '<link rel="preconnect" href="https://fonts.googleapis.com">';
    echo '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>';
    echo '<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">';

    echo '<style>';
    echo '* { box-sizing: border-box; margin: 0; padding: 0; }';
    echo 'body { font-family: "Inter", "Segoe UI", "Helvetica Neue", Arial, sans-serif; }';
    echo ':root, [data-theme="light"] {';
    echo '  --c-bg: #f2f3f5; --c-surface: #ffffff; --c-surface-hover: #f0f0f2;';
    echo '  --c-text-primary: #313338; --c-text-secondary: #4e5058; --c-text-muted: #5c6470; --c-text-faint: #80848e;';
    echo '  --c-border: rgba(0,0,0,0.08); --c-scrollbar: rgba(0,0,0,0.12);';
    echo '  --c-accent: ' . $colors['accent_hover'] . '; --c-accent-hover: ' . $colors['accent'] . ';';
    echo '  --c-badge-bg: ' . $light['badge_bg'] . '; --c-badge-border: ' . $light['badge_border'] . '; --c-badge-text: ' . $light['badge_text'] . ';';
    echo '  --c-green: #16a34a; --c-red: #dc2626; --c-yellow: #ca8a04;';
    echo '  --c-terminal-bg: #f8f8f8;';
    echo '}';
    echo '[data-theme="dark"] {';
    echo '  --c-bg: #1e1f22; --c-surface: #2b2d31; --c-surface-hover: #383a40;';
    echo '  --c-text-primary: #dbdee1; --c-text-secondary: #b5bac1; --c-text-muted: #949ba4; --c-text-faint: #6d6f78;';
    echo '  --c-border: rgba(255,255,255,0.06); --c-scrollbar: rgba(255,255,255,0.1);';
    echo '  --c-accent: ' . $colors['accent'] . '; --c-accent-hover: ' . $colors['accent_hover'] . ';';
    echo '  --c-badge-bg: ' . $dark['badge_bg'] . '; --c-badge-border: ' . $dark['badge_border'] . '; --c-badge-text: ' . $dark['badge_text'] . ';';
    echo '  --c-green: #a6e3a1; --c-red: #f38ba8; --c-yellow: #f9e2af;';
    echo '  --c-terminal-bg: #1a1b1e;';
    echo '}';
    echo <<<'CSS'

html, body { height: 100%; }
body { background: var(--c-bg); color: var(--c-text-primary); display: flex; flex-direction: column; height: 100vh; overflow: hidden; }

::-webkit-scrollbar { width: 6px; }
::-webkit-scrollbar-thumb { background: var(--c-scrollbar); border-radius: 3px; }

/* -- Header ------------------------------------------ */
.header {
    display: flex; align-items: center; justify-content: space-between;
    padding: 0 20px; height: 56px; flex-shrink: 0;
    background: var(--c-surface); border-bottom: 1px solid var(--c-border);
}
.header-left { display: flex; align-items: center; gap: 12px; }
.header-left h1 { font-size: 16px; font-weight: 700; letter-spacing: -0.01em; color: var(--c-text-primary); }
.header-logo { width: 28px; height: 28px; border-radius: 50%; object-fit: cover; flex-shrink: 0; box-shadow: 0 0 0 2px rgba(129,140,248,0.4); }
.header-right { display: flex; align-items: center; gap: 10px; }

.site-link {
    font-size: 12px; font-weight: 500; color: var(--c-text-muted);
    text-decoration: none; padding: 5px 12px; border-radius: 6px;
    border: 1px solid var(--c-border); transition: all 0.15s;
}
.site-link:hover { color: var(--c-text-primary); border-color: var(--c-accent); background: var(--c-surface-hover); }

.env-badge {
    display: inline-flex; align-items: center; gap: 6px;
    font-size: 14px; font-weight: 700; letter-spacing: 0.02em;
    padding: 5px 14px; border-radius: 8px;
    background: var(--c-badge-bg); border: 1.5px solid var(--c-badge-border); color: var(--c-badge-text);
}
.env-badge .dot {
    width: 8px; height: 8px; border-radius: 50%;
    background: var(--c-accent); flex-shrink: 0;
}

.theme-toggle {
    background: none; border: none; cursor: pointer; padding: 6px; border-radius: 8px;
    color: var(--c-text-muted); transition: all 0.2s;
}
.theme-toggle:hover { color: var(--c-text-primary); background: var(--c-surface-hover); }
.hidden { display: none; }

/* -- Project Selector -------------------------------- */
.project-selector {
    display: flex; align-items: center; gap: 6px; position: relative;
}
.project-selector select {
    appearance: none; -webkit-appearance: none;
    padding: 5px 28px 5px 10px; font-size: 12px; font-weight: 500; font-family: 'JetBrains Mono', monospace;
    background: var(--c-bg); color: var(--c-text-primary);
    border: 1px solid var(--c-border); border-radius: 6px;
    cursor: pointer; max-width: 220px; outline: none; transition: border-color 0.15s;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='%236d6f78' stroke-width='2'%3E%3Cpath d='M6 9l6 6 6-6'/%3E%3C/svg%3E");
    background-repeat: no-repeat; background-position: right 8px center;
}
.project-selector select:focus { border-color: var(--c-accent); }
.project-selector select:hover { border-color: var(--c-accent); }
.project-custom-input {
    padding: 5px 10px; font-size: 12px; font-weight: 500; font-family: 'JetBrains Mono', monospace;
    background: var(--c-bg); color: var(--c-text-primary);
    border: 1px solid var(--c-border); border-radius: 6px;
    width: 260px; outline: none; transition: border-color 0.15s;
}
.project-custom-input:focus { border-color: var(--c-accent); }
.project-custom-input.invalid { border-color: var(--c-red); }
.project-badge {
    font-size: 11px; font-weight: 600; color: var(--c-accent);
    padding: 3px 8px; border-radius: 4px;
    background: var(--c-badge-bg); white-space: nowrap;
}
.project-label {
    font-size: 11px; font-weight: 600; color: var(--c-text-faint);
    text-transform: uppercase; letter-spacing: 0.04em; white-space: nowrap;
}

/* -- Layout ------------------------------------------ */
.layout { display: flex; flex: 1; overflow: hidden; }

/* -- Sidebar ----------------------------------------- */
.sidebar-wrapper {
    width: 272px; min-width: 272px; flex-shrink: 0;
    display: flex; flex-direction: column;
    background: var(--c-surface); border-right: 1px solid var(--c-border);
}
.sidebar {
    flex: 1; overflow-y: auto; padding: 12px 0;
}
.sidebar-footer {
    padding: 8px 0; text-align: center; border-top: 1px solid var(--c-border);
}
.sidebar-footer a {
    font-size: 10px; color: var(--c-text-faint); text-decoration: none;
}
.sidebar-footer a:hover { text-decoration: underline; }

.category { margin-bottom: 2px; }
.category-header {
    display: flex; align-items: center; gap: 6px;
    padding: 8px 16px; cursor: pointer; user-select: none;
    font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.06em;
    color: var(--c-text-faint); transition: color 0.15s;
}
.category-header:hover { color: var(--c-text-secondary); }
.category-header .arrow {
    font-size: 10px; transition: transform 0.15s; display: inline-block; width: 12px;
}
.category.collapsed .arrow { transform: rotate(-90deg); }
.category.collapsed .category-scripts { display: none; }

.script-btn {
    display: flex; align-items: flex-start; gap: 10px;
    width: calc(100% - 20px); margin: 1px 10px; padding: 8px 12px;
    font-size: 13px; font-family: inherit; font-weight: 500;
    text-align: left; text-decoration: none;
    background: transparent; color: var(--c-text-primary);
    border: 1px solid transparent; border-radius: 8px;
    cursor: pointer; transition: all 0.15s; position: relative;
}
.script-btn:hover { background: var(--c-surface-hover); border-color: var(--c-border); }
.script-btn:active { transform: scale(0.98); }
.script-btn.running {
    background: var(--c-badge-bg); border-color: var(--c-badge-border);
    animation: pulse 2s ease-in-out infinite;
}
.script-btn:disabled { opacity: 0.35; cursor: not-allowed; pointer-events: none; }
.script-btn .s-name { line-height: 1.3; }
.script-btn .s-desc {
    display: block; font-size: 11px; font-weight: 400; color: var(--c-text-faint);
    margin-top: 1px; line-height: 1.3;
}

@keyframes pulse {
    0%, 100% { border-color: var(--c-badge-border); }
    50% { border-color: transparent; }
}

/* -- Terminal panel ---------------------------------- */
.terminal-wrapper { flex: 1; display: flex; flex-direction: column; overflow: hidden; }

.terminal-toolbar {
    display: flex; align-items: center; gap: 10px;
    padding: 10px 16px; flex-shrink: 0;
    background: var(--c-surface); border-bottom: 1px solid var(--c-border);
}
.script-label {
    flex: 1; font-size: 13px; font-weight: 500;
    font-family: 'JetBrains Mono', monospace; color: var(--c-text-muted);
}
.script-label strong { color: var(--c-green); font-weight: 600; }

.toolbar-btn {
    padding: 5px 14px; font-size: 12px; font-weight: 600;
    font-family: 'Inter', sans-serif;
    border: 1px solid var(--c-border); border-radius: 6px;
    cursor: pointer; transition: all 0.15s;
    background: var(--c-surface-hover); color: var(--c-text-secondary);
}
.toolbar-btn:hover { background: var(--c-bg); color: var(--c-text-primary); }
.toolbar-btn.stop { background: rgba(243,139,168,0.12); border-color: var(--c-red); color: var(--c-red); }
.toolbar-btn.stop:hover { background: rgba(243,139,168,0.25); }
.toolbar-btn:disabled { opacity: 0.25; cursor: not-allowed; }

.terminal {
    flex: 1; overflow-y: auto; padding: 16px 20px;
    font-family: 'JetBrains Mono', 'SF Mono', Consolas, monospace;
    font-size: 13px; line-height: 1.6;
    white-space: pre-wrap; word-break: break-word;
    background: var(--c-terminal-bg);
}
.terminal .welcome { color: var(--c-text-faint); font-style: italic; }

/* -- ANSI colors ------------------------------------- */
.ansi-bold { font-weight: 700; }
.ansi-dim { opacity: 0.55; }
.ansi-black { color: #585b70; }
.ansi-red { color: var(--c-red); }
.ansi-green { color: var(--c-green); }
.ansi-yellow { color: var(--c-yellow); }
.ansi-blue { color: #89b4fa; }
.ansi-magenta { color: #cba6f7; }
.ansi-cyan { color: #94e2d5; }
.ansi-white { color: var(--c-text-primary); }

/* -- Config banner ----------------------------------- */
.config-banner {
    display: flex; align-items: flex-start; gap: 10px;
    margin: 12px 16px; padding: 12px 16px;
    font-size: 12px; line-height: 1.5; color: var(--c-yellow);
    background: rgba(202,138,4,0.08); border: 1px solid rgba(202,138,4,0.25);
    border-radius: 8px;
}
.config-banner code {
    font-family: 'JetBrains Mono', monospace; font-size: 11px;
    padding: 1px 5px; border-radius: 4px;
    background: rgba(202,138,4,0.12);
}
.config-banner .dismiss {
    margin-left: auto; background: none; border: none; cursor: pointer;
    color: var(--c-text-faint); font-size: 16px; line-height: 1; padding: 0 2px;
}
.config-banner .dismiss:hover { color: var(--c-text-primary); }

/* -- Modal ------------------------------------------- */
.modal-overlay {
    display: none; position: fixed; inset: 0;
    background: rgba(0,0,0,0.55); z-index: 100;
    justify-content: center; align-items: center;
}
.modal-overlay.open { display: flex; }
.modal {
    background: var(--c-surface); border: 1px solid var(--c-border);
    border-radius: 12px; padding: 24px; min-width: 360px; max-width: 440px;
    box-shadow: 0 16px 48px rgba(0,0,0,0.3);
}
.modal h3 { font-size: 15px; font-weight: 700; margin-bottom: 16px; color: var(--c-text-primary); }
.modal label { display: block; font-size: 12px; font-weight: 600; color: var(--c-text-secondary); margin-bottom: 6px; }
.modal input, .modal select {
    width: 100%; padding: 9px 12px; font-size: 14px; font-family: inherit;
    background: var(--c-bg); color: var(--c-text-primary);
    border: 1px solid var(--c-border); border-radius: 8px; outline: none; margin-bottom: 16px;
}
.modal input:focus, .modal select:focus { border-color: var(--c-accent); }
.modal .modal-actions { display: flex; gap: 8px; justify-content: flex-end; margin-top: 20px; }
.modal .modal-actions button {
    padding: 8px 20px; font-size: 13px; font-weight: 600; font-family: inherit;
    border-radius: 8px; cursor: pointer; border: 1px solid var(--c-border); transition: all 0.15s;
}
.modal .btn-cancel { background: var(--c-bg); color: var(--c-text-secondary); }
.modal .btn-cancel:hover { background: var(--c-surface-hover); }
.modal .btn-confirm {
    background: var(--c-accent); color: #fff; border-color: var(--c-accent); font-weight: 700;
}
.modal .btn-confirm:hover { background: var(--c-accent-hover); }
CSS;
    echo '</style>';
    echo '</head>';

    echo '<body>';

    // Header
    echo '<header class="header">';
    echo '  <div class="header-left">';
    echo '    <img src="/blundergoat-avatar.jpg" alt="DevGoat" class="header-logo">';
    echo '    <h1>' . $projectTitle . '</h1>';
    echo '  </div>';
    echo '  <div class="header-right">';
    // Project selector (WSL Path Selector)
    $defaultDir = htmlspecialchars(basename(SCRIPTS_DIR), ENT_QUOTES);
    echo '    <div class="project-selector">';
    echo '      <select id="projectSelect" onchange="onProjectSelectChange(this)">';
    echo '        <option value="">Select project path\u2026</option>';
    echo '        <option value="__custom__">Custom path\u2026</option>';
    echo '      </select>';
    echo '      <input type="text" class="project-custom-input hidden" id="projectCustomInput" placeholder="/path/to/project" onkeydown="if(event.key===\'Enter\')applyCustomProject()" onblur="applyCustomProject()">';
    echo '    </div>';
    /** @var string $siteUrlConst */
    $siteUrlConst = SITE_URL;
    if ($siteUrlConst !== '') {
        $siteUrl = htmlspecialchars($siteUrlConst, ENT_QUOTES);
        $parsedHost = parse_url($siteUrlConst, PHP_URL_HOST);
        $siteLabel = htmlspecialchars(is_string($parsedHost) ? $parsedHost : $siteUrlConst, ENT_QUOTES);
        echo '    <a class="site-link" href="' . $siteUrl . '" target="_blank">' . $siteLabel . '</a>';
    }
    echo '    <span class="env-badge" id="envBadge" title="' . htmlspecialchars(SCRIPTS_DIR, ENT_QUOTES) . '"><span class="dot"></span><span id="envBadgeText">' . $defaultDir . '</span></span>';
    echo '    <button class="theme-toggle" onclick="toggleTheme()" title="Toggle theme">';
    echo '      <svg id="themeIconSun" class="hidden" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><circle cx="12" cy="12" r="5"/><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/></svg>';
    echo '      <svg id="themeIconMoon" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M21 12.79A9 9 0 1111.21 3 7 7 0 0021 12.79z"/></svg>';
    echo '    </button>';
    echo '  </div>';
    echo '</header>';

    echo '<div class="layout">';
    echo '    <div class="sidebar-wrapper">';
    echo '        <div class="sidebar" id="sidebar"></div>';
    echo '        <div class="sidebar-footer"><a href="https://www.blundergoat.com" target="_blank" rel="noopener">created by BlunderGOAT</a></div>';
    echo '    </div>';
    echo '    <div class="terminal-wrapper">';
    echo '        <div class="terminal-toolbar">';
    echo '            <span class="script-label" id="scriptLabel">Ready</span>';
    echo '            <button class="toolbar-btn" id="copyBtn" onclick="copyOutput()" title="Copy output to clipboard">Copy</button>';
    echo '            <button class="toolbar-btn stop" id="stopBtn" disabled onclick="stopScript()">Stop</button>';
    echo '            <button class="toolbar-btn" id="clearBtn" onclick="clearTerminal()">Clear</button>';
    echo '        </div>';
    if (IS_EXAMPLE_CONFIG) {
        echo '<div class="config-banner" id="configBanner">';
        echo '<span>You\'re using the default example config. Edit <code>dashboard/config.php</code> to add the scripts useful for your project. Run <strong>Help</strong> to see what\'s available.</span>';
        echo '<button class="dismiss" onclick="this.parentElement.remove()" title="Dismiss">&times;</button>';
        echo '</div>';
    }
    echo '        <div class="terminal" id="terminal">';
    echo '            <span class="welcome">Select a script from the sidebar to run it.</span>';
    echo '        </div>';
    echo '    </div>';
    echo '</div>';

    echo <<<'HTML_BODY'

<div class="modal-overlay" id="modalOverlay">
    <div class="modal" id="modal">
        <h3 id="modalTitle"></h3>
        <div id="modalBody"></div>
        <div class="modal-actions">
            <button class="btn-cancel" onclick="closeModal()">Cancel</button>
            <button class="btn-confirm" id="modalConfirm" onclick="confirmModal()">Run</button>
        </div>
    </div>
</div>

<script>
/**
 * Theme
 */

function applyThemeIcons() {
    const theme = document.documentElement.getAttribute('data-theme');
    document.getElementById('themeIconSun').classList.toggle('hidden', theme === 'dark');
    document.getElementById('themeIconMoon').classList.toggle('hidden', theme === 'light');
}
function toggleTheme() {
    const next = document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', next);
    localStorage.setItem('devex_dash_theme', next);
    applyThemeIcons();
}
applyThemeIcons();

/**
 * State
 */

let state = {
    scripts: [],           // category/script tree from /api/scripts
    timings: {},           // scriptId → last run duration in seconds
    runningId: null,       // unique run ID (e.g. "port-check-143022") or null when idle
    runningScriptId: null, // script ID from config (e.g. "port-check") or null when idle
    eventSource: null,     // active EventSource for SSE streaming, null when idle
    autoScroll: true,      // auto-scroll terminal to bottom on new output
    pendingCallback: null, // callback to execute when modal is confirmed, null when no modal
};

const $ = (sel) => document.querySelector(sel);
const terminal = $('#terminal');
const sidebar  = $('#sidebar');
const stopBtn  = $('#stopBtn');
const scriptLabel = $('#scriptLabel');

/**
 * Init
 */

async function init() {
    try {
        // Load script registry and timing data in parallel
        const [scriptsResp, timingsResp] = await Promise.all([
            fetch('/api/scripts'),
            fetch('/api/timings'),
        ]);
        state.scripts = await scriptsResp.json();
        state.timings = await timingsResp.json();
        renderSidebar();

        // Load project list and restore saved selection from localStorage
        await loadProjects();

        // Check if a script is already running (e.g. page was refreshed mid-run)
        const statusResp = await fetch('/api/status');
        const statusData = await statusResp.json();
        if (statusData.running) {
            state.runningId = statusData.id;
            state.runningScriptId = statusData.script_id;
            setRunningState(true, statusData.script);
            connectStream(statusData.id);
        }
    } catch (err) {
        appendToTerminal(`<span class="ansi-red">Failed to load dashboard: ${esc(String(err))}</span>\n`);
    }
}

/**
 * Sidebar
 */

function renderSidebar() {
    sidebar.innerHTML = '';
    for (const cat of state.scripts) {
        const div = document.createElement('div');
        div.className = 'category';
        div.innerHTML = `
            <div class="category-header" onclick="this.parentElement.classList.toggle('collapsed')">
                <span class="arrow">\u25be</span>${esc(cat.category)}
            </div>
            <div class="category-scripts"></div>
        `;
        const container = div.querySelector('.category-scripts');
        for (const s of cat.scripts) {
            const btn = document.createElement('button');
            btn.className = 'script-btn';
            btn.dataset.id = s.id;
            btn.innerHTML = `<span class="s-name">${esc(s.name)}<span class="s-desc">${esc(s.desc)}</span></span>`;
            btn.title = s.desc;
            btn.onclick = () => onScriptClick(s);
            if (state.runningId && state.runningScriptId !== s.id) btn.disabled = true;
            if (state.runningScriptId === s.id) btn.classList.add('running');
            container.appendChild(btn);
        }
        sidebar.appendChild(div);
    }
}

function updateButtons() {
    document.querySelectorAll('.script-btn').forEach(btn => {
        const id = btn.dataset.id;
        if (state.runningId) {
            btn.classList.toggle('running', id === state.runningScriptId);
            btn.disabled = id !== state.runningScriptId;
        } else {
            btn.classList.remove('running');
            btn.disabled = false;
        }
    });
}

/**
 * Script execution
 */

/** Handle sidebar script button click - show modal if needed, or run directly. */
function onScriptClick(script) {
    if (state.runningId) return; // ignore clicks while a script is running
    if (script.confirm) { showConfirm(script); return; }
    if (script.prompt) { showPrompt(script); return; }
    runScript(script.id);
}

async function runScript(scriptId, arg) {
    const body = { script: scriptId };
    if (arg !== undefined) body.arg = arg;
    // Attach the selected project path so the script runs in that directory
    const project = localStorage.getItem('devex_dash_project');
    if (project) body.project = project;
    clearTerminal();

    try {
        const resp = await fetch('/api/run', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body),
        });
        const data = await resp.json();
        if (data.error) {
            appendToTerminal(`<span class="ansi-red">Error: ${esc(data.error)}</span>\n`);
            return;
        }

        state.runningId = data.id;
        state.runningScriptId = scriptId;
        state.startedAt = Date.now();

        // Resolve the display label (show cmd + args rather than just the script ID)
        let label = scriptId;
        for (const cat of state.scripts) {
            for (const s of cat.scripts) {
                if (s.id === scriptId) { label = s.cmd + (s.args ? ' ' + s.args.join(' ') : ''); break; }
            }
        }
        setRunningState(true, label);
        connectStream(data.id);
    } catch (err) {
        appendToTerminal(`<span class="ansi-red">Failed to start script: ${esc(String(err))}</span>\n`);
    }
}

/**
 * Open an SSE connection to stream script output into the terminal.
 *
 * Events:
 *   output    - a chunk of ANSI-converted HTML to append
 *   done      - script finished, show duration and reset UI
 *   heartbeat - keepalive, ignored
 */
function connectStream(id) {
    // Close any existing stream (shouldn't happen, but defensive)
    if (state.eventSource) state.eventSource.close();

    const es = new EventSource(`/api/stream/${id}`);
    state.eventSource = es;

    es.addEventListener('output', (e) => appendToTerminal(e.data));

    es.addEventListener('done', () => {
        const elapsedSecs = state.startedAt ? ((Date.now() - state.startedAt) / 1000) : 0;
        const duration = elapsedSecs < 1 ? '<1s' : elapsedSecs < 60 ? Math.round(elapsedSecs) + 's' : Math.floor(elapsedSecs/60) + 'm ' + Math.round(elapsedSecs%60) + 's';
        appendToTerminal(`\n<span class="ansi-green ansi-bold">\u2714 Done</span> <span class="ansi-dim">in ${duration}</span>\n`);
        setRunningState(false, null, duration);
        es.close();
        state.eventSource = null;
        state.runningId = null;
        state.runningScriptId = null;
        updateButtons();
    });

    es.addEventListener('heartbeat', () => {}); // keepalive - no action needed

    es.onerror = () => {
        // EventSource auto-reconnects on error; if the connection is truly closed
        // (server ended the stream), wait 2s then clean up the UI state
        setTimeout(() => {
            if (es.readyState === EventSource.CLOSED) {
                setRunningState(false);
                state.runningId = null;
                state.runningScriptId = null;
                updateButtons();
            }
        }, 2000);
    };
}

async function stopScript() {
    if (!state.runningId) return;
    stopBtn.disabled = true;
    stopBtn.textContent = 'Stopping\u2026';
    try {
        await fetch(`/api/stop/${state.runningId}`, { method: 'POST' });
        appendToTerminal('\n<span class="ansi-yellow">\u2500\u2500 Stopped \u2500\u2500</span>\n');
    } catch (e) {
        appendToTerminal('\n<span class="ansi-red">Failed to stop process</span>\n');
    }
}

/**
 * Update the toolbar and sidebar to reflect running/idle state.
 *
 * When running: shows the command label with a live elapsed timer.
 * When done with a duration: shows "$ command 12s ✔ Done".
 * When idle (no duration): shows "Ready".
 */
function setRunningState(running, label, completedDuration) {
    stopBtn.disabled = !running;
    stopBtn.textContent = 'Stop';
    if (state.timerInterval) { clearInterval(state.timerInterval); state.timerInterval = null; }
    if (running) {
        state.lastLabel = label;
        scriptLabel.innerHTML = `$ <strong>${esc(label || '')}</strong> <span id="elapsed" class="ansi-dim"></span>`;
        // Live elapsed timer - updates every second while script runs
        state.timerInterval = setInterval(() => {
            const el = document.getElementById('elapsed');
            if (!el || !state.startedAt) return;
            const s = Math.floor((Date.now() - state.startedAt) / 1000);
            el.textContent = s < 60 ? s + 's' : Math.floor(s/60) + 'm ' + (s%60) + 's';
        }, 1000);
    } else if (state.lastLabel && completedDuration) {
        // Script just finished - show the final duration
        scriptLabel.innerHTML = `$ ${esc(state.lastLabel)} <span class="ansi-dim">${esc(completedDuration)}</span> <span class="ansi-green">\u2714 Done</span>`;
    } else {
        scriptLabel.textContent = 'Ready';
    }
    updateButtons();
}

/**
 * Terminal
 */

/** Append HTML content to the terminal, removing the welcome message on first output. */
function appendToTerminal(html) {
    const welcome = terminal.querySelector('.welcome');
    if (welcome) welcome.remove(); // clear placeholder on first real output
    const span = document.createElement('span');
    span.innerHTML = html;
    terminal.appendChild(span);
    // Defer scroll until after the browser paints the new content
    if (state.autoScroll) {
        requestAnimationFrame(() => { terminal.scrollTop = terminal.scrollHeight; });
    }
}

// Disable auto-scroll when user scrolls up to read earlier output.
// Re-enable when they scroll back to the bottom (within 50px threshold).
terminal.addEventListener('scroll', () => {
    state.autoScroll = terminal.scrollTop + terminal.clientHeight >= terminal.scrollHeight - 50;
});

function clearTerminal() { terminal.innerHTML = ''; }

/** Copy terminal text content to clipboard (strips HTML/ANSI spans). */
function copyOutput() {
    const text = terminal.innerText;
    if (!text.trim()) return;
    navigator.clipboard.writeText(text).then(() => {
        const btn = $('#copyBtn');
        btn.textContent = 'Copied!';
        setTimeout(() => { btn.textContent = 'Copy'; }, 1500);
    });
}

/**
 * Modal
 */

/** Show a confirmation dialog before running a destructive or slow script. */
function showConfirm(script) {
    $('#modalTitle').textContent = 'Confirm: ' + script.name;
    // Show timing info: prefer recorded duration from last run, fall back to estimated
    const recordedSecs = state.timings[script.id];
    const estimatedMins = script.estimatedMins;
    let timing = '';
    if (recordedSecs) {
        timing = `Last time this took ${formatDuration(recordedSecs)}.`;
    } else if (estimatedMins) {
        timing = `Typically takes ~${estimatedMins} min${estimatedMins > 1 ? 's' : ''}.`;
    }
    $('#modalBody').innerHTML =
        `<p style="color:var(--c-text-secondary);font-size:13px;margin-bottom:8px">${esc(script.desc)}</p>` +
        (timing ? `<p style="color:var(--c-yellow);font-size:13px">${esc(timing)}</p>` : '');
    $('#modalConfirm').textContent = 'Run';
    state.pendingCallback = () => runScript(script.id);
    $('#modalOverlay').classList.add('open');
}

function formatDuration(secs) {
    if (secs < 60) return `${secs}s`;
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return s > 0 ? `${m}m ${s}s` : `${m}m`;
}

/**
 * Show a prompt modal for scripts that need user input before running.
 *
 * Supports two prompt types from config.php:
 *   type: 'select'  - dropdown with predefined options
 *   type: 'text'    - free-form text input
 *
 * The optional flag allows submitting an empty value (for optional args).
 */
function showPrompt(script) {
    const promptConfig = script.prompt;
    $('#modalTitle').textContent = script.name;
    if (promptConfig.type === 'select') {
        $('#modalBody').innerHTML = `<label>${esc(promptConfig.label)}</label><select id="modalInput">` +
            promptConfig.options.map(o => `<option value="${esc(o)}">${esc(o)}</option>`).join('') + `</select>`;
    } else {
        $('#modalBody').innerHTML = `<label>${esc(promptConfig.label)}</label><input type="text" id="modalInput" placeholder="${esc(promptConfig.label)}" autofocus>`;
    }
    $('#modalConfirm').textContent = 'Run';
    const isOptional = promptConfig.optional || false;
    state.pendingCallback = () => {
        const val = $('#modalInput').value.trim();
        if (!val && !isOptional) return; // required input can't be empty
        runScript(script.id, val || undefined); // undefined = don't send arg field
    };
    $('#modalOverlay').classList.add('open');
    setTimeout(() => { const inp = $('#modalInput'); if (inp) inp.focus(); }, 50);
}

function confirmModal() {
    const cb = state.pendingCallback;
    closeModal();
    if (cb) cb();
}

function closeModal() {
    $('#modalOverlay').classList.remove('open');
    state.pendingCallback = null;
}

// Keyboard shortcuts: Escape closes modal, Enter confirms it
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeModal();
    if (e.key === 'Enter' && $('#modalOverlay').classList.contains('open')) confirmModal();
});

/**
 * Helpers
 */

/** HTML-escape a string to prevent XSS when injecting into innerHTML. */
function esc(str) { const d = document.createElement('div'); d.textContent = str || ''; return d.innerHTML; }

/**
 * Project Selector (WSL Path Selector)
 *
 * Lets users pick which project directory scripts run in.
 * Selection is persisted in localStorage ('devex_dash_project').
 */

async function loadProjects() {
    try {
        const resp = await fetch('/api/projects');
        state.projects = await resp.json();
    } catch { state.projects = []; } // graceful fallback if API fails

    const sel = $('#projectSelect');
    sel.innerHTML = '<option value="">Select project path\u2026</option>';
    for (const p of state.projects) {
        const opt = document.createElement('option');
        opt.value = p.path;
        opt.textContent = p.name + (p.exists ? '' : ' (not found)');
        opt.disabled = !p.exists; // grey out paths that don't exist on disk
        sel.appendChild(opt);
    }
    const customOpt = document.createElement('option');
    customOpt.value = '__custom__';
    customOpt.textContent = 'Custom path\u2026';
    sel.appendChild(customOpt);

    // Restore previously selected project from localStorage
    const savedProject = localStorage.getItem('devex_dash_project') || '';
    if (savedProject) {
        const isKnownPath = state.projects.find(p => p.path === savedProject);
        if (isKnownPath) {
            sel.value = savedProject;
        } else {
            // Saved path isn't in the config - add it as a custom option
            const opt = document.createElement('option');
            opt.value = savedProject;
            opt.textContent = savedProject.split('/').pop() + ' (custom)';
            sel.insertBefore(opt, sel.querySelector('[value="__custom__"]'));
            sel.value = savedProject;
        }
        updateTargetLabel(savedProject);
    }
}

/** Handle project dropdown change - show custom input or persist selection. */
function onProjectSelectChange(sel) {
    const val = sel.value;
    const customInput = $('#projectCustomInput');

    if (val === '__custom__') {
        // Show the free-text path input
        customInput.classList.remove('hidden');
        customInput.classList.remove('invalid');
        customInput.value = '';
        customInput.focus();
        return;
    }

    customInput.classList.add('hidden');

    if (val === '') {
        // "Select project path…" placeholder - clear saved project
        localStorage.removeItem('devex_dash_project');
        updateTargetLabel('');
    } else {
        localStorage.setItem('devex_dash_project', val);
        updateTargetLabel(val);
    }
}

function applyCustomProject() {
    const input = $('#projectCustomInput');
    const sel = $('#projectSelect');
    const path = input.value.trim();

    if (path === '') {
        // Cancelled - revert to default
        sel.value = '';
        input.classList.add('hidden');
        localStorage.removeItem('devex_dash_project');
        updateTargetLabel('');
        return;
    }

    // Add as option and select it
    const existing = sel.querySelector(`option[value="${CSS.escape(path)}"]`);
    if (!existing) {
        const opt = document.createElement('option');
        opt.value = path;
        opt.textContent = path.split('/').pop() + ' (custom)';
        sel.insertBefore(opt, sel.querySelector('[value="__custom__"]'));
    }
    sel.value = path;
    input.classList.add('hidden');
    input.classList.remove('invalid');
    localStorage.setItem('devex_dash_project', path);
    updateTargetLabel(path);
}

/** Update the header badge to show the active project folder name. */
function updateTargetLabel(path) {
    const badge = $('#envBadge');
    const badgeText = $('#envBadgeText');
    const defaultName = $('#projectSelect').options[0].textContent;
    if (!path) {
        badgeText.textContent = defaultName;
        badge.title = '';
    } else {
        badgeText.textContent = path.split('/').pop(); // show just the folder name
        badge.title = path; // full path on hover
    }
}

/**
 * Start
 */

init();
</script>
</body>
</html>
HTML_BODY;
}
