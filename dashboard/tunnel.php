<?php

/**
 * Generic tunnel UI fragments for the main dashboard.
 *
 * The tunnel surface is intentionally provider-agnostic. Users can paste any
 * public base URL (Cloudflare, ngrok, localhost.run, etc.), store it in the
 * dashboard temp dir, and manually test exposed routes from the browser.
 */

function tunnelCss(): string
{
    return <<<'CSS'

/* Tunnel icon in header */
.tunnel-icon-btn {
    position: relative;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    min-height: 32px;
    padding: 0 12px;
    font-size: 11px;
    font-weight: 600;
    font-family: inherit;
    background: var(--c-surface);
    border: 1px solid var(--c-border);
    cursor: pointer;
    border-radius: 8px;
    color: var(--c-text-muted);
    text-decoration: none;
    transition: all 0.2s;
    box-shadow: var(--shadow-sm);
}
.tunnel-icon-btn:hover { color: var(--c-text-primary); background: var(--c-surface-hover); }
.tunnel-icon-btn.active-page { color: var(--c-accent); }
.tunnel-icon-btn .tunnel-dot {
    display: none;
    position: absolute;
    top: 4px;
    right: 4px;
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: var(--c-green);
    border: 1.5px solid var(--c-surface);
}
.tunnel-icon-btn.tunnel-live .tunnel-dot { display: block; }

/* Tunnel page */
.tunnel-page {
    display: none;
    flex: 1;
    overflow-y: auto;
    padding: 18px 16px 24px;
    max-width: none;
    margin: 0;
    width: 100%;
    background: var(--c-bg);
}
.tunnel-page.visible { display: block; }

.tp-back {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    min-height: 30px;
    font-size: 11px;
    font-weight: 600;
    color: var(--c-text-muted);
    text-decoration: none;
    cursor: pointer;
    background: var(--c-surface);
    border: 1px solid var(--c-border);
    font-family: inherit;
    padding: 0 10px;
    margin-bottom: 16px;
    border-radius: 8px;
    transition: color 0.15s;
    box-shadow: var(--shadow-sm);
}
.tp-back:hover { color: var(--c-text-primary); border-color: var(--c-accent); }

.tp-title {
    font-size: 18px;
    font-weight: 700;
    margin-bottom: 4px;
    display: flex;
    align-items: center;
    gap: 8px;
    letter-spacing: -0.02em;
}
.tp-subtitle {
    font-size: 12px;
    color: var(--c-text-muted);
    margin-bottom: 18px;
    line-height: 1.65;
    max-width: 84ch;
}

.tp-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 16px;
}
.tp-grid .tp-card.full { grid-column: 1 / -1; }

.tp-card {
    background: var(--c-surface);
    border: 1px solid var(--c-border);
    border-radius: 16px;
    padding: 16px;
    min-width: 0;
    box-shadow: var(--shadow-panel);
}
.tp-card-title {
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--c-text-faint);
    margin-bottom: 12px;
    font-family: var(--font-mono);
}

.tp-status-row {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 10px;
}
.tp-status-dot {
    width: 10px;
    height: 10px;
    border-radius: 50%;
    flex-shrink: 0;
}
.tp-status-dot.active { background: var(--c-green); }
.tp-status-dot.inactive { background: var(--c-text-faint); opacity: 0.4; }
.tp-status-label { font-size: 13px; font-weight: 700; }
.tp-status-url {
    font-size: 14px;
    font-weight: 600;
    font-family: var(--font-mono);
    color: var(--c-accent);
    word-break: break-all;
    cursor: pointer;
    transition: color 0.15s;
}
.tp-status-url:hover { opacity: 0.8; }
.tp-status-meta {
    font-size: 11px;
    color: var(--c-text-faint);
    margin-top: 4px;
    line-height: 1.5;
}

.tp-manual-row,
.tp-test-row,
.tp-action-row {
    display: flex;
    gap: 8px;
    align-items: center;
    margin-top: 14px;
    flex-wrap: wrap;
}
.tp-manual-row input,
.tp-test-row input,
.tp-test-row select {
    min-height: 36px;
    padding: 0 12px;
    font-size: 12px;
    font-family: var(--font-mono);
    background: var(--c-bg);
    color: var(--c-text-primary);
    border: 1px solid var(--c-border);
    border-radius: 8px;
    outline: none;
}
.tp-manual-row input { flex: 1; min-width: 260px; }
.tp-test-row input { flex: 1; min-width: 220px; }
.tp-test-row select { min-width: 96px; }
.tp-manual-row input:focus,
.tp-test-row input:focus,
.tp-test-row select:focus { border-color: var(--c-accent); }
.tp-manual-row input::placeholder,
.tp-test-row input::placeholder { color: var(--c-text-faint); }

