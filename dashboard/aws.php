<?php

/**
 * AWS reports dashboard page and API.
 */

require_once __DIR__ . '/aws_ui.php';

/**
 * @return array<string, array{label: string, script: string, description: string}>
 */
function getAwsReportRegistry(): array
{
    return [
        'costs' => [
            'label' => 'Costs',
            'script' => 'lib/aws/aws-costs.sh',
            'description' => 'Cost Explorer summary plus AWS inventory counts.',
        ],
        'rightsizing' => [
            'label' => 'Rightsizing',
            'script' => 'lib/aws/aws-rightsizing.sh',
            'description' => 'Utilisation review for RDS, ECS, ALB, NAT, EC2, and logs.',
        ],
        'security' => [
            'label' => 'Security',
            'script' => 'lib/aws/aws-security.sh',
            'description' => 'Read-only security posture scan across common services.',
        ],
        'cli' => [
            'label' => 'AWS CLI',
            'script' => 'lib/aws/aws-cli.sh',
            'description' => 'Run a wrapped AWS CLI or Terraform command with the shared auth loader.',
        ],
    ];
}

function handleAwsDashboardRequest(string $method): void
{
    if ($method === 'POST') {
        handleApiAwsRun();
        return;
    }

    serveAwsDashboardUi();
}

function handleApiAwsRun(): void
{
    $body = getJsonBody();
    $reportId = (string) ($body['report'] ?? '');
    $reports = getAwsReportRegistry();

    if ($reportId === '' || !isset($reports[$reportId])) {
        jsonResponse(['error' => 'Unknown AWS report'], 400);
        return;
    }

    $scriptPath = SCRIPTS_DIR . '/' . $reports[$reportId]['script'];
    if (!is_file($scriptPath)) {
        jsonResponse(['error' => 'Script not found: ' . $reports[$reportId]['script']], 500);
        return;
    }

    try {
        [$args, $displayArgs] = buildAwsReportArgs($reportId, $body);
    } catch (InvalidArgumentException $e) {
        jsonResponse(['error' => $e->getMessage()], 400);
        return;
    }

    $command = array_merge(['/usr/bin/env', 'bash', $scriptPath], $args);
    $commandLabel = 'bash ' . $reports[$reportId]['script'];
    if ($displayArgs !== []) {
        $commandLabel .= ' ' . implode(' ', array_map(static fn (string $arg): string => escapeshellarg($arg), $displayArgs));
    }

    $start = microtime(true);

    // Capture stdout and stderr in separate pipes and read both concurrently
    // to avoid the classic deadlock where one pipe buffer fills while we
    // block on the other.
    $descriptors = [
        1 => ['pipe', 'w'],
        2 => ['pipe', 'w'],
    ];

    $process = proc_open($command, $descriptors, $pipes, SCRIPTS_DIR);
    if (!is_resource($process)) {
        jsonResponse(['error' => 'Failed to start AWS report process'], 500);
        return;
    }

    // Read both pipes concurrently to prevent buffer deadlocks.
    $stdout = '';
    $stderr = '';
    if (is_resource($pipes[1] ?? null)) {
        stream_set_blocking($pipes[1], false);
    }
    if (is_resource($pipes[2] ?? null)) {
        stream_set_blocking($pipes[2], false);
    }
    while (true) {
        $read = [];
        if (is_resource($pipes[1] ?? null) && !feof($pipes[1])) {
            $read[] = $pipes[1];
        }
        if (is_resource($pipes[2] ?? null) && !feof($pipes[2])) {
            $read[] = $pipes[2];
        }
        if ($read === []) {
            break;
        }
        $write = null;
        $except = null;
        if (@stream_select($read, $write, $except, 5) === false) {
            break;
        }
        foreach ($read as $stream) {
            $chunk = fread($stream, 8192);
            if ($chunk === false || $chunk === '') {
                continue;
            }
            if ($stream === ($pipes[1] ?? null)) {
                $stdout .= $chunk;
            } else {
                $stderr .= $chunk;
            }
        }
    }

    if (is_resource($pipes[1] ?? null)) {
        fclose($pipes[1]);
    }
    if (is_resource($pipes[2] ?? null)) {
        fclose($pipes[2]);
    }

    $exitCode = proc_close($process);
    $rawOutput = $stdout . $stderr;
    $durationMs = (int) round((microtime(true) - $start) * 1000);
    $plainText = stripAnsiText($rawOutput);

    jsonResponse([
        'report' => $reportId,
        'label' => $reports[$reportId]['label'],
        'command' => $commandLabel,
        'exit_code' => $exitCode,
        'duration_ms' => $durationMs,
        'html' => ansiToHtml($rawOutput),
        'text' => $plainText,
        'summary' => summarizeAwsOutput($plainText, $exitCode),
        'ran_at' => gmdate('Y-m-d H:i:s') . ' UTC',
    ], $exitCode === 0 ? 200 : 422);
}

/**
 * @param array<string, string> $body
 *
 * @return array{0: list<string>, 1: list<string>}
 */
function buildAwsReportArgs(string $reportId, array $body): array
{
    return match ($reportId) {
        'costs' => buildAwsCostArgs($body),
        'rightsizing' => buildAwsRightsizingArgs($body),
        'security' => [[], []],
        'cli' => buildAwsCliArgs($body),
        default => throw new InvalidArgumentException('Unsupported AWS report'),
    };
}

