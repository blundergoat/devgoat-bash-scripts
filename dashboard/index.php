<?php
/**
 * DevEx Dashboard - index.php
 *
 * Web UI for running project scripts from the browser.
 * Local development only - never expose to the network.
 *
 * This file is the single entry point for the PHP built-in server.
 * All requests route through here: API endpoints for script execution,
 * SSE streaming, and process management, plus the HTML frontend.
 *
 * Architecture:
 *   index.php      - router, API handlers, process management, ANSI→HTML
 *   frontend.php   - single-page HTML/CSS/JS UI (included by index.php)
 *   config.php     - script registry (categories + commands whitelist)
 *   start-dev.sh   - launcher script (sets env vars, starts PHP server)
 *
 * Usage:
 *   ./dashboard/start-dev.sh
 *
 * Then open http://localhost:8899
 */

// Security: reject non-localhost requests before any routing or script execution
$remote = $_SERVER['REMOTE_ADDR'] ?? '';
if (!in_array($remote, ['127.0.0.1', '::1'], true)) {
    http_response_code(403);
    echo 'Forbidden — dashboard is local-dev only';
    exit(1);
}

/**
 * Check posix extension (required for process management)
 */
if (!extension_loaded('posix')) {
    http_response_code(500);
    echo 'posix extension required — install php-posix or enable it in php.ini';
    exit(1);
}

/**
 * Constants
 *
 * Guards: each define() is wrapped in if (!defined(...)) to prevent
 * "constant already defined" errors when phpstan-bootstrap.php has
 * already declared them during static analysis.
 */

$projectName = getenv('PROJECT_NAME') ?: 'DevEx Dashboard';

$scriptsDir = getenv('SCRIPTS_DIR') ?: dirname(__DIR__);
if (!defined('SCRIPTS_DIR')) {
    define('SCRIPTS_DIR', $scriptsDir);
}
if (!defined('PROJECT_ROOT')) {
    define('PROJECT_ROOT', dirname(SCRIPTS_DIR));
}

// Slug the project name for use in the temp dir path (e.g. "My Project" → "my-project")
$sanitizedProjectSlug = preg_replace('/[^a-zA-Z0-9_-]/', '-', strtolower($projectName)) ?? 'dashboard';
if (!defined('TMP_DIR')) {
    define('TMP_DIR', '/tmp/' . $sanitizedProjectSlug . '-dashboard');
}
if (!defined('SENTINEL')) {
    define('SENTINEL', '__DASHBOARD_DONE__');
}
if (!defined('TIMINGS_FILE')) {
    define('TIMINGS_FILE', TMP_DIR . '/timings.json');
}

// Environment name: from env var, or infer from grandparent directory name
// (e.g. /srv/deploy/my-project → "deploy"), or fall back to 'local'
$envName = getenv('ENV_NAME') ?: basename(dirname(PROJECT_ROOT)) ?: 'local';
if (!defined('ENV_NAME')) {
    define('ENV_NAME', $envName);
}
if (!defined('PROJECT_NAME')) {
    define('PROJECT_NAME', $projectName);
}

// Site URL: from env var, or empty (hides the link in the UI)
if (!defined('SITE_URL')) {
    define('SITE_URL', getenv('SITE_URL') ?: '');
}

// Ensure temp directory exists
if (!is_dir(TMP_DIR)) {
    mkdir(TMP_DIR, 0755, true);
}

// Detect if config.php is the unedited example (auto-copied by start-dev.sh).
// When true, the UI shows a banner prompting the user to customize it.
$configFile = __DIR__ . '/config.php';
$exampleFile = __DIR__ . '/config.example.php';
$isExampleConfig = file_exists($exampleFile) && file_get_contents($configFile) === file_get_contents($exampleFile);
if (!defined('IS_EXAMPLE_CONFIG')) {
    define('IS_EXAMPLE_CONFIG', $isExampleConfig);
}

/**
 * Load the script registry from config.php.
 *
 * Returns the full category/script tree that the sidebar renders.
 * Each entry is a category with a 'scripts' array of runnable commands.
 */