.tp-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-height: 32px;
    padding: 0 12px;
    font-size: 11px;
    font-weight: 700;
    font-family: inherit;
    border-radius: 8px;
    cursor: pointer;
    border: 1px solid var(--c-border);
    transition: all 0.15s;
    background: var(--c-surface-hover);
    color: var(--c-text-secondary);
    box-shadow: var(--shadow-sm);
}
.tp-btn:hover { background: var(--c-bg); color: var(--c-text-primary); }
.tp-btn:disabled { opacity: 0.35; cursor: not-allowed; }
.tp-btn.primary {
    background: var(--c-accent);
    color: #fff;
    border-color: var(--c-accent);
    font-weight: 700;
}
.tp-btn.primary:hover { background: var(--c-accent-hover); }
.tp-btn.danger {
    color: var(--c-red);
    border-color: var(--c-red);
    background: rgba(243,139,168,0.08);
}
.tp-btn.danger:hover { background: rgba(243,139,168,0.2); }

.tp-copy {
    border: 1px solid var(--c-border);
    background: var(--c-bg);
    color: var(--c-text-secondary);
    border-radius: 8px;
    min-height: 32px;
    padding: 0 12px;
    font-size: 11px;
    font-weight: 700;
    cursor: pointer;
    box-shadow: var(--shadow-sm);
}
.tp-copy.copied,
.tp-btn.copied {
    color: var(--c-green);
    border-color: var(--c-green);
    background: rgba(22,163,74,0.12);
}

.tp-example,
.tp-note {
    margin-top: 12px;
    padding: 10px 12px;
    border-radius: 8px;
    background: var(--c-surface-hover);
    border: 1px solid var(--c-border);
}
.tp-example-label {
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--c-text-faint);
    margin-bottom: 6px;
    font-family: var(--font-mono);
}
.tp-example-value {
    font-size: 11px;
    line-height: 1.6;
    word-break: break-word;
    font-family: var(--font-mono);
    color: var(--c-text-secondary);
    white-space: pre-wrap;
}

.tp-test-help,
.tp-instructions {
    font-size: 12px;
    line-height: 1.7;
    color: var(--c-text-secondary);
}
.tp-test-help code,
.tp-instructions code {
    font-family: var(--font-mono);
    font-size: 11px;
    background: var(--c-bg);
    padding: 2px 6px;
    border-radius: 4px;
    border: 1px solid var(--c-border);
}

.tp-test-result-line {
    display: flex;
    gap: 8px;
    align-items: center;
    flex-wrap: wrap;
    font-size: 12px;
    margin-top: 14px;
}
.tp-response,
.tp-output {
    display: none;
    max-height: 260px;
    overflow-y: auto;
    padding: 12px 16px;
    font-family: var(--font-mono);
    font-size: 12px;
    line-height: 1.6;
    white-space: pre-wrap;
    word-break: break-word;
    background: var(--c-terminal-bg);
    border-radius: 8px;
    border: 1px solid var(--c-border);
    margin-top: 12px;
}
.tp-response.visible,
.tp-output.visible { display: block; }

.tp-warning {
    display: flex;
    align-items: flex-start;
    gap: 8px;
    margin-top: 14px;
    padding: 10px 14px;
    border-radius: 8px;
    background: rgba(217,119,6,0.08);
    border: 1px solid rgba(217,119,6,0.2);
    font-size: 12px;
    color: var(--c-yellow);
    line-height: 1.5;
}
[data-theme="dark"] .tp-warning {
    background: rgba(245,158,11,0.08);
    border-color: rgba(245,158,11,0.16);
}

/* Uptime display */
.tp-uptime {
    font-size: 11px;
    font-family: var(--font-mono);
    color: var(--c-text-faint);
    margin-top: 6px;
}

/* Target input row */
.tp-target-row {
    display: flex;
    gap: 8px;
    align-items: center;
    margin-top: 10px;
}
.tp-target-row input {
    flex: 1;
    min-height: 34px;
    padding: 0 12px;
    font-size: 12px;
    font-family: var(--font-mono);
    background: var(--c-bg);
    color: var(--c-text-primary);
    border: 1px solid var(--c-border);
    border-radius: 8px;
    outline: none;
}
.tp-target-row input:focus { border-color: var(--c-accent); }
.tp-target-row input::placeholder { color: var(--c-text-faint); }
.tp-target-row label {
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--c-text-faint);
    font-family: var(--font-mono);
    white-space: nowrap;
}