/**
 * @param array<string, string> $body
 *
 * @return array{0: list<string>, 1: list<string>}
 */
function buildAwsCostArgs(array $body): array
{
    $args = [];
    $display = [];

    $start = trim((string) ($body['start_month'] ?? ''));
    $end = trim((string) ($body['end_month'] ?? ''));

    if ($start !== '') {
        $args[] = '--start';
        $args[] = $start;
        $display[] = '--start';
        $display[] = $start;
    }

    if ($end !== '') {
        $args[] = '--end';
        $args[] = $end;
        $display[] = '--end';
        $display[] = $end;
    }

    return [$args, $display];
}

/**
 * @param array<string, string> $body
 *
 * @return array{0: list<string>, 1: list<string>}
 */
function buildAwsRightsizingArgs(array $body): array
{
    $days = trim((string) ($body['days'] ?? '7'));
    if ($days === '') {
        $days = '7';
    }

    return [['--days', $days], ['--days', $days]];
}

/**
 * @param array<string, string> $body
 *
 * @return array{0: list<string>, 1: list<string>}
 */
function buildAwsCliArgs(array $body): array
{
    $command = trim((string) ($body['command'] ?? ''));
    if ($command === '') {
        throw new InvalidArgumentException('AWS CLI command is required');
    }

    $parts = splitCommandString($command);
    if ($parts === []) {
        throw new InvalidArgumentException('AWS CLI command is required');
    }

    if (count($parts) > 64) {
        throw new InvalidArgumentException('AWS CLI command is too long');
    }

    return [$parts, $parts];
}

/**
 * @return list<string>
 */
function splitCommandString(string $command): array
{
    $tokens = [];
    $length = strlen($command);
    $buffer = '';
    $quote = null;

    for ($i = 0; $i < $length; $i++) {
        $char = $command[$i];

        if ($quote !== null) {
            if ($char === '\\' && $quote === '"' && $i + 1 < $length) {
                $i++;
                $buffer .= $command[$i];
                continue;
            }

            if ($char === $quote) {
                $quote = null;
                continue;
            }

            $buffer .= $char;
            continue;
        }

        if ($char === '"' || $char === "'") {
            $quote = $char;
            continue;
        }

        if (ctype_space($char)) {
            if ($buffer !== '') {
                $tokens[] = $buffer;
                $buffer = '';
            }
            continue;
        }

        if ($char === '\\' && $i + 1 < $length) {
            $i++;
            $buffer .= $command[$i];
            continue;
        }

        $buffer .= $char;
    }

    if ($quote !== null) {
        throw new InvalidArgumentException('Unterminated quote in AWS CLI command');
    }

    if ($buffer !== '') {
        $tokens[] = $buffer;
    }

    return array_values(array_filter($tokens, static fn (string $token): bool => $token !== ''));
}

function stripAnsiText(string $text): string
{
    $text = str_replace("\r", '', $text);
    return preg_replace('/\x1b\[[0-9;]*[A-Za-z]/', '', $text) ?? $text;
}

/**
 * @return array<string, int|string>
 */
function summarizeAwsOutput(string $text, int $exitCode): array
{
    $alerts = preg_match_all('/(^|\s)(\[ERROR\]|✗)/mu', $text) ?: 0;
    $warnings = preg_match_all('/(^|\s)(\[WARN\]|⚠)/mu', $text) ?: 0;
    $oks = preg_match_all('/(^|\s)(\[OK\]|✓)/mu', $text) ?: 0;

    $headline = $exitCode === 0 ? 'Completed successfully' : 'Completed with errors';

    if (preg_match('/([0-9]+ findings.*)$/mi', $text, $matches) === 1) {
        $headline = trim($matches[1]);
    } elseif (preg_match('/(No security issues found!|No issues found .*|No cost data returned .*|No issues found)/mi', $text, $matches) === 1) {
        $headline = trim($matches[1]);
    }

    return [
        'headline' => $headline,
        'alerts' => $alerts,
        'warnings' => $warnings,
        'oks' => $oks,
    ];
}

/**
 * @return array{
 *   has_env_file: bool,
 *   access_key_preview: string,
 *   secret_preview: string,
 *   has_secret: bool,
 *   region: string,
 *   saved_at: string|null
 * }
 */