function getScriptRegistry(): array // @phpstan-ignore missingType.iterableValue
{
    $config = require __DIR__ . '/config.php';
    return is_array($config) ? $config : [];
}

/**
 * Look up a script entry by ID.
 *
 * Returns null when the ID doesn't match any entry in config.php -
 * this is the whitelist check that prevents running arbitrary commands.
 */
function findScript(string $id): ?array // @phpstan-ignore missingType.iterableValue
{
    foreach (getScriptRegistry() as $cat) {
        foreach ($cat['scripts'] as $script) { // @phpstan-ignore offsetAccess.nonOffsetAccessible, foreach.nonIterable
            if (($script['id'] ?? '') === $id) { // @phpstan-ignore offsetAccess.nonOffsetAccessible
                return $script; // @phpstan-ignore return.type
            }
        }
    }
    return null; // script ID not in whitelist
}

require __DIR__ . '/frontend.php';

/* ============================================================
 * Project path helpers (Phase 2 - WSL Path Selector)
 * ============================================================ */

/**
 * Allowed base directories for project paths. Only paths under these
 * prefixes are accepted - prevents path traversal attacks.
 */
if (!defined('ALLOWED_BASES')) {
    define('ALLOWED_BASES', ['/srv/', '/home/', '/mnt/', '/opt/', '/var/www/']);
}

/**
 * Get known project directories from config.php or DASHBOARD_PROJECTS env var.
 *
 * @return list<string>
 */
function getProjectPaths(): array
{
    $paths = [];

    // From env var (comma-separated)
    $envProjects = getenv('DASHBOARD_PROJECTS');
    if ($envProjects !== false && $envProjects !== '') {
        foreach (explode(',', $envProjects) as $p) {
            $p = trim($p);
            if ($p !== '') {
                $paths[] = $p;
            }
        }
    }

    // From config.php projects array
    $config = require __DIR__ . '/config.php';
    if (is_array($config)) {
        foreach ($config as $entry) {
            if (is_array($entry) && isset($entry['projects']) && is_array($entry['projects'])) {
                foreach ($entry['projects'] as $proj) {
                    if (is_string($proj)) {
                        $paths[] = $proj;
                    }
                }
            }
        }
    }

    return array_values(array_unique($paths));
}

/**
 * Validate and resolve a project path.
 *
 * Returns null when:
 *  - the path is empty (no project selected)
 *  - the directory doesn't exist on disk (realpath fails)
 *  - the resolved path is outside ALLOWED_BASES (prevents path traversal)
 */
function validateProjectPath(string $path): ?string
{
    if ($path === '') {
        return null; // no project selected - use default SCRIPTS_DIR
    }

    $resolved = realpath($path);
    if ($resolved === false || !is_dir($resolved)) {
        return null; // path doesn't exist or isn't a directory
    }

    // Only accept paths under known base directories (security: prevents traversal)
    $allowed = false;
    foreach (ALLOWED_BASES as $base) {
        if (str_starts_with($resolved . '/', $base)) {
            $allowed = true;
            break;
        }
    }

    return $allowed ? $resolved : null; // null = outside allowed bases
}

/**
 * Routing
 *
 * Route table:
 *   GET  /                         → Dashboard HTML (serveDashboardHtml)
 *   GET  /api/scripts              → Script registry JSON
 *   GET  /api/timings              → Last-run durations JSON
 *   GET  /api/projects             → Known project paths JSON
 *   POST /api/run                  → Start a script (JSON body: script, arg?, project?)
 *   GET  /api/status               → Check if a script is currently running
 *   GET  /api/stream/{id}          → SSE stream of script output
 *   POST /api/stop/{id}            → Kill a running script
 *   GET  /blundergoat-avatar.jpg   → Logo image
 */

$rawUri = $_SERVER['REQUEST_URI'] ?? '/';
$parsed = parse_url(is_string($rawUri) ? $rawUri : '/', PHP_URL_PATH);
$uri    = is_string($parsed) ? $parsed : '/';
$rawMethod = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$method = is_string($rawMethod) ? $rawMethod : 'GET';