/* Recent URLs */
.tp-recent { margin-top: 12px; }
.tp-recent-label {
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--c-text-faint);
    margin-bottom: 6px;
    font-family: var(--font-mono);
}
.tp-recent-chips {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
}
.tp-recent-chip {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 4px 10px;
    font-size: 11px;
    font-family: var(--font-mono);
    background: var(--c-surface-hover);
    border: 1px solid var(--c-border);
    border-radius: 6px;
    cursor: pointer;
    color: var(--c-text-secondary);
    transition: all 0.15s;
    max-width: 100%;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}
.tp-recent-chip:hover { border-color: var(--c-accent); color: var(--c-accent); }
.tp-recent-chip .remove {
    font-size: 13px;
    color: var(--c-text-faint);
    cursor: pointer;
    margin-left: 2px;
    flex-shrink: 0;
}
.tp-recent-chip .remove:hover { color: var(--c-red); }

/* Log output inside collapsible */
.tp-log-output {
    max-height: 260px;
    overflow-y: auto;
    padding: 12px 16px;
    font-family: var(--font-mono);
    font-size: 12px;
    line-height: 1.6;
    white-space: pre-wrap;
    word-break: break-word;
    background: var(--c-terminal-bg);
    border-radius: 8px;
    border: 1px solid var(--c-border);
    margin-top: 8px;
}

@media (max-width: 860px) {
    .tunnel-page { padding: 12px; }
    .tp-grid { grid-template-columns: 1fr; }
    .tp-grid .tp-card.full { grid-column: auto; }
}
CSS;
}

function tunnelHeaderIconHtml(): string
{
    return <<<'HTML'
    <button class="tunnel-icon-btn" id="tunnelIconBtn" onclick="toggleTunnelPage()" title="Tunnel" aria-label="Tunnel">
      <span class="tunnel-dot"></span>
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 014 10 15.3 15.3 0 01-4 10 15.3 15.3 0 01-4-10 15.3 15.3 0 014-10z"/></svg>
      Tunnel
    </button>
HTML;
}

