<?php
/**
 * DevEx Dashboard
 *
 * Web UI for running project scripts from the browser.
 * Local development only — never expose to the network.
 *
 * Usage:
 *   php -S 127.0.0.1:8899 dashboard/index.php
 *
 * Then open http://localhost:8899
 */

/**
 * Security: local-only guard
 *
 * Returns HTTP 403 for any request not from localhost.
 * This fires before any routing or script execution.
 */

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
 */

$projectName = getenv('PROJECT_NAME') ?: 'DevEx Dashboard';

$scriptsDir = getenv('SCRIPTS_DIR') ?: dirname(__DIR__);
define('SCRIPTS_DIR', $scriptsDir);
define('PROJECT_ROOT', dirname(SCRIPTS_DIR));

$tmpBase = preg_replace('/[^a-zA-Z0-9_-]/', '-', strtolower($projectName));
define('TMP_DIR', '/tmp/' . $tmpBase . '-dashboard');
define('SENTINEL', '__DASHBOARD_DONE__');
define('TIMINGS_FILE', TMP_DIR . '/timings.json');

// Environment name: from env var, or detect from project path, or 'local'
$envName = getenv('ENV_NAME') ?: basename(dirname(PROJECT_ROOT)) ?: 'local';
define('ENV_NAME', $envName);
define('PROJECT_NAME', $projectName);

// Site URL: from env var, or empty (hides the link in the UI)
define('SITE_URL', getenv('SITE_URL') ?: '');

// Ensure temp directory exists
if (!is_dir(TMP_DIR)) {
    mkdir(TMP_DIR, 0755, true);
}

// Detect if config.php is the unedited example (auto-copied by start.sh)
$configFile = __DIR__ . '/config.php';
$exampleFile = __DIR__ . '/config.example.php';
$isExampleConfig = file_exists($exampleFile) && file_get_contents($configFile) === file_get_contents($exampleFile);
define('IS_EXAMPLE_CONFIG', $isExampleConfig);

/**
 * Script registry (whitelist)
 */

function getScriptRegistry(): array
{
    $config = require __DIR__ . '/config.php';
    return is_array($config) ? $config : [];
}

/**
 * Look up a script entry by ID, returns null if not found in whitelist.
 *
 * @param string $id
 *
 * @return array|null
 */
function findScript(string $id): ?array
{
    foreach (getScriptRegistry() as $cat) {
        foreach ($cat['scripts'] as $script) {
            if ($script['id'] === $id) {
                return $script;
            }
        }
    }
    return null;
}

require __DIR__ . '/frontend.php';

/**
 * Project path helpers (Phase 2 — WSL Path Selector)
 */

/**
 * Allowed base directories for project paths. Only paths under these
 * prefixes are accepted — prevents path traversal attacks.
 */
define('ALLOWED_BASES', ['/srv/', '/home/', '/mnt/', '/opt/', '/var/www/']);

/**
 * Get known project directories from config.php or DASHBOARD_PROJECTS env var.
 *
 * @return string[]
 */
function getProjectPaths(): array
{
    $paths = [];

    // From env var (comma-separated)
    $envProjects = getenv('DASHBOARD_PROJECTS');
    if ($envProjects) {
        foreach (explode(',', $envProjects) as $p) {
            $p = trim($p);
            if ($p !== '') $paths[] = $p;
        }
    }

    // From config.php projects array
    $config = require __DIR__ . '/config.php';
    if (is_array($config)) {
        // Look for a top-level 'projects' key (outside the categories array)
        // config.php returns an array — if the last element has a 'projects' key, use it
        foreach ($config as $entry) {
            if (isset($entry['projects']) && is_array($entry['projects'])) {
                $paths = array_merge($paths, $entry['projects']);
            }
        }
    }

    return array_values(array_unique($paths));
}

/**
 * Validate and resolve a project path. Returns the resolved absolute path
 * or null if invalid.
 *
 * @param string $path
 *
 * @return string|null
 */
function validateProjectPath(string $path): ?string
{
    if ($path === '') return null;

    $resolved = realpath($path);
    if ($resolved === false || !is_dir($resolved)) return null;

    // Check against allowed base directories
    $allowed = false;
    foreach (ALLOWED_BASES as $base) {
        if (str_starts_with($resolved . '/', $base)) {
            $allowed = true;
            break;
        }
    }

    return $allowed ? $resolved : null;
}

/**
 * Routing
 */

$uri    = (string) parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$method = $_SERVER['REQUEST_METHOD'];

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
    jsonResponse($running ? ['running' => true] + $running : ['running' => false]);
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
 * API handlers
 *
 * @param array $data
 * @param int   $status
 *
 * @return void
 */
function jsonResponse(array $data, int $status = 200): void
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
 * @return array
 */