if ($uri === '/api/scripts' && $method === 'GET') {
    jsonResponse(getScriptRegistry());
} elseif ($uri === '/api/timings' && $method === 'GET') {
    jsonResponse(getTimings());
} elseif ($uri === '/api/projects' && $method === 'GET') {
    handleApiProjects();
} elseif ($uri === '/api/run' && $method === 'POST') {
    handleApiRun();
} elseif ($uri === '/api/status' && $method === 'GET') {
    $running = findRunningProcess();
    jsonResponse($running !== null ? ['running' => true] + $running : ['running' => false]);
} elseif (preg_match('#^/api/stream/([a-zA-Z0-9_-]+)$#', $uri, $m) && $method === 'GET') {
    handleApiStream($m[1]);
} elseif (preg_match('#^/api/stop/([a-zA-Z0-9_-]+)$#', $uri, $m) && $method === 'POST') {
    handleApiStop($m[1]);
} elseif ($uri === '/blundergoat-avatar.jpg') {
    $imgPath = __DIR__ . '/blundergoat-avatar.jpg';
    if (file_exists($imgPath)) {
        header('Content-Type: image/jpeg');
        header('Cache-Control: public, max-age=86400');
        readfile($imgPath);
    } else {
        http_response_code(404);
    }
} elseif ($uri === '/' || $uri === '') {
    serveDashboardHtml();
} else {
    http_response_code(404);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Not found']);
}

exit(0);

/**
 * Send a JSON response.
 */
function jsonResponse(array $data, int $status = 200): void // @phpstan-ignore missingType.iterableValue
{
    http_response_code($status);
    header('Content-Type: application/json');
    echo json_encode($data, JSON_UNESCAPED_SLASHES);
}

/**
 * Write a tagged log line to stderr (shows in terminal).
 */
function dashLog(string $msg): void
{
    file_put_contents('php://stderr', "[dashboard] {$msg}\n");
}

/**
 * Parse JSON body of request, returns empty array if invalid or missing.
 *
 * @return array<string, string>
 */
function getJsonBody(): array
{
    $raw = file_get_contents('php://input');
    if ($raw === false || $raw === '') {
        return [];
    }
    $decoded = json_decode($raw, true);
    if (!is_array($decoded)) {
        return [];
    }
    /** @var array<string, string> */
    return $decoded;
}


/**
 * Return known project directories for the WSL path selector.
 */
function handleApiProjects(): void
{
    $paths = getProjectPaths();

    // Validate each path and return with metadata
    $projects = [];
    foreach ($paths as $path) {
        $resolved = validateProjectPath($path);
        $projects[] = [
            'path'   => $path,
            'name'   => basename($path),
            'exists' => $resolved !== null,
        ];
    }

    jsonResponse($projects);
}

/**
 * Start a script. Only one script can run at a time.
 *
 * JSON body fields:
 *   script  (required) - script ID from config.php whitelist
 *   arg     (optional) - user-supplied argument from prompt modal
 *   project (optional) - target project directory (WSL path selector)
 */