function tunnelPageHtml(): string
{
    return <<<'HTML'

<div class="tunnel-page" id="tunnelPage">
    <button class="tp-back" onclick="toggleTunnelPage()">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5"/><polyline points="12 19 5 12 12 5"/></svg>
        Back to Dashboard
    </button>

    <div class="tp-title">
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 014 10 15.3 15.3 0 01-4 10 15.3 15.3 0 01-4-10 15.3 15.3 0 014-10z"/></svg>
        Tunnel
    </div>
    <div class="tp-subtitle">Cloudflare quick tunnel is the default. Start a public demo URL that points back to this dashboard, or paste a manual URL from another provider.</div>

    <div class="tp-grid">
        <!-- STATUS — full width hero -->
        <div class="tp-card full">
            <div class="tp-card-title">Status</div>
            <div class="tp-status-row">
                <span class="tp-status-dot inactive" id="tpDot"></span>
                <span class="tp-status-label" id="tpLabel">Inactive</span>
            </div>
            <div id="tpUrlDisplay" style="display:none">
                <div class="tp-status-url" id="tpUrl" onclick="copyTunnelUrlText()" title="Click to copy"></div>
                <div class="tp-status-meta" id="tpMeta"></div>
                <div class="tp-uptime" id="tpUptime"></div>
            </div>
            <div class="tp-target-row" id="tpTargetRow">
                <label>Target</label>
                <input type="text" id="tpTargetInput" placeholder="http://127.0.0.1:8899" />
            </div>
            <div class="tp-action-row">
                <button class="tp-btn primary" id="tpStartBtn" type="button" onclick="tunnelStart()">Start Cloudflare Demo</button>
                <button class="tp-btn danger" id="tpStopBtn" type="button" onclick="tunnelStop()" style="display:none">Stop</button>
                <button class="tp-copy" id="tpCopyUrlBtn" type="button" onclick="copyTunnelUrl(this)" style="display:none">Copy URL</button>
                <button class="tp-btn danger" id="tpClearBtn" type="button" onclick="tunnelClear()" style="display:none">Clear</button>
            </div>

            <div class="collapsible-header" id="tpLogsToggle" onclick="toggleTunnelLogs()" style="display:none">
                <span class="chevron">&#9654;</span> Logs
            </div>
            <div class="collapsible-body" id="tpLogsBody">
                <pre class="tp-log-output" id="tpLogsContent"></pre>
            </div>

            <div class="collapsible-header" onclick="toggleCollapsible(this)">
                <span class="chevron">&#9654;</span> Default Demo Target
            </div>
            <div class="collapsible-body">
                <div class="tp-example" style="margin-top:4px">
                    <div class="tp-example-value" id="tpDefaultTarget">Loading...</div>
                </div>
            </div>

            <div class="tp-output" id="tpOutput"></div>
        </div>

        <!-- PASTE TUNNEL URL -->
        <div class="tp-card">
            <div class="tp-card-title">Paste Tunnel URL</div>
            <div class="tp-test-help">Already have a public URL from ngrok, localhost.run, Tailscale Funnel, or another provider? Paste it here.</div>
            <div class="tp-manual-row">
                <input type="text" id="tpManualInput" placeholder="https://abc123.trycloudflare.com" />
                <button class="tp-btn primary" id="tpSetManualBtn" type="button" onclick="tunnelSetManual()">Save URL</button>
            </div>
            <div class="tp-recent" id="tpRecentSection" style="display:none">
                <div class="tp-recent-label">Recent URLs</div>
                <div class="tp-recent-chips" id="tpRecentChips"></div>
            </div>

            <div class="tp-warning">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="flex-shrink:0;margin-top:1px"><path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
                <div><strong>Public exposure:</strong> the stored URL is reachable outside your machine. Only expose routes safe for local development.</div>
            </div>

            <div class="collapsible-header" onclick="toggleCollapsible(this)">
                <span class="chevron">&#9654;</span> Usage Notes
            </div>
            <div class="collapsible-body">
                <div class="tp-instructions" style="margin-top:4px">
                    <ol style="padding-left:20px">
                        <li>Use <strong>Start Cloudflare Demo</strong> for a working public URL with no extra setup.</li>
                        <li>Set a custom <strong>Target</strong> to tunnel a different local service (e.g. <code>http://127.0.0.1:3000</code>).</li>
                        <li>The default target is this dashboard, so the public URL is immediately testable.</li>
                        <li>Use the manual test card to verify routes before sharing.</li>
                        <li>Paste a manual URL to use another tunnel provider or target.</li>
                    </ol>
                </div>
            </div>
        </div>

        <!-- QUICK START -->
        <div class="tp-card" style="border-left:3px solid var(--c-accent);background:var(--c-surface-hover)">
            <div class="tp-card-title">Quick Start</div>
            <div class="tp-test-help" style="line-height:1.7">The default Cloudflare action tunnels this dashboard itself, so you can confirm that public routing works before wiring it into another local service. No account or config needed — just click <strong>Start Cloudflare Demo</strong>.</div>
        </div>

        <!-- MANUAL TEST — full width -->
        <div class="tp-card full" id="tpManualTestCard">
            <div class="tp-card-title">Manual Test</div>
            <div class="tp-test-help">Run a quick <code>GET</code> or <code>HEAD</code> against the current tunnel URL.</div>
            <div class="tp-test-row">
                <select id="tpTestMethod" onchange="updateTunnelTestPreview()">
                    <option value="GET">GET</option>
                    <option value="HEAD">HEAD</option>
                </select>
                <input type="text" id="tpTestPath" value="/" placeholder="/" oninput="updateTunnelTestPreview()" />
                <button class="tp-btn primary" id="tpTestBtn" type="button" onclick="tunnelTest()">Run test</button>
                <button class="tp-btn" id="tpOpenBtn" type="button" onclick="openTunnelTestUrl()" style="opacity:0.7">Open URL</button>
                <button class="tp-btn" id="tpCopyCurlBtn" type="button" onclick="copyTunnelCurl(this)" style="opacity:0.7">Copy curl</button>
            </div>
            <div id="tpTestResult"></div>
            <pre class="tp-response" id="tpTestResponse"></pre>

            <div class="collapsible-header" onclick="toggleCollapsible(this)">
                <span class="chevron">&#9654;</span> Request Details
            </div>
            <div class="collapsible-body">
                <div class="tp-example" style="margin-top:4px">
                    <div class="tp-example-label">Full URL</div>
                    <div class="tp-example-value" id="tpTestUrl">Configure a tunnel URL to generate a test target.</div>
                </div>
                <div class="tp-example">
                    <div class="tp-example-label">Example curl</div>
                    <div class="tp-example-value" id="tpCurlPreview"></div>
                </div>
            </div>
        </div>
    </div>
</div>
HTML;
}

function tunnelJs(): string
{
    return <<<'JS'

state.tunnelPageVisible = false;
state.tunnel = {
    active: false,
    url: null,
    provider: null,
    target: null,
    started_at: null,
    default_target: null,
    cloudflare_available: false,
    provider_default: 'cloudflare',
};

function normalizeTunnelPath(value) {
    const trimmed = (value || '').trim();
    if (!trimmed) return '/';
    if (/^[a-z][a-z0-9+.-]*:\/\//i.test(trimmed)) return '/';
    return trimmed.startsWith('/') ? trimmed : '/' + trimmed;
}

function buildTunnelTestUrl(path) {
    if (!state.tunnel.active || !state.tunnel.url) return '';
    const baseUrl = String(state.tunnel.url || '').replace(/\/+$/, '');
    const normalizedPath = normalizeTunnelPath(path);
    return normalizedPath === '/' ? `${baseUrl}/` : `${baseUrl}${normalizedPath}`;
}

function buildTunnelCurl(method, path) {
    const url = buildTunnelTestUrl(path);
    if (!url) return '';
    return `curl ${method === 'HEAD' ? '-I' : '-i'} "${url}"`;
}

function updateTunnelTestPreview() {
    const path = normalizeTunnelPath(document.getElementById('tpTestPath')?.value || '/');
    const method = (document.getElementById('tpTestMethod')?.value || 'GET').toUpperCase();
    const fullUrl = buildTunnelTestUrl(path);
    document.getElementById('tpTestUrl').textContent = fullUrl || 'Start the Cloudflare demo or save a tunnel URL to generate a test target.';
    document.getElementById('tpCurlPreview').textContent = fullUrl ? buildTunnelCurl(method, path) : '';
}

function toggleTunnelPage() {
    state.tunnelPageVisible = !state.tunnelPageVisible;
    document.getElementById('mainLayout').style.display = state.tunnelPageVisible ? 'none' : 'flex';
    document.getElementById('tunnelPage').classList.toggle('visible', state.tunnelPageVisible);
    document.getElementById('tunnelIconBtn').classList.toggle('active-page', state.tunnelPageVisible);
    if (state.tunnelPageVisible) {
        refreshTunnelPage();
        renderRecentUrls();
        startTunnelPolling();
    } else {
        stopTunnelPolling();
        stopUptimeTimer();
    }
}

function setTunnelOutput(message, isError = false) {
    const output = document.getElementById('tpOutput');
    output.innerHTML = isError ? `<span class="ansi-red">${esc(message)}</span>` : esc(message);
    output.classList.add('visible');
}

function clearTunnelOutput() {
    const output = document.getElementById('tpOutput');
    output.textContent = '';
    output.classList.remove('visible');
}

async function refreshTunnelPage() {
    try {
        const resp = await fetch('/api/tunnel-status');
        if (!resp.ok) return;
        const data = await resp.json();
        state.tunnel = data;
        renderTunnelStatus(data);
    } catch (_) {
        setTunnelOutput('Failed to load tunnel status.', true);
    }
}

function renderTunnelStatus(data) {
    const dot = document.getElementById('tpDot');
    const label = document.getElementById('tpLabel');
    const urlDisplay = document.getElementById('tpUrlDisplay');
    const urlEl = document.getElementById('tpUrl');
    const metaEl = document.getElementById('tpMeta');
    const startBtn = document.getElementById('tpStartBtn');
    const stopBtn = document.getElementById('tpStopBtn');
    const clearBtn = document.getElementById('tpClearBtn');
    const copyUrlBtn = document.getElementById('tpCopyUrlBtn');
    const defaultTarget = document.getElementById('tpDefaultTarget');
    const testResult = document.getElementById('tpTestResult');
    const testResponse = document.getElementById('tpTestResponse');
    const targetRow = document.getElementById('tpTargetRow');
    const logsToggle = document.getElementById('tpLogsToggle');

    defaultTarget.textContent = data.default_target || 'http://127.0.0.1:8899';
    startBtn.disabled = data.cloudflare_available !== true;
    startBtn.title = data.cloudflare_available ? 'Start a Cloudflare quick tunnel to the target URL' : 'cloudflared is not available';

    if (data.active && data.url) {
        const metaParts = [];
        if (data.provider) metaParts.push(`Source: ${data.provider}`);
        if (data.target) metaParts.push(`Target: ${data.target}`);
        if (data.started_at) metaParts.push(`Saved: ${data.started_at}`);

        dot.className = 'tp-status-dot active';
        label.textContent = 'Active';
        label.style.color = 'var(--c-green)';
        urlEl.textContent = data.url;
        metaEl.textContent = metaParts.join(' | ');
        urlDisplay.style.display = 'block';
        startBtn.style.display = 'none';
        targetRow.style.display = 'none';
        stopBtn.style.display = data.provider === 'cloudflare' ? 'inline-flex' : 'none';
        clearBtn.style.display = data.provider === 'manual' ? 'inline-flex' : 'none';
        copyUrlBtn.style.display = 'inline-flex';
        logsToggle.style.display = data.provider === 'cloudflare' ? 'block' : 'none';
        startUptimeTimer();
        updateUptimeDisplay();
        clearTunnelOutput();
    } else {
        dot.className = 'tp-status-dot inactive';
        label.textContent = 'Inactive';
        label.style.color = '';
        urlDisplay.style.display = 'none';
        startBtn.style.display = 'inline-flex';
        targetRow.style.display = 'flex';
        stopBtn.style.display = 'none';
        clearBtn.style.display = 'none';
        copyUrlBtn.style.display = 'none';
        logsToggle.style.display = 'none';
        // Collapse logs
        document.getElementById('tpLogsBody').classList.remove('open');
        logsToggle.classList.remove('open');
        stopUptimeTimer();
        document.getElementById('tpUptime').textContent = '';
        testResult.innerHTML = '';
        testResponse.textContent = '';
        testResponse.classList.remove('visible');
        const targetInput = document.getElementById('tpTargetInput');
        if (targetInput && !targetInput.value) {
            targetInput.placeholder = data.default_target || 'http://127.0.0.1:8899';
        }
    }

    updateTunnelTestPreview();

    // Disable test controls when no tunnel is active
    const testDisabled = !(data.active && data.url);
    ['tpTestBtn', 'tpOpenBtn', 'tpCopyCurlBtn'].forEach(id => {
        const el = document.getElementById(id);
        if (el) el.disabled = testDisabled;
    });
}

async function tunnelStart() {
    setTunnelActionState(true);
    try {
        const customTarget = (document.getElementById('tpTargetInput')?.value || '').trim();
        const target = customTarget || state.tunnel.default_target || null;
        const resp = await fetch('/api/tunnel-start', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ target }),
        });
        const data = await resp.json();
        if (!resp.ok) {
            throw new Error(data.error || 'Failed to start Cloudflare tunnel');
        }

        state.tunnel = data;
        renderTunnelStatus(data);
        updateTunnelIcon();
        setTunnelOutput('Cloudflare quick tunnel started.');
        notifyTunnelReady(data.url);
    } catch (err) {
        setTunnelOutput(String(err), true);
    } finally {
        setTunnelActionState(false);
    }
}