function getAwsEnvSummary(): array
{
    $envFilePath = SCRIPTS_DIR . '/.env';
    $values = [
        'AWS_ACCESS_KEY_ID' => '',
        'AWS_SECRET_ACCESS_KEY' => '',
        'AWS_DEFAULT_REGION' => '',
    ];

    if (is_file($envFilePath)) {
        $lines = file($envFilePath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        if (is_array($lines)) {
            foreach ($lines as $line) {
                $trimmed = trim($line);
                if ($trimmed === '' || str_starts_with($trimmed, '#') || !str_contains($trimmed, '=')) {
                    continue;
                }

                [$key, $value] = array_map('trim', explode('=', $trimmed, 2));
                if (!array_key_exists($key, $values)) {
                    continue;
                }

                $unquoted = trim($value, "\"'");
                $values[$key] = $unquoted;
            }
        }
    }

    foreach (array_keys($values) as $key) {
        if ($values[$key] === '') {
            $envValue = getenv($key);
            if (is_string($envValue) && $envValue !== '') {
                $values[$key] = $envValue;
            }
        }
    }

    $accessKey = $values['AWS_ACCESS_KEY_ID'];
    $secretKey = $values['AWS_SECRET_ACCESS_KEY'];

    if ($accessKey === '') {
        $accessKeyPreview = 'Not configured';
    } elseif (strlen($accessKey) <= 10) {
        $accessKeyPreview = str_repeat('*', strlen($accessKey));
    } else {
        $accessKeyPreview = substr($accessKey, 0, 6) . str_repeat('*', max(4, strlen($accessKey) - 10)) . substr($accessKey, -4);
    }

    $secretPreview = $secretKey === '' ? 'Not configured' : str_repeat('*', 24);
    $savedAt = is_file($envFilePath) ? date('d/m/Y, g:i:s a', (int) filemtime($envFilePath)) : null;

    return [
        'has_env_file' => is_file($envFilePath),
        'access_key_preview' => $accessKeyPreview,
        'secret_preview' => $secretPreview,
        'has_secret' => $secretKey !== '',
        'region' => $values['AWS_DEFAULT_REGION'] !== '' ? $values['AWS_DEFAULT_REGION'] : 'Not configured',
        'saved_at' => $savedAt,
    ];
}

/**
 * Legacy AWS dashboard HTML renderer — no longer used.
 *
 * The router calls serveAwsDashboardUi() (from aws_ui.php) instead.
 * This function is retained temporarily for reference during the
 * transition and will be removed in a future release.
 *
 * @deprecated Use serveAwsDashboardUi() instead.
 */
function serveAwsDashboardHtml(): void
{
    // Delegate to the active UI implementation.
    serveAwsDashboardUi();
    return;

    // @codeCoverageIgnoreStart — dead code below, kept for reference only.
    /** @phpstan-ignore deadCode.unreachable */
    header('Content-Type: text/html; charset=UTF-8');

    $projectTitle = htmlspecialchars(PROJECT_NAME, ENT_QUOTES);
    $envLabel = htmlspecialchars(ENV_NAME, ENT_QUOTES);
    $envFilePath = SCRIPTS_DIR . '/.env';
    $envExamplePath = SCRIPTS_DIR . '/.env.example';
    $hasEnvFile = is_file($envFilePath);
    $reportsJson = json_encode(getAwsReportRegistry(), JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    if (!is_string($reportsJson)) {
        $reportsJson = '{}';
    }

    echo '<!DOCTYPE html>';
    echo '<html lang="en" data-theme="light">';
    echo '<head>';
    echo '<meta charset="UTF-8">';
    echo '<meta name="viewport" content="width=device-width, initial-scale=1.0">';
    echo '<title>AWS Reports - ' . $projectTitle . '</title>';
    echo '<script>document.documentElement.setAttribute("data-theme", localStorage.getItem("devex_dash_theme") || "light");</script>';
    echo '<link rel="preconnect" href="https://fonts.googleapis.com">';
    echo '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>';
    echo '<link href="https://fonts.googleapis.com/css2?family=Manrope:wght@500;600;700;800&family=IBM+Plex+Mono:wght@400;500&display=swap" rel="stylesheet">';
    echo <<<'CSS'
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body { min-height: 100%; }
body {
    font-family: "Manrope", "Segoe UI", sans-serif;
    background:
        radial-gradient(circle at top left, rgba(34,197,94,0.14), transparent 28%),
        radial-gradient(circle at top right, rgba(59,130,246,0.12), transparent 26%),
        linear-gradient(180deg, #f5f7fb 0%, #edf2f7 100%);
    color: #16202a;
}
[data-theme="dark"] body {
    background:
        radial-gradient(circle at top left, rgba(34,197,94,0.18), transparent 22%),
        radial-gradient(circle at top right, rgba(59,130,246,0.12), transparent 24%),
        linear-gradient(180deg, #10151d 0%, #151c26 100%);
    color: #eef4fb;
}
:root, [data-theme="light"] {
    --bg-panel: rgba(255,255,255,0.82);
    --bg-soft: rgba(255,255,255,0.62);
    --border: rgba(15,23,42,0.08);
    --text-main: #16202a;
    --text-muted: #5f6c7a;
    --accent: #0f766e;
    --accent-strong: #0b5f58;
    --good: #15803d;
    --warn: #b45309;
    --bad: #b91c1c;
    --mono-bg: #f7fafc;
    --shadow: 0 28px 80px rgba(15,23,42,0.08);
}
[data-theme="dark"] {
    --bg-panel: rgba(16,22,30,0.86);
    --bg-soft: rgba(20,28,38,0.72);
    --border: rgba(148,163,184,0.14);
    --text-main: #eef4fb;
    --text-muted: #93a3b5;
    --accent: #34d399;
    --accent-strong: #10b981;
    --good: #86efac;
    --warn: #fbbf24;
    --bad: #fca5a5;
    --mono-bg: #0f1720;
    --shadow: 0 32px 96px rgba(0,0,0,0.28);
}
.page {
    width: min(1320px, calc(100% - 32px));
    margin: 24px auto 40px;
}
.hero {
    padding: 28px;
    border-radius: 28px;
    background: var(--bg-panel);
    border: 1px solid var(--border);
    box-shadow: var(--shadow);
    backdrop-filter: blur(18px);
}
.hero-top {
    display: flex;
    justify-content: space-between;
    gap: 16px;
    align-items: flex-start;
}
.hero-title h1 {
    font-size: clamp(2rem, 4vw, 3rem);
    line-height: 0.95;
    letter-spacing: -0.04em;
    margin-bottom: 10px;
}
.hero-title p {
    max-width: 720px;
    color: var(--text-muted);
    font-size: 0.98rem;
    line-height: 1.6;
}
.hero-actions {
    display: flex;
    align-items: center;
    gap: 10px;
    flex-wrap: wrap;
}
.ghost-link, .theme-toggle {
    border: 1px solid var(--border);
    background: var(--bg-soft);
    color: var(--text-main);
    text-decoration: none;
    padding: 10px 14px;
    border-radius: 999px;
    font-weight: 700;
    cursor: pointer;
}
.hero-meta {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
    gap: 14px;
    margin-top: 22px;
}
.meta-card {
    border: 1px solid var(--border);
    border-radius: 18px;
    padding: 16px 18px;
    background: var(--bg-soft);
}
.meta-card strong {
    display: block;
    font-size: 0.75rem;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    color: var(--text-muted);
    margin-bottom: 8px;
}
.meta-card span, .meta-card code {
    font-size: 0.98rem;
    color: var(--text-main);
}
.meta-card code {
    font-family: "IBM Plex Mono", monospace;
    background: transparent;
}
.status-pill {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 7px 12px;
    border-radius: 999px;
    font-weight: 800;
}
.status-ok {
    background: rgba(21,128,61,0.12);
    color: var(--good);
}
.status-missing {
    background: rgba(185,28,28,0.12);
    color: var(--bad);
}
.layout {
    display: grid;
    grid-template-columns: 320px minmax(0, 1fr);
    gap: 20px;
    margin-top: 20px;
}
.nav-panel, .content-panel {
    border-radius: 26px;
    background: var(--bg-panel);
    border: 1px solid var(--border);
    box-shadow: var(--shadow);
    backdrop-filter: blur(18px);
}
.nav-panel {
    padding: 18px;
}
.nav-panel h2 {
    font-size: 0.86rem;
    text-transform: uppercase;
    letter-spacing: 0.14em;
    color: var(--text-muted);
    margin-bottom: 14px;
}
.tab-list {
    display: grid;
    gap: 10px;
}
.tab-btn {
    width: 100%;
    text-align: left;
    border: 1px solid var(--border);
    border-radius: 18px;
    background: var(--bg-soft);
    padding: 16px 18px;
    cursor: pointer;
    transition: transform 0.15s ease, border-color 0.15s ease, background 0.15s ease;
}
.tab-btn.live {
    border-color: rgba(15,118,110,0.32);
    box-shadow: inset 0 0 0 1px rgba(15,118,110,0.12);
}
.tab-btn:hover {
    transform: translateY(-1px);
    border-color: rgba(15,118,110,0.25);
}
.tab-btn.active {
    border-color: rgba(15,118,110,0.38);
    background: linear-gradient(135deg, rgba(15,118,110,0.13), rgba(59,130,246,0.08));
}
.tab-btn strong {
    display: block;
    font-size: 1rem;
    color: var(--text-main);
    margin-bottom: 5px;
}
.tab-btn span {
    display: block;
    color: var(--text-muted);
    line-height: 1.5;
    font-size: 0.9rem;
}
.tab-meta {
    margin-top: 12px;
    display: flex;
    gap: 8px;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
}
.tab-status {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    border-radius: 999px;
    padding: 5px 10px;
    font-size: 0.74rem;
    font-weight: 800;
    letter-spacing: 0.04em;
    text-transform: uppercase;
}
.tab-status.ok {
    background: rgba(21,128,61,0.12);
    color: var(--good);
}
.tab-status.bad {
    background: rgba(185,28,28,0.12);
    color: var(--bad);
}
.tab-status.live {
    background: rgba(15,118,110,0.14);
    color: var(--accent-strong);
}
.tab-time {
    font-size: 0.75rem;
    color: var(--text-muted);
}
.content-panel {
    padding: 20px;
    min-width: 0;
}
.report-toolbar {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    align-items: flex-start;
    margin-bottom: 16px;
}
.report-toolbar h2 {
    font-size: 1.6rem;
    letter-spacing: -0.03em;
    margin-bottom: 6px;
}
.report-toolbar p {
    color: var(--text-muted);
    line-height: 1.6;
}
.run-btn {
    border: none;
    border-radius: 16px;
    background: linear-gradient(135deg, var(--accent), #2563eb);
    color: white;
    font-weight: 800;
    font-size: 0.95rem;
    padding: 14px 20px;
    cursor: pointer;
    min-width: 132px;
}
.run-btn-content {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 10px;
}
.run-btn-copy {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
}
.run-btn-label {
    font-size: 0.95rem;
    line-height: 1.1;
}
.run-btn-sub {
    font-size: 0.74rem;
    opacity: 0.88;
    letter-spacing: 0.06em;
    text-transform: uppercase;
}
.run-btn:disabled {
    opacity: 0.6;
    cursor: wait;
}
.spinner {
    width: 14px;
    height: 14px;
    border-radius: 50%;
    border: 2px solid currentColor;
    border-right-color: transparent;
    animation: spin 0.8s linear infinite;
    flex-shrink: 0;
}
.spinner.inline {
    width: 12px;
    height: 12px;
    border-width: 1.8px;
}
@keyframes spin {
    to { transform: rotate(360deg); }
}
.controls {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap: 14px;
    margin-bottom: 18px;
}
.control-card {
    border: 1px solid var(--border);
    border-radius: 20px;
    padding: 16px;
    background: var(--bg-soft);
}
.control-card label {
    display: block;
    font-size: 0.78rem;
    text-transform: uppercase;
    letter-spacing: 0.12em;
    color: var(--text-muted);
    margin-bottom: 10px;
}
.control-card input, .control-card textarea, .control-card select {
    width: 100%;
    border: 1px solid var(--border);
    border-radius: 14px;
    background: rgba(255,255,255,0.75);
    color: #0f172a;
    padding: 12px 13px;
    font: inherit;
}
[data-theme="dark"] .control-card input,
[data-theme="dark"] .control-card textarea,
[data-theme="dark"] .control-card select {
    background: rgba(15,23,32,0.92);
    color: #eef4fb;
}
.control-card textarea {
    min-height: 96px;
    resize: vertical;
    font-family: "IBM Plex Mono", monospace;
    font-size: 0.92rem;
}
.control-card small {
    display: block;
    color: var(--text-muted);
    margin-top: 10px;
    line-height: 1.5;
}
.quick-actions {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-top: 10px;
}
.chip {
    border: 1px solid var(--border);
    background: transparent;
    color: var(--text-main);
    border-radius: 999px;
    padding: 7px 11px;
    font-size: 0.82rem;
    font-weight: 700;
    cursor: pointer;
}
.summary-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
    gap: 12px;
    margin-bottom: 18px;
}
.summary-card {
    border: 1px solid var(--border);
    border-radius: 18px;
    padding: 14px 16px;
    background: var(--bg-soft);
}
.summary-card strong {
    display: block;
    font-size: 0.76rem;
    text-transform: uppercase;
    letter-spacing: 0.12em;
    color: var(--text-muted);
    margin-bottom: 8px;
}
.summary-card span {
    font-size: 1.12rem;
    font-weight: 800;
}
.summary-card.good span { color: var(--good); }
.summary-card.warn span { color: var(--warn); }
.summary-card.bad span { color: var(--bad); }
.run-banner {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 14px;
    padding: 14px 18px;
    margin-bottom: 18px;
    border: 1px solid rgba(15,118,110,0.22);
    border-radius: 18px;
    background: linear-gradient(135deg, rgba(15,118,110,0.1), rgba(37,99,235,0.06));
}
.run-banner-copy {
    display: flex;
    align-items: center;
    gap: 12px;
    min-width: 0;
}
.run-banner-text {
    min-width: 0;
}
.run-banner-text strong {
    display: block;
    font-size: 0.9rem;
    margin-bottom: 3px;
}
.run-banner-text span {
    display: block;
    font-family: "IBM Plex Mono", monospace;
    font-size: 0.8rem;
    color: var(--text-muted);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}
.run-banner-time {
    font-size: 0.86rem;
    font-weight: 800;
    white-space: nowrap;
}
.output-shell {
    border: 1px solid var(--border);
    border-radius: 22px;
    overflow: hidden;
    background: var(--mono-bg);
}
.shell-header {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    align-items: center;
    padding: 14px 18px;
    border-bottom: 1px solid var(--border);
    background: rgba(15,23,42,0.03);
}
[data-theme="dark"] .shell-header {
    background: rgba(255,255,255,0.03);
}
.shell-header code {
    font-family: "IBM Plex Mono", monospace;
    font-size: 0.86rem;
    word-break: break-word;
}
.shell-meta {
    color: var(--text-muted);
    font-size: 0.86rem;
    white-space: nowrap;
}
.shell-output {
    padding: 18px;
    overflow: auto;
    max-height: 820px;
    font-family: "IBM Plex Mono", monospace;
    font-size: 0.88rem;
    line-height: 1.55;
    white-space: pre-wrap;
    word-break: break-word;
}
.empty-state {
    border: 1px dashed var(--border);
    border-radius: 22px;
    padding: 42px 28px;
    text-align: center;
    color: var(--text-muted);
    background: var(--bg-soft);
}
.ansi-bold { font-weight: 700; }
.ansi-dim { opacity: 0.65; }
.ansi-black { color: #64748b; }
.ansi-red { color: var(--bad); }
.ansi-green { color: var(--good); }
.ansi-yellow { color: var(--warn); }
.ansi-blue { color: #60a5fa; }
.ansi-magenta { color: #c084fc; }
.ansi-cyan { color: #22d3ee; }
.ansi-white { color: var(--text-main); }
@media (max-width: 1040px) {
    .layout { grid-template-columns: 1fr; }
}
@media (max-width: 720px) {
    .page { width: min(100% - 20px, 1320px); margin-top: 12px; }
    .hero, .nav-panel, .content-panel { border-radius: 22px; }
    .hero-top, .report-toolbar { flex-direction: column; }
    .run-btn { width: 100%; }
}
</style>
CSS;
    echo '</head>';
    echo '<body>';
    echo '<div class="page">';
    echo '<section class="hero">';
    echo '  <div class="hero-top">';
    echo '    <div class="hero-title">';
    echo '      <h1>AWS Reports</h1>';
    echo '      <p>Run the AWS wrapper, cost summary, rightsizing audit, and security scan from one page. Each tab keeps its own latest result so you can compare reports without losing output.</p>';
    echo '    </div>';
    echo '    <div class="hero-actions">';
    echo '      <a class="ghost-link" href="/">Main Dashboard</a>';
    echo '      <button class="theme-toggle" type="button" onclick="toggleTheme()">Toggle Theme</button>';
    echo '    </div>';
    echo '  </div>';
    echo '  <div class="hero-meta">';
    echo '    <div class="meta-card"><strong>Project</strong><span>' . $projectTitle . '</span></div>';
    echo '    <div class="meta-card"><strong>Environment</strong><span>' . $envLabel . '</span></div>';
    echo '    <div class="meta-card"><strong>AWS Env File</strong><span class="status-pill ' . ($hasEnvFile ? 'status-ok' : 'status-missing') . '">' . ($hasEnvFile ? '.env present' : '.env missing') . '</span></div>';
    echo '    <div class="meta-card"><strong>Template</strong><code>' . htmlspecialchars($envExamplePath, ENT_QUOTES) . '</code></div>';
    echo '  </div>';
    echo '</section>';
    echo '<section class="layout">';
    echo '  <aside class="nav-panel">';
    echo '    <h2>Reports</h2>';
    echo '    <div class="tab-list" id="tabList"></div>';
    echo '  </aside>';
    echo '  <main class="content-panel">';
    echo '    <div id="reportView"></div>';
    echo '  </main>';
    echo '</section>';
    echo '</div>';
    echo '<script>';
    echo 'const AWS_REPORTS = ' . $reportsJson . ';';
    echo <<<'JS'
const AWS_STATE_STORAGE_KEY = 'devex_dash_aws_reports_v1';
const awsState = {
    active: 'costs',
    running: false,
    runningReport: null,
    startedAt: 0,
    timerId: null,
    pendingCommand: '',
    results: {},
    inputs: {
        costs: { start_month: '', end_month: '' },
        rightsizing: { days: '7' },
        cli: { command: 'sts get-caller-identity' },
    },
};

function toggleTheme() {
    const next = document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', next);
    localStorage.setItem('devex_dash_theme', next);
}

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

function shortenText(value, maxLength = 42) {
    if (!value || value.length <= maxLength) return value || '';
    return `${value.slice(0, maxLength - 1)}…`;
}

function getElapsedMs() {
    return awsState.startedAt ? Date.now() - awsState.startedAt : 0;
}

function serializeAwsState() {
    const results = {};
    for (const [id, result] of Object.entries(awsState.results)) {
        if (!result || typeof result !== 'object') continue;
        results[id] = {
            label: result.label || '',
            command: result.command || '',
            exit_code: Number.isFinite(result.exit_code) ? result.exit_code : 1,
            duration_ms: Number.isFinite(result.duration_ms) ? result.duration_ms : 0,
            html: typeof result.html === 'string' ? result.html : '',
            summary: {
                headline: result.summary?.headline || '',
                alerts: Number.isFinite(result.summary?.alerts) ? result.summary.alerts : 0,
                warnings: Number.isFinite(result.summary?.warnings) ? result.summary.warnings : 0,
                oks: Number.isFinite(result.summary?.oks) ? result.summary.oks : 0,
            },
            ran_at: result.ran_at || '',
        };
    }

    return {
        active: awsState.active,
        inputs: awsState.inputs,
        results,
    };
}

function persistAwsState() {
    try {
        localStorage.setItem(AWS_STATE_STORAGE_KEY, JSON.stringify(serializeAwsState()));
    } catch (_) {
        // Ignore storage failures.
    }
}

function restoreAwsState() {
    try {
        const raw = localStorage.getItem(AWS_STATE_STORAGE_KEY);
        if (!raw) return;
        const parsed = JSON.parse(raw);
        if (!parsed || typeof parsed !== 'object') return;

        if (typeof parsed.active === 'string' && AWS_REPORTS[parsed.active]) {
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
    } catch (_) {
        // Ignore corrupt cache data.
    }
}

function startRunTimer() {
    stopRunTimer();
    awsState.timerId = window.setInterval(updateRunningIndicators, 1000);
}

function stopRunTimer() {
    if (awsState.timerId !== null) {
        window.clearInterval(awsState.timerId);
        awsState.timerId = null;
    }
}

function updateRunningIndicators() {
    if (!awsState.running || !awsState.runningReport) return;
    const elapsed = formatElapsed(getElapsedMs());

    const runButtonSub = document.getElementById('runButtonSub');
    if (runButtonSub) {
        runButtonSub.textContent = elapsed;
    }

    const bannerElapsed = document.getElementById('runBannerElapsed');
    if (bannerElapsed) {
        bannerElapsed.textContent = elapsed;
    }

    const tabTimer = document.getElementById(`tabStatusTimer-${awsState.runningReport}`);
    if (tabTimer) {
        tabTimer.textContent = elapsed;
    }
}

function renderTabs() {
    const tabList = document.getElementById('tabList');
    tabList.innerHTML = Object.entries(AWS_REPORTS).map(([id, report]) => {
        const result = awsState.results[id];
        const isRunning = awsState.running && awsState.runningReport === id;
        let metaHtml = '';

        if (isRunning) {
            metaHtml = `
                <div class="tab-meta">
                    <span class="tab-status live">
                        <span class="spinner inline"></span>
                        Running
                        <span id="tabStatusTimer-${id}">${formatElapsed(getElapsedMs())}</span>
                    </span>
                </div>
            `;
        } else if (result) {
            metaHtml = `
                <div class="tab-meta">
                    <span class="tab-status ${result.exit_code === 0 ? 'ok' : 'bad'}">${escapeHtml(shortenText(result.summary.headline, 28))}</span>
                    <span class="tab-time">${escapeHtml(formatRunTimestamp(result.ran_at))}</span>
                </div>
            `;
        }

        return `
            <button class="tab-btn ${awsState.active === id ? 'active' : ''} ${isRunning ? 'live' : ''}" type="button" onclick="setAwsTab('${id}')">
                <strong>${escapeHtml(report.label)}</strong>
                <span>${escapeHtml(report.description)}</span>
                ${metaHtml}
            </button>
        `;
    }).join('');
}

function buildReportControls(reportId) {
    if (reportId === 'costs') {
        return `
            <div class="controls">
                <div class="control-card">
                    <label for="costStartMonth">Start month</label>
                    <input id="costStartMonth" type="month" value="${escapeHtml(awsState.inputs.costs.start_month)}" />
                    <small>Optional. Leave blank to default to the previous month.</small>
                </div>
                <div class="control-card">
                    <label for="costEndMonth">End month</label>
                    <input id="costEndMonth" type="month" value="${escapeHtml(awsState.inputs.costs.end_month)}" />
                    <small>Optional. Leave blank to use the current month to date when no range is set.</small>
                </div>
            </div>
        `;
    }

    if (reportId === 'rightsizing') {
        return `
            <div class="controls">
                <div class="control-card">
                    <label for="rightsizingDays">Lookback days</label>
                    <select id="rightsizingDays">
                        <option value="7" ${awsState.inputs.rightsizing.days === '7' ? 'selected' : ''}>7 days</option>
                        <option value="14" ${awsState.inputs.rightsizing.days === '14' ? 'selected' : ''}>14 days</option>
                        <option value="30" ${awsState.inputs.rightsizing.days === '30' ? 'selected' : ''}>30 days</option>
                        <option value="60" ${awsState.inputs.rightsizing.days === '60' ? 'selected' : ''}>60 days</option>
                    </select>
                    <small>Longer windows reduce noise but make the run slower.</small>
                </div>
            </div>
        `;
    }

    if (reportId === 'cli') {
        return `
            <div class="controls">
                <div class="control-card" style="grid-column: 1 / -1">
                    <label for="awsCliCommand">AWS CLI or Terraform command</label>
                    <textarea id="awsCliCommand" spellcheck="false" placeholder="sts get-caller-identity">${escapeHtml(awsState.inputs.cli.command)}</textarea>
                    <small>Do not prefix with <code>bash</code>. You can enter AWS subcommands directly, or start with <code>terraform</code>.</small>
                    <div class="quick-actions">
                        <button class="chip" type="button" onclick="setAwsCliCommand('sts get-caller-identity')">Identity</button>
                        <button class="chip" type="button" onclick="setAwsCliCommand('s3 ls')">Buckets</button>
                        <button class="chip" type="button" onclick="setAwsCliCommand('ec2 describe-regions --all-regions')">Regions</button>
                        <button class="chip" type="button" onclick="setAwsCliCommand('terraform version')">Terraform Version</button>
                    </div>
                </div>
            </div>
        `;
    }

    return `
        <div class="controls">
            <div class="control-card">
                <label>Read-only scan</label>
                <small>This report has no user inputs. It will query AWS and return a full security findings summary.</small>
            </div>
        </div>
    `;
}

function renderReportView() {
    const report = AWS_REPORTS[awsState.active];
    const result = awsState.results[awsState.active] || null;
    const isRunningHere = awsState.running && awsState.runningReport === awsState.active;
    const isBackgroundRun = awsState.running && awsState.runningReport !== awsState.active;
    const runningLabel = awsState.runningReport ? (AWS_REPORTS[awsState.runningReport]?.label || 'Report') : 'Report';
    const runButtonLabel = isRunningHere ? 'Running' : (isBackgroundRun ? `${runningLabel} Running` : 'Run Report');
    const runButtonSub = awsState.running ? formatElapsed(getElapsedMs()) : (result ? `Last ${formatRunTimestamp(result.ran_at)}` : 'Live AWS query');
    const runBannerHtml = awsState.running ? `
        <div class="run-banner">
            <div class="run-banner-copy">
                <span class="spinner"></span>
                <div class="run-banner-text">
                    <strong>${isRunningHere ? 'Running this report now' : `${escapeHtml(runningLabel)} is running in the background`}</strong>
                    <span>${escapeHtml(awsState.pendingCommand || (awsState.runningReport ? `bash ${AWS_REPORTS[awsState.runningReport].script}` : 'Preparing command'))}</span>
                </div>
            </div>
            <div class="run-banner-time" id="runBannerElapsed">${formatElapsed(getElapsedMs())}</div>
        </div>
    ` : '';
    const outputHtml = result
        ? `
            <div class="summary-grid">
                <div class="summary-card">
                    <strong>Status</strong>
                    <span>${escapeHtml(result.summary.headline)}</span>
                </div>
                <div class="summary-card ${result.exit_code === 0 ? 'good' : 'bad'}">
                    <strong>Exit Code</strong>
                    <span>${result.exit_code}</span>
                </div>
                <div class="summary-card ${result.summary.alerts > 0 ? 'bad' : 'good'}">
                    <strong>Alerts</strong>
                    <span>${result.summary.alerts}</span>
                </div>
                <div class="summary-card ${result.summary.warnings > 0 ? 'warn' : ''}">
                    <strong>Warnings</strong>
                    <span>${result.summary.warnings}</span>
                </div>
                <div class="summary-card good">
                    <strong>Checks OK</strong>
                    <span>${result.summary.oks}</span>
                </div>
                <div class="summary-card">
                    <strong>Duration</strong>
                    <span>${formatDuration(result.duration_ms)}</span>
                </div>
                <div class="summary-card">
                    <strong>Last Run</strong>
                    <span>${escapeHtml(formatRunTimestamp(result.ran_at))}</span>
                </div>
            </div>
            <div class="output-shell">
                <div class="shell-header">
                    <code>${escapeHtml(result.command)}</code>
                    <span class="shell-meta">${escapeHtml(result.ran_at)}</span>
                </div>
                <div class="shell-output">${result.html}</div>
            </div>
        `
        : `
            <div class="empty-state">
                <p>No output yet for <strong>${escapeHtml(report.label)}</strong>.</p>
                <p style="margin-top: 8px;">Run the report to capture a formatted result here.</p>
            </div>
        `;

    document.getElementById('reportView').innerHTML = `
        <div class="report-toolbar">
            <div>
                <h2>${escapeHtml(report.label)}</h2>
                <p>${escapeHtml(report.description)}</p>
            </div>
            <button class="run-btn" type="button" id="runBtn" onclick="runAwsReport()" ${awsState.running ? 'disabled' : ''}>
                <span class="run-btn-content">
                    ${awsState.running ? '<span class="spinner"></span>' : ''}
                    <span class="run-btn-copy">
                        <span class="run-btn-label">${escapeHtml(runButtonLabel)}</span>
                        <span class="run-btn-sub" id="runButtonSub">${escapeHtml(runButtonSub)}</span>
                    </span>
                </span>
            </button>
        </div>
        ${buildReportControls(awsState.active)}
        ${runBannerHtml}
        ${outputHtml}
    `;

    updateRunningIndicators();
}

function setAwsTab(reportId) {
    awsState.active = reportId;
    persistAwsState();
    renderTabs();
    renderReportView();
}

function setAwsCliCommand(command) {
    awsState.inputs.cli.command = command;
    persistAwsState();
    const input = document.getElementById('awsCliCommand');
    if (input) {
        input.value = command;
        input.focus();
    }
}

function getReportPayload(reportId) {
    if (reportId === 'costs') {
        const startInput = document.getElementById('costStartMonth');
        const endInput = document.getElementById('costEndMonth');
        awsState.inputs.costs.start_month = startInput ? startInput.value : '';
        awsState.inputs.costs.end_month = endInput ? endInput.value : '';
        persistAwsState();
        return { ...awsState.inputs.costs };
    }

    if (reportId === 'rightsizing') {
        const select = document.getElementById('rightsizingDays');
        awsState.inputs.rightsizing.days = select ? select.value : '7';
        persistAwsState();
        return { ...awsState.inputs.rightsizing };
    }

    if (reportId === 'cli') {
        const textarea = document.getElementById('awsCliCommand');
        awsState.inputs.cli.command = textarea ? textarea.value : '';
        persistAwsState();
        return { ...awsState.inputs.cli };
    }

    return {};
}

async function runAwsReport() {
    if (awsState.running) return;

    const payload = {
        report: awsState.active,
        ...getReportPayload(awsState.active),
    };

    awsState.running = true;
    awsState.runningReport = awsState.active;
    awsState.startedAt = Date.now();
    awsState.pendingCommand = payload.command ? payload.command : `bash ${AWS_REPORTS[awsState.active].script}`;
    startRunTimer();
    renderTabs();
    renderReportView();

    try {
        const response = await fetch('/api/aws/run', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
        });
        const data = await response.json();

        if (!response.ok) {
            throw new Error(data.error || 'AWS report failed');
        }

        awsState.results[awsState.active] = data;
        persistAwsState();
    } catch (error) {
        awsState.results[awsState.active] = {
            label: AWS_REPORTS[awsState.active].label,
            command: 'request failed',
            exit_code: 1,
            duration_ms: 0,
            ran_at: new Date().toISOString(),
            html: `<span class="ansi-red ansi-bold">Error:</span> ${escapeHtml(String(error))}`,
            summary: {
                headline: 'Request failed',
                alerts: 1,
                warnings: 0,
                oks: 0,
            },
        };
        persistAwsState();
    } finally {
        awsState.running = false;
        awsState.runningReport = null;
        awsState.startedAt = 0;
        awsState.pendingCommand = '';
        stopRunTimer();
        persistAwsState();
        renderTabs();
        renderReportView();
    }
}

restoreAwsState();
renderTabs();
renderReportView();
JS;
    echo '</script>';
    echo '</body>';
    echo '</html>';
}