function handleApiRun(): void
{
    $body      = getJsonBody();
    $scriptId  = $body['script'] ?? '';  // which script to run
    $extraArg  = $body['arg'] ?? '';     // user input from prompt modal (empty = no prompt)
    $projectPath = $body['project'] ?? ''; // target project dir (empty = use SCRIPTS_DIR)

    // Whitelist check - null means the script ID isn't in config.php
    $script = findScript($scriptId);
    if ($script === null) {
        jsonResponse(['error' => 'Unknown script'], 400);
        return;
    }
    $scriptName = (string) ($script['name'] ?? ''); // @phpstan-ignore cast.string
    $scriptCmd  = (string) ($script['cmd'] ?? ''); // @phpstan-ignore cast.string
    $scriptArgs = isset($script['args']) && is_array($script['args']) ? $script['args'] : [];

    // Validate project path if provided (WSL path selector).
    // null = path doesn't exist or is outside allowed bases.
    $projectDir = '';
    if ($projectPath !== '') {
        $resolved = validateProjectPath($projectPath);
        if ($resolved === null) {
            jsonResponse(['error' => 'Invalid project path: directory does not exist or is outside allowed base directories'], 400);
            return;
        }
        $projectDir = $resolved;
    }

    // Enforce single-script concurrency - null means nothing is running
    $running = findRunningProcess();
    if ($running !== null) {
        jsonResponse(['error' => 'A script is already running: ' . (string) ($running['script'] ?? ''), 'running' => $running], 409);
        return;
    }

    // Unique run ID: script name + timestamp (e.g. "port-check-143022")
    $runId    = $scriptId . '-' . date('His');
    $logFile  = TMP_DIR . "/{$runId}.log";
    $metaFile = TMP_DIR . "/{$runId}.meta";
    $pidFile  = TMP_DIR . "/{$runId}.pid";

    // Build the shell command - resolve script path relative to SCRIPTS_DIR
    $scriptPath = SCRIPTS_DIR . '/' . $scriptCmd;
    $cmd = 'bash ' . escapeshellarg($scriptPath);

    // Append fixed args from config.php (e.g. ['--verbose', '--color'])
    if ($scriptArgs !== []) {
        foreach ($scriptArgs as $a) {
            $cmd .= ' ' . escapeshellarg((string) $a); // @phpstan-ignore cast.string
        }
    }

    // Append user-supplied arg from prompt modal (only if script has a prompt config)
    if ($extraArg !== '' && isset($script['prompt'])) {
        $cmd .= ' ' . escapeshellarg($extraArg);
    }

    // When a project path is set, cd into it so the script runs in that directory
    if ($projectDir !== '') {
        $cmd = 'cd ' . escapeshellarg($projectDir) . ' && ' . $cmd;
    }

    // Wrapper: records PID, runs script via script(1) for unbuffered PTY output,
    // then appends a sentinel marker so the SSE stream handler knows the process
    // finished - even if it exits before the client connects (fast scripts).
    $wrapper = sprintf(
        'echo $$ > %s; script -qfc %s %s; echo %s >> %s',
        escapeshellarg($pidFile),
        escapeshellarg($cmd . ' 2>&1'),
        escapeshellarg($logFile),
        escapeshellarg("\n" . SENTINEL),
        escapeshellarg($logFile)
    );
    // setsid creates a new session so the script outlives this PHP request
    $fullCmd = sprintf('setsid bash -c %s > /dev/null 2>&1 &', escapeshellarg($wrapper));

    exec($fullCmd);

    // Poll for PID file (wrapper writes it immediately, but filesystem needs a moment)
    $pid = 0;
    for ($attempt = 0; $attempt < 20; $attempt++) {
        usleep(50000); // 50ms between attempts, up to 1s total
        if (file_exists($pidFile)) {
            $pid = (int) trim((string) file_get_contents($pidFile));
            if ($pid > 0) {
                break;
            }
        }
    }

    // Persist run metadata - the stream and stop handlers read this file
    $meta = [
        'id'         => $runId,
        'script'     => $scriptName,
        'script_id'  => $scriptId,
        'cmd'        => $cmd,
        'pid'        => $pid,
        'start_time' => time(),
        'log_file'   => $logFile,
        'project'    => $projectDir,
    ];
    file_put_contents($metaFile, json_encode($meta, JSON_UNESCAPED_SLASHES));

    $targetLabel = $projectDir !== '' ? basename($projectDir) : basename(SCRIPTS_DIR);
    dashLog("RUN  {$scriptName} ({$scriptCmd}) → {$targetLabel}  pid={$pid}");

    jsonResponse(['id' => $runId, 'pid' => $pid]);
}

/**
 * SSE stream of script output.
 *
 * Tails the log file that script(1) is writing to and pushes new chunks
 * to the browser as Server-Sent Events. Ends when either the sentinel
 * marker appears in the log or the process exits.
 */