async function tunnelSetManual() {
    const input = document.getElementById('tpManualInput');
    const url = (input.value || '').trim();
    if (!url) {
        setTunnelOutput('Enter a public tunnel URL first.', true);
        return;
    }

    setTunnelActionState(true);
    try {
        const resp = await fetch('/api/tunnel-configure', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ url }),
        });
        const data = await resp.json();
        if (!resp.ok) {
            throw new Error(data.error || 'Failed to store tunnel URL');
        }

        state.tunnel = data;
        renderTunnelStatus(data);
        updateTunnelIcon();
        addRecentUrl(url);
        input.value = '';
        setTunnelOutput('Tunnel URL saved.');
    } catch (err) {
        setTunnelOutput(String(err), true);
    } finally {
        setTunnelActionState(false);
    }
}

async function tunnelClear() {
    setTunnelActionState(true);
    try {
        const resp = await fetch('/api/tunnel-configure', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ clear: true }),
        });
        const data = await resp.json();
        if (!resp.ok) {
            throw new Error(data.error || 'Failed to clear tunnel URL');
        }

        state.tunnel = data;
        renderTunnelStatus(data);
        updateTunnelIcon();
        setTunnelOutput('Tunnel URL cleared.');
    } catch (err) {
        setTunnelOutput(String(err), true);
    } finally {
        setTunnelActionState(false);
    }
}