function getJsonBody(): array
{
    $raw = file_get_contents('php://input');
    return $raw ? (json_decode($raw, true) ?: []) : [];
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
 * Start a script. Only one at a time.
 *
 * Accepts an optional 'project' field in the JSON body for WSL path selector.
 * When present, the script runs with cwd set to that project directory.
 */
function handleApiRun(): void
{
    $body     = getJsonBody();
    $scriptId = $body['script'] ?? '';
    $extraArg = $body['arg'] ?? '';
    $project  = $body['project'] ?? '';

    $script = findScript($scriptId);
    if (!$script) {
        jsonResponse(['error' => 'Unknown script'], 400);
        return;
    }

    // Validate project path if provided (WSL path selector)
    $projectDir = '';
    if ($project !== '') {
        $resolved = validateProjectPath($project);
        if ($resolved === null) {
            jsonResponse(['error' => 'Invalid project path: directory does not exist or is outside allowed base directories'], 400);
            return;
        }
        $projectDir = $resolved;
    }

    $running = findRunningProcess();
    if ($running) {
        jsonResponse(['error' => 'A script is already running: ' . $running['script'], 'running' => $running], 409);
        return;
    }

    $id       = $scriptId . '-' . date('His');
    $logFile  = TMP_DIR . "/{$id}.log";
    $metaFile = TMP_DIR . "/{$id}.meta";
    $pidFile  = TMP_DIR . "/{$id}.pid";

    // Build command — resolve script path relative to SCRIPTS_DIR
    $scriptPath = SCRIPTS_DIR . '/' . $script['cmd'];
    $cmd = 'bash ' . escapeshellarg($scriptPath);

    if (!empty($script['args'])) {
        foreach ($script['args'] as $a) {
            $cmd .= ' ' . escapeshellarg($a);
        }
    }

    if ($extraArg !== '' && isset($script['prompt'])) {
        $cmd .= ' ' . escapeshellarg($extraArg);
    }

    // When a project path is set, cd into it before running the script
    if ($projectDir !== '') {
        $cmd = 'cd ' . escapeshellarg($projectDir) . ' && ' . $cmd;
    }

    // Wrapper: records PID, runs script via script(1) for unbuffered output,
    // appends sentinel so the stream handler knows the process finished even
    // if it exits before SSE connects (fast scripts like git-status).
    $wrapper = sprintf(
        'echo $$ > %s; script -qfc %s %s; echo %s >> %s',
        escapeshellarg($pidFile),
        escapeshellarg($cmd . ' 2>&1'),
        escapeshellarg($logFile),
        escapeshellarg("\n" . SENTINEL),
        escapeshellarg($logFile)
    );
    $fullCmd = sprintf('setsid bash -c %s > /dev/null 2>&1 &', escapeshellarg($wrapper));

    exec($fullCmd);

    // Wait for wrapper to write its PID (up to 1s)
    $pid = 0;
    for ($i = 0; $i < 20; $i++) {
        usleep(50000);
        if (file_exists($pidFile)) {
            $pid = (int) trim((string) file_get_contents($pidFile));
            if ($pid > 0) break;
        }
    }

    $meta = [
        'id'         => $id,
        'script'     => $script['name'],
        'script_id'  => $scriptId,
        'cmd'        => $cmd,
        'pid'        => $pid,
        'start_time' => time(),
        'log_file'   => $logFile,
        'project'    => $projectDir,
    ];
    file_put_contents($metaFile, json_encode($meta, JSON_UNESCAPED_SLASHES));

    $target = $projectDir !== '' ? basename($projectDir) : basename(SCRIPTS_DIR);
    dashLog("RUN  {$script['name']} ({$script['cmd']}) → {$target}  pid={$pid}");

    jsonResponse(['id' => $id, 'pid' => $pid]);
}

/**
 * SSE stream of script output.
 */
function handleApiStream(string $id): void
{
    $logFile  = TMP_DIR . "/{$id}.log";
    $metaFile = TMP_DIR . "/{$id}.meta";

    if (!file_exists($metaFile)) {
        jsonResponse(['error' => 'Unknown process ID'], 404);
        return;
    }

    header('Content-Type: text/event-stream');
    header('Cache-Control: no-cache');
    header('Connection: keep-alive');
    header('X-Accel-Buffering: no');

    if (function_exists('apache_setenv')) {
        apache_setenv('no-gzip', '1');
    }
    @ini_set('zlib.output_compression', '0');
    @ini_set('output_buffering', '0');
    while (ob_get_level()) {
        ob_end_flush();
    }

    $meta   = json_decode((string) file_get_contents($metaFile), true);
    $pid    = $meta['pid'] ?? 0;
    $offset = 0;
    $lastHeartbeat = time();

    // Wait briefly for log file to appear
    for ($w = 0; !file_exists($logFile) && $w < 30; $w++) {
        usleep(100000);
    }

    while (true) {
        if (connection_aborted()) break;

        $foundSentinel = false;

        if (file_exists($logFile)) {
            clearstatcache(true, $logFile);
            $size = filesize($logFile);
            if ($size > $offset) {
                $fp = fopen($logFile, 'r');
                fseek($fp, $offset);
                $chunk = fread($fp, max(1, $size - $offset));
                fclose($fp);
                $offset = $size;

                if ($chunk !== '' && $chunk !== false) {
                    // Strip sentinel marker and script(1) header/footer noise
                    $sentinelPos = strpos($chunk, SENTINEL);
                    if ($sentinelPos !== false) {
                        $chunk = substr($chunk, 0, $sentinelPos);
                        $foundSentinel = true;
                    }
                    // Remove script(1) header/footer lines
                    $chunk = preg_replace('/^Script (started|done) on .+$/m', '', $chunk) ?? $chunk;
                    $chunk = trim($chunk, "\n");
                    if ($chunk !== '') {
                        sendSseEvent('output', ansiToHtml($chunk));
                    }
                }
            }
        }

        // Done if sentinel found, or process exited and we've read output
        $processGone = $pid > 0 ? !posix_kill($pid, 0) : false;
        if ($foundSentinel || ($processGone && $offset > 0)) {
            $elapsed = time() - ($meta['start_time'] ?? time());
            saveTiming($meta['script_id'] ?? '', $elapsed);
            dashLog("DONE {$meta['script']} ({$elapsed}s)");
            sendSseEvent('done', (string) json_encode(['id' => $id]));
            break;
        }

        if (time() - $lastHeartbeat >= 15) {
            sendSseEvent('heartbeat', '');
            $lastHeartbeat = time();
        }

        usleep(100000); // 100ms poll
    }
}

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
 * @param string $id
 *
 * @return void
 */
function handleApiStop(string $id): void
{
    $metaFile = TMP_DIR . "/{$id}.meta";

    if (!file_exists($metaFile)) {
        jsonResponse(['error' => 'Unknown process ID'], 404);
        return;
    }

    $meta = json_decode((string) file_get_contents($metaFile), true);
    $pid  = (int) ($meta['pid'] ?? 0);

    if ($pid <= 0) {
        jsonResponse(['error' => 'No PID recorded'], 400);
        return;
    }

    @posix_kill(-$pid, 15); // SIGTERM to process group
    @posix_kill($pid, 15);

    $waited = 0;
    while ($waited < 20 && posix_kill($pid, 0)) {
        usleep(100000);
        $waited++;
    }

    if (posix_kill($pid, 0)) {
        @posix_kill(-$pid, 9); // SIGKILL
        @posix_kill($pid, 9);
    }

    $logFile = TMP_DIR . "/{$id}.log";
    exec('pkill -f ' . escapeshellarg("script.*{$logFile}") . ' 2>/dev/null');

    dashLog("STOP {$meta['script']} (pid {$pid})");
    jsonResponse(['stopped' => true, 'id' => $id]);
}

/**
 * Process helpers
 */

function findRunningProcess(): ?array
{
    $files = glob(TMP_DIR . '/*.meta');
    if (!$files) return null;

    usort($files, fn($a, $b) => filemtime($b) - filemtime($a));

    foreach ($files as $file) {
        $meta = json_decode((string) file_get_contents($file), true);
        if (!$meta || empty($meta['pid'])) continue;

        $pid = (int) $meta['pid'];
        if ($pid > 0 && posix_kill($pid, 0)) {
            return $meta;
        }
    }

    return null;
}

/**
 * Timing helpers
 */

function getTimings(): array
{
    if (!file_exists(TIMINGS_FILE)) return [];
    $data = json_decode((string) file_get_contents(TIMINGS_FILE), true);
    return is_array($data) ? $data : [];
}

function saveTiming(string $scriptId, int $seconds): void
{
    if ($scriptId === '' || $seconds <= 0) return;
    $timings = getTimings();
    $timings[$scriptId] = $seconds;
    file_put_contents(TIMINGS_FILE, json_encode($timings, JSON_UNESCAPED_SLASHES));
}

/**
 * ANSI to HTML conversion
 */

function ansiToHtml(string $text): string
{
    $text = str_replace("\r", '', $text);

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

    $result = '';
    $len    = strlen($text);
    $i      = 0;

    while ($i < $len) {
        if (ord($text[$i]) === 0x1B && $i + 1 < $len && $text[$i + 1] === '[') {
            $seqStart = $i + 2;
            $seqEnd   = $seqStart;
            while ($seqEnd < $len && $seqEnd - $seqStart < 16) {
                if (ctype_alpha($text[$seqEnd])) { $seqEnd++; break; }
                $seqEnd++;
            }
            $seq = substr($text, $seqStart, $seqEnd - $seqStart);
            if (isset($ansiMap[$seq])) {
                $result .= $ansiMap[$seq];
            }
            $i = $seqEnd;
        } else {
            $ch = $text[$i];
            $result .= match($ch) {
                '&' => '&amp;', '<' => '&lt;', '>' => '&gt;',
                '"' => '&quot;', "'" => '&#039;',
                default => $ch,
            };
            $i++;
        }
    }

    return $result;
}