function handleApiStream(string $runId): void
{
    $logFile  = TMP_DIR . "/{$runId}.log";
    $metaFile = TMP_DIR . "/{$runId}.meta";

    // null check: metaFile missing means the run ID is invalid or already cleaned up
    if (!file_exists($metaFile)) {
        jsonResponse(['error' => 'Unknown process ID'], 404);
        return;
    }

    // SSE headers - tell the browser to expect a streaming event stream
    header('Content-Type: text/event-stream');
    header('Cache-Control: no-cache');
    header('Connection: keep-alive');
    header('X-Accel-Buffering: no'); // disable nginx buffering

    // Disable all output buffering so SSE events reach the browser immediately.
    // PHP and proxies buffer output by default, which would batch events and
    // break the real-time feel. We disable gzip, zlib compression, PHP's
    // output_buffering, and flush any existing ob layers.
    if (function_exists('apache_setenv')) {
        apache_setenv('no-gzip', '1');
    }
    @ini_set('zlib.output_compression', '0');
    @ini_set('output_buffering', '0');
    while (ob_get_level()) {
        ob_end_flush();
    }

    /** @var array<string, int|string> $meta */
    $meta           = json_decode((string) file_get_contents($metaFile), true);
    $pid            = (int) ($meta['pid'] ?? 0);
    $startTime      = (int) ($meta['start_time'] ?? 0);
    $metaScriptId   = (string) ($meta['script_id'] ?? '');
    $metaScriptName = (string) ($meta['script'] ?? '');
    $bytesRead      = 0;  // byte offset into the log file - tracks how far we've read
    $lastHeartbeat  = time();

    // The log file may not exist yet - script(1) needs a moment to create it
    for ($waitCycles = 0; !file_exists($logFile) && $waitCycles < 30; $waitCycles++) {
        usleep(100000); // 100ms per cycle, up to 3s total
    }

    while (true) {
        if (connection_aborted()) {
            break; // client disconnected
        }

        $foundSentinel = false;

        if (file_exists($logFile)) {
            clearstatcache(true, $logFile); // required: PHP caches filesize
            $fileSize = (int) filesize($logFile);
            if ($fileSize > $bytesRead) {
                $fp = fopen($logFile, 'r');
                if ($fp !== false) {
                    fseek($fp, $bytesRead);
                    $chunk = (string) fread($fp, max(1, $fileSize - $bytesRead));
                    fclose($fp);
                    $bytesRead = $fileSize;

                    if ($chunk !== '') {
                        // Check for sentinel marker - its presence means the script finished
                        $sentinelPos = strpos($chunk, SENTINEL);
                        if ($sentinelPos !== false) {
                            $chunk = substr($chunk, 0, $sentinelPos);
                            $foundSentinel = true;
                        }
                        // Strip script(1) wrapper noise ("Script started on...", "Script done on...")
                        $chunk = preg_replace('/^Script (started|done) on .+$/m', '', $chunk) ?? $chunk;
                        $chunk = trim($chunk, "\n");
                        if ($chunk !== '') {
                            sendSseEvent('output', ansiToHtml($chunk));
                        }
                    }
                }
            }
        }

        // Stream is done when:
        //   1. Sentinel found in log (normal exit - script wrote it before finishing), or
        //   2. Process is gone AND we've read at least some output (crash/kill case).
        // posix_kill(pid, 0) returns true if the process exists - false means it exited.
        $processExited = $pid > 0 ? !posix_kill($pid, 0) : false;
        if ($foundSentinel || ($processExited && $bytesRead > 0)) {
            $elapsedSeconds = time() - $startTime;
            saveTiming($metaScriptId, $elapsedSeconds);
            dashLog("DONE {$metaScriptName} ({$elapsedSeconds}s)");
            sendSseEvent('done', (string) json_encode(['id' => $runId]));
            break;
        }

        // Send a heartbeat every 15s to keep the SSE connection alive
        if (time() - $lastHeartbeat >= 15) {
            sendSseEvent('heartbeat', '');
            $lastHeartbeat = time();
        }

        usleep(100000); // 100ms poll interval
    }
}