async function tunnelStop() {
    setTunnelActionState(true);
    try {
        const resp = await fetch('/api/tunnel-stop', { method: 'POST' });
        const data = await resp.json();
        if (!resp.ok) {
            throw new Error(data.error || 'Failed to stop Cloudflare tunnel');
        }

        state.tunnel = data;
        renderTunnelStatus(data);
        updateTunnelIcon();
        setTunnelOutput('Cloudflare tunnel stopped.');
    } catch (err) {
        setTunnelOutput(String(err), true);
    } finally {
        setTunnelActionState(false);
    }
}

function setTunnelActionState(disabled) {
    ['tpStartBtn', 'tpStopBtn', 'tpSetManualBtn', 'tpClearBtn', 'tpTestBtn', 'tpOpenBtn', 'tpCopyCurlBtn'].forEach((id) => {
        const el = document.getElementById(id);
        if (el) el.disabled = disabled;
    });
}

async function tunnelTest() {
    const result = document.getElementById('tpTestResult');
    const responseBox = document.getElementById('tpTestResponse');
    const btn = document.getElementById('tpTestBtn');

    if (!state.tunnel.active || !state.tunnel.url) {
        setTunnelOutput('Save a tunnel URL before testing.', true);
        return;
    }

    const method = (document.getElementById('tpTestMethod').value || 'GET').toUpperCase();
    const path = normalizeTunnelPath(document.getElementById('tpTestPath').value || '/');
    result.innerHTML = '<span class="ansi-dim" style="font-size:12px">Testing...</span>';
    responseBox.textContent = '';
    responseBox.classList.remove('visible');
    btn.disabled = true;

    try {
        const resp = await fetch('/api/tunnel-test', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ method, path }),
        });
        const data = await resp.json();
        if (!data.reachable) {
            throw new Error(data.error || 'Unreachable');
        }

        let detail = `${esc(String(data.time_ms))}ms`;
        if (data.content_type) detail += ` \u00b7 ${esc(String(data.content_type))}`;
        if (data.final_url && data.final_url !== data.url) detail += ` \u2192 ${esc(String(data.final_url))}`;
        result.innerHTML = `
            <div class="result-alert success">
                <div>
                    <div class="alert-title">Reachable \u2014 HTTP ${esc(String(data.status))}</div>
                    <div class="alert-detail">${detail}</div>
                </div>
            </div>`;
        if (data.body_preview) {
            responseBox.textContent = data.body_preview;
            responseBox.classList.add('visible');
        }
    } catch (err) {
        result.innerHTML = `
            <div class="result-alert error">
                <div>
                    <div class="alert-title">Unreachable</div>
                    <div class="alert-detail">${esc(String(err))}</div>
                </div>
            </div>`;
    } finally {
        btn.disabled = false;
    }
}