/**
 * Send a single Server-Sent Event to the browser.
 *
 * SSE protocol: "event: <name>\ndata: <line>\ndata: <line>\n\n"
 * Multi-line data must be split into separate "data:" lines per the spec.
 */
function sendSseEvent(string $event, string $data): void
{
    echo "event: {$event}\n";
    foreach (explode("\n", $data) as $line) {
        echo "data: {$line}\n";
    }
    echo "\n";
    flush();
}

/**
 * Stop a running script.
 *
 * Sends SIGTERM first (graceful), waits up to 2s, then escalates to
 * SIGKILL if the process is still alive. Also cleans up orphaned
 * script(1) wrapper processes.
 */
function handleApiStop(string $runId): void
{
    $metaFile = TMP_DIR . "/{$runId}.meta";

    // null check: metaFile missing means the run ID is invalid or already cleaned up
    if (!file_exists($metaFile)) {
        jsonResponse(['error' => 'Unknown process ID'], 404);
        return;
    }

    /** @var array<string, int|string> $meta */
    $meta = json_decode((string) file_get_contents($metaFile), true);
    $pid  = (int) ($meta['pid'] ?? 0);
    $metaScriptName = (string) ($meta['script'] ?? '');

    if ($pid <= 0) {
        jsonResponse(['error' => 'No PID recorded'], 400);
        return;
    }

    // Phase 1: SIGTERM - ask the process group and the process itself to exit gracefully.
    // Negative PID sends the signal to the entire process group (script + its children).
    $negPid = -$pid;
    @posix_kill($negPid, 15); // SIGTERM → process group
    @posix_kill($pid, 15);    // SIGTERM → process directly

    // Wait up to 2s for graceful shutdown (posix_kill(pid, 0) checks if still alive)
    $waitCycles = 0;
    while ($waitCycles < 20 && posix_kill($pid, 0)) {
        usleep(100000); // 100ms per cycle
        $waitCycles++;
    }

    // Phase 2: SIGKILL - force kill if still alive after grace period
    if (posix_kill($pid, 0)) {
        @posix_kill($negPid, 9); // SIGKILL → process group
        @posix_kill($pid, 9);    // SIGKILL → process directly
    }

    // Clean up orphaned script(1) wrapper processes that may outlive the main script
    $logFile = TMP_DIR . "/{$runId}.log";
    exec('pkill -f ' . escapeshellarg("script.*{$logFile}") . ' 2>/dev/null');

    dashLog("STOP {$metaScriptName} (pid {$pid})");
    jsonResponse(['stopped' => true, 'id' => $runId]);
}

/**
 * Find a currently running script process.
 *
 * Scans .meta files (newest first) and checks if the recorded PID is
 * still alive. Returns the meta data of the first live process found,
 * or null if nothing is running.
 *
 * @return array<string, int|string>|null  null = no script is currently running
 */
function findRunningProcess(): ?array
{
    $metaFiles = glob(TMP_DIR . '/*.meta');
    if (!$metaFiles) {
        return null; // no meta files exist - nothing has ever run
    }

    // Check newest meta files first (most likely to be the active one)
    usort($metaFiles, fn(string $a, string $b): int => filemtime($b) - filemtime($a));

    foreach ($metaFiles as $file) {
        $decoded = json_decode((string) file_get_contents($file), true);
        if (!is_array($decoded) || !isset($decoded['pid'])) {
            continue; // corrupt or incomplete meta file
        }
        $pid = (int) $decoded['pid']; // @phpstan-ignore cast.int
        // posix_kill(pid, 0) doesn't send a signal - it just checks if the process exists
        if ($pid > 0 && posix_kill($pid, 0)) {
            /** @var array<string, int|string> $decoded */
            return $decoded;
        }
    }

    return null; // all recorded processes have exited
}

/**
 * Timing helpers
 *
 * Stores the last run duration per script ID. The UI shows this when
 * a script has a confirm dialog ("Last time this took 12s").
 *
 * @return array<string, int>  scriptId → seconds
 */
function getTimings(): array
{
    if (!file_exists(TIMINGS_FILE)) {
        return []; // no timings recorded yet
    }
    $data = json_decode((string) file_get_contents(TIMINGS_FILE), true);
    /** @var array<string, int> */
    return is_array($data) ? $data : [];
}

/**
 * @param string $scriptId
 * @param int    $elapsedSeconds
 *
 * @return void
 */
function saveTiming(string $scriptId, int $elapsedSeconds): void
{
    if ($scriptId === '' || $elapsedSeconds <= 0) {
        return; // don't record empty or instant runs
    }
    $timings = getTimings();
    $timings[$scriptId] = $elapsedSeconds;
    file_put_contents(TIMINGS_FILE, json_encode($timings, JSON_UNESCAPED_SLASHES));
}

/**
 * ANSI to HTML conversion.
 *
 * Parses ANSI escape codes (colors, bold, dim) from script output
 * and replaces them with <span class="ansi-*"> elements. Characters
 * outside escape sequences are HTML-escaped to prevent XSS.
 */
function ansiToHtml(string $text): string
{
    $text = str_replace("\r", '', $text);

    /** @var array<string, string> $ansiMap */
    $ansiMap = [
        '0m'    => '</span>',
        '1m'    => '<span class="ansi-bold">',
        '2m'    => '<span class="ansi-dim">',
        '0;30m' => '<span class="ansi-black">', '0;31m' => '<span class="ansi-red">',
        '0;32m' => '<span class="ansi-green">', '0;33m' => '<span class="ansi-yellow">',
        '0;34m' => '<span class="ansi-blue">',  '0;35m' => '<span class="ansi-magenta">',
        '0;36m' => '<span class="ansi-cyan">',  '0;37m' => '<span class="ansi-white">',
        '1;30m' => '<span class="ansi-bold ansi-black">', '1;31m' => '<span class="ansi-bold ansi-red">',
        '1;32m' => '<span class="ansi-bold ansi-green">', '1;33m' => '<span class="ansi-bold ansi-yellow">',
        '1;34m' => '<span class="ansi-bold ansi-blue">',  '1;35m' => '<span class="ansi-bold ansi-magenta">',
        '1;36m' => '<span class="ansi-bold ansi-cyan">',  '1;37m' => '<span class="ansi-bold ansi-white">',
    ];

    // Walk through the text byte-by-byte, converting ANSI escape sequences
    // to HTML spans and escaping everything else for safe HTML output.
    //
    // ANSI escape format: ESC[ <params> <letter>
    //   e.g. "\e[1;32m" = bold green, "\e[0m" = reset
    $htmlOut    = '';
    $textLength = strlen($text);
    $pos        = 0;

    while ($pos < $textLength) {
        $byte = $text[$pos];

        // Check for ESC (0x1B) followed by '[' - start of a CSI escape sequence
        if (ord($byte) === 0x1B && $pos + 1 < $textLength && $text[$pos + 1] === '[') {
            // Skip past "ESC[" and scan for the sequence body (e.g. "1;32m")
            $seqBodyStart = $pos + 2;
            $seqBodyEnd   = $seqBodyStart;
            // Sequences are short - cap at 16 chars to avoid runaway scanning
            while ($seqBodyEnd < $textLength && $seqBodyEnd - $seqBodyStart < 16) {
                if (ctype_alpha($text[$seqBodyEnd])) { $seqBodyEnd++; break; } // letter = end of sequence
                $seqBodyEnd++;
            }
            $escapeCode = substr($text, $seqBodyStart, $seqBodyEnd - $seqBodyStart);
            // Map known codes to HTML spans; unrecognized codes are silently dropped
            if (isset($ansiMap[$escapeCode])) {
                $htmlOut .= $ansiMap[$escapeCode];
            }
            $pos = $seqBodyEnd;
        } else {
            // Regular character - HTML-escape to prevent XSS
            $htmlOut .= match($byte) {
                '&' => '&amp;', '<' => '&lt;', '>' => '&gt;',
                '"' => '&quot;', "'" => '&#039;',
                default => $byte,
            };
            $pos++;
        }
    }

    return $htmlOut;
}