function openTunnelTestUrl() {
    const url = buildTunnelTestUrl(document.getElementById('tpTestPath')?.value || '/');
    if (!url) return;
    window.open(url, '_blank', 'noopener');
}

function copyTunnelCurl(btn) {
    const method = (document.getElementById('tpTestMethod')?.value || 'GET').toUpperCase();
    const path = document.getElementById('tpTestPath')?.value || '/';
    const command = buildTunnelCurl(method, path);
    if (!command) return;
    navigator.clipboard.writeText(command).then(() => {
        const original = btn.textContent;
        btn.textContent = 'Copied';
        btn.classList.add('copied');
        setTimeout(() => {
            btn.textContent = original;
            btn.classList.remove('copied');
        }, 1400);
    });
}

function copyTunnelUrl(btn) {
    if (!state.tunnel.url) return;
    navigator.clipboard.writeText(state.tunnel.url).then(() => {
        const original = btn.textContent;
        btn.textContent = 'Copied';
        btn.classList.add('copied');
        setTimeout(() => {
            btn.textContent = original;
            btn.classList.remove('copied');
        }, 1400);
    });
}

function copyTunnelUrlText() {
    if (!state.tunnel.url) return;
    navigator.clipboard.writeText(state.tunnel.url).then(() => {
        const el = document.getElementById('tpUrl');
        const original = el.textContent;
        el.textContent = 'Copied!';
        el.style.color = 'var(--c-green)';
        setTimeout(() => {
            el.textContent = original;
            el.style.color = '';
        }, 1200);
    });
}

async function updateTunnelIcon() {
    try {
        const resp = await fetch('/api/tunnel-status');
        if (!resp.ok) return;
        const data = await resp.json();
        state.tunnel = data;
        const btn = document.getElementById('tunnelIconBtn');
        if (!btn) return;
        btn.classList.toggle('tunnel-live', data.active === true);
        btn.title = data.active ? `Tunnel: ${data.url}` : 'Tunnel';
    } catch (_) {
        // Ignore transient tunnel status failures in the header.
    }
}

/* ── Auto-refresh polling ─────────────────────────────────────── */

let tunnelPollInterval = null;

function startTunnelPolling() {
    stopTunnelPolling();
    tunnelPollInterval = setInterval(() => {
        if (state.tunnelPageVisible) refreshTunnelPage();
    }, 20000);
}

function stopTunnelPolling() {
    if (tunnelPollInterval) {
        clearInterval(tunnelPollInterval);
        tunnelPollInterval = null;
    }
}

/* ── Uptime timer ─────────────────────────────────────────────── */

let tunnelUptimeInterval = null;

function startUptimeTimer() {
    stopUptimeTimer();
    tunnelUptimeInterval = setInterval(updateUptimeDisplay, 1000);
}

function stopUptimeTimer() {
    if (tunnelUptimeInterval) {
        clearInterval(tunnelUptimeInterval);
        tunnelUptimeInterval = null;
    }
}

function updateUptimeDisplay() {
    const el = document.getElementById('tpUptime');
    if (!el || !state.tunnel.active || !state.tunnel.started_at) {
        if (el) el.textContent = '';
        return;
    }
    const started = new Date(state.tunnel.started_at.replace(' UTC', 'Z'));
    const elapsed = Math.floor((Date.now() - started.getTime()) / 1000);
    if (elapsed < 0) { el.textContent = ''; return; }
    const h = Math.floor(elapsed / 3600);
    const m = Math.floor((elapsed % 3600) / 60);
    const s = elapsed % 60;
    let display = '';
    if (h > 0) display = `${h}h ${m}m`;
    else if (m > 0) display = `${m}m ${s}s`;
    else display = `${s}s`;
    el.textContent = `Uptime: ${display}`;
}

/* ── Recent URLs ──────────────────────────────────────────────── */

const RECENT_URLS_KEY = 'devex_tunnel_recent_urls';
const MAX_RECENT_URLS = 5;

function getRecentUrls() {
    try {
        const raw = localStorage.getItem(RECENT_URLS_KEY);
        return raw ? JSON.parse(raw) : [];
    } catch (_) { return []; }
}

function addRecentUrl(url) {
    let urls = getRecentUrls().filter(u => u !== url);
    urls.unshift(url);
    if (urls.length > MAX_RECENT_URLS) urls = urls.slice(0, MAX_RECENT_URLS);
    localStorage.setItem(RECENT_URLS_KEY, JSON.stringify(urls));
    renderRecentUrls();
}

function removeRecentUrl(url) {
    const urls = getRecentUrls().filter(u => u !== url);
    localStorage.setItem(RECENT_URLS_KEY, JSON.stringify(urls));
    renderRecentUrls();
}

function renderRecentUrls() {
    const container = document.getElementById('tpRecentChips');
    if (!container) return;
    const section = document.getElementById('tpRecentSection');
    const urls = getRecentUrls();
    if (urls.length === 0) {
        if (section) section.style.display = 'none';
        return;
    }
    if (section) section.style.display = 'block';
    container.innerHTML = '';
    urls.forEach(url => {
        const chip = document.createElement('span');
        chip.className = 'tp-recent-chip';
        const short = url.replace(/^https?:\/\//, '').replace(/\/$/, '');
        chip.title = url;
        const label = document.createTextNode(short.length > 40 ? short.substring(0, 37) + '...' : short);
        chip.appendChild(label);
        chip.addEventListener('click', () => {
            document.getElementById('tpManualInput').value = url;
            tunnelSetManual();
        });
        const remove = document.createElement('span');
        remove.className = 'remove';
        remove.textContent = '\u00d7';
        remove.addEventListener('click', (e) => {
            e.stopPropagation();
            removeRecentUrl(url);
        });
        chip.appendChild(remove);
        container.appendChild(chip);
    });
}

/* ── Cloudflare logs viewer ───────────────────────────────────── */

async function toggleTunnelLogs() {
    const header = document.getElementById('tpLogsToggle');
    const body = document.getElementById('tpLogsBody');
    const content = document.getElementById('tpLogsContent');
    const isOpen = header.classList.contains('open');

    if (isOpen) {
        header.classList.remove('open');
        body.classList.remove('open');
        return;
    }

    content.textContent = 'Loading...';
    header.classList.add('open');
    body.classList.add('open');

    try {
        const resp = await fetch('/api/tunnel-logs');
        const data = await resp.json();
        content.textContent = data.logs || '(no logs)';
    } catch (_) {
        content.textContent = 'Failed to load logs.';
    }
}

/* ── Browser notification ─────────────────────────────────────── */

function notifyTunnelReady(url) {
    if (!url || !('Notification' in window)) return;
    if (Notification.permission === 'granted') {
        new Notification('Tunnel Ready', { body: url });
    } else if (Notification.permission !== 'denied') {
        Notification.requestPermission().then(perm => {
            if (perm === 'granted') new Notification('Tunnel Ready', { body: url });
        });
    }
}

/* ── Keyboard shortcuts ───────────────────────────────────────── */

document.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && document.activeElement) {
        if (document.activeElement.id === 'tpManualInput') {
            tunnelSetManual();
        } else if (document.activeElement.id === 'tpTestPath') {
            tunnelTest();
        } else if (document.activeElement.id === 'tpTargetInput') {
            tunnelStart();
        }
    }
});
JS;
}
