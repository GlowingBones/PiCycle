<?php
declare(strict_types=1);

/*
  PiCycle index.php
  Purpose: confirm PHP is executing, show basic device and asset status, and serve local assets.
*/

function h(string $s): string { return htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'); }

$docroot = $_SERVER['DOCUMENT_ROOT'] ?? __DIR__;
$docroot = rtrim($docroot, '/');

$clientIp = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
$serverIp = $_SERVER['SERVER_ADDR'] ?? ($_SERVER['SERVER_NAME'] ?? 'unknown');
$nowUtc   = (new DateTimeImmutable('now', new DateTimeZone('UTC')))->format('c');

$assetCandidates = [
  $docroot . '/assets',
  $docroot,
];

function firstExistingFile(array $candidates, array $relativeNames): ?string {
  foreach ($candidates as $base) {
    foreach ($relativeNames as $rel) {
      $p = rtrim($base, '/') . '/' . ltrim($rel, '/');
      if (is_file($p)) return $p;
    }
  }
  return null;
}

$logoPath = firstExistingFile(
  $assetCandidates,
  ['picycle.png', 'assets/picycle.png', 'img/picycle.png', 'images/picycle.png']
);

function webPathFromDocroot(string $docroot, string $absPath): string {
  $docroot = rtrim($docroot, '/');
  if (str_starts_with($absPath, $docroot . '/')) {
    return '/' . ltrim(substr($absPath, strlen($docroot)), '/');
  }
  return '';
}

$logoWeb = $logoPath ? webPathFromDocroot($docroot, $logoPath) : '';

$checks = [
  'PHP executing' => true,
  'Document root exists' => is_dir($docroot),
  'index.php readable' => is_readable(__FILE__),
  '/var/www/html exists' => is_dir('/var/www/html'),
  '/dev/hidg0 present' => file_exists('/dev/hidg0'),
  '/dev/hidg1 present' => file_exists('/dev/hidg1'),
  '/dev/hidg2 present' => file_exists('/dev/hidg2'),
];

function listFiles(string $dir, int $limit = 200): array {
  if (!is_dir($dir) || !is_readable($dir)) return [];
  $out = [];
  $it = @scandir($dir);
  if ($it === false) return [];
  foreach ($it as $name) {
    if ($name === '.' || $name === '..') continue;
    if ($name[0] === '.') continue;
    $path = rtrim($dir, '/') . '/' . $name;
    $out[] = [
      'name' => $name,
      'is_dir' => is_dir($path),
      'size' => is_file($path) ? filesize($path) : null,
      'mtime' => @filemtime($path) ?: null,
    ];
    if (count($out) >= $limit) break;
  }
  usort($out, function($a, $b) {
    if ($a['is_dir'] !== $b['is_dir']) return $a['is_dir'] ? -1 : 1;
    return strcmp($a['name'], $b['name']);
  });
  return $out;
}

$filesRoot = listFiles($docroot);
$filesAssets = listFiles($docroot . '/assets');

header('Content-Type: text/html; charset=utf-8');

?><!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>PiCycle</title>
  <style>
    body { font-family: Arial, Helvetica, sans-serif; margin: 18px; line-height: 1.35; }
    .wrap { max-width: 980px; }
    .card { border: 1px solid #ddd; border-radius: 10px; padding: 14px; margin: 12px 0; }
    table { border-collapse: collapse; width: 100%; }
    td, th { border-bottom: 1px solid #eee; padding: 8px; text-align: left; }
    .ok { color: #0a7a0a; font-weight: 700; }
    .bad { color: #b00020; font-weight: 700; }
    .mono { font-family: Consolas, Menlo, monospace; }
    a { text-decoration: none; }
    a:hover { text-decoration: underline; }
    .small { font-size: 12px; color: #555; }
    .logo { max-width: 320px; height: auto; display: block; margin: 10px 0; }
  </style>
</head>
<body>
<div class="wrap">
  <div class="card">
    <div class="mono">PiCycle web server OK</div>
    <div class="small mono">Client IP: <?= h($clientIp) ?></div>
    <div class="small mono">Server IP: <?= h($serverIp) ?></div>
    <div class="small mono">UTC Time: <?= h($nowUtc) ?></div>
    <?php if ($logoWeb !== ''): ?>
      <img class="logo" alt="PiCycle" src="<?= h($logoWeb) ?>" />
    <?php else: ?>
      <div class="small">No local picycle.png found in document root or assets directory.</div>
    <?php endif; ?>
  </div>

  <div class="card">
    <h3>Checks</h3>
    <table>
      <tbody>
      <?php foreach ($checks as $label => $pass): ?>
        <tr>
          <td><?= h($label) ?></td>
          <td class="<?= $pass ? 'ok' : 'bad' ?>"><?= $pass ? 'OK' : 'FAIL' ?></td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  </div>

  <div class="card">
    <h3>Web root files</h3>
    <?php if (!$filesRoot): ?>
      <div class="small">No readable directory listing for <?= h($docroot) ?></div>
    <?php else: ?>
      <table>
        <thead>
          <tr><th>Name</th><th>Type</th><th>Size</th><th>Modified</th></tr>
        </thead>
        <tbody>
        <?php foreach ($filesRoot as $f): ?>
          <?php
            $name = $f['name'];
            $href = '/' . rawurlencode($name);
            $type = $f['is_dir'] ? 'dir' : 'file';
            $size = ($f['size'] === null) ? '' : (string)$f['size'];
            $mtime = $f['mtime'] ? gmdate('c', (int)$f['mtime']) : '';
          ?>
          <tr>
            <td class="mono">
              <?php if ($f['is_dir']): ?>
                <?= h($name) ?>
              <?php else: ?>
                <a href="<?= h($href) ?>"><?= h($name) ?></a>
              <?php endif; ?>
            </td>
            <td><?= h($type) ?></td>
            <td class="mono"><?= h($size) ?></td>
            <td class="mono"><?= h($mtime) ?></td>
          </tr>
        <?php endforeach; ?>
        </tbody>
      </table>
    <?php endif; ?>
  </div>

  <div class="card">
    <h3>/assets files</h3>
    <?php if (!$filesAssets): ?>
      <div class="small">No readable directory listing for <?= h($docroot . '/assets') ?></div>
    <?php else: ?>
      <table>
        <thead>
          <tr><th>Name</th><th>Type</th><th>Size</th><th>Modified</th></tr>
        </thead>
        <tbody>
        <?php foreach ($filesAssets as $f): ?>
          <?php
            $name = $f['name'];
            $href = '/assets/' . rawurlencode($name);
            $type = $f['is_dir'] ? 'dir' : 'file';
            $size = ($f['size'] === null) ? '' : (string)$f['size'];
            $mtime = $f['mtime'] ? gmdate('c', (int)$f['mtime']) : '';
          ?>
          <tr>
            <td class="mono">
              <?php if ($f['is_dir']): ?>
                <?= h($name) ?>
              <?php else: ?>
                <a href="<?= h($href) ?>"><?= h($name) ?></a>
              <?php endif; ?>
            </td>
            <td><?= h($type) ?></td>
            <td class="mono"><?= h($size) ?></td>
            <td class="mono"><?= h($mtime) ?></td>
          </tr>
        <?php endforeach; ?>
        </tbody>
      </table>
    <?php endif; ?>
  </div>

  <div class="card">
    <h3>PHP</h3>
    <div class="small mono">
      Version: <?= h(PHP_VERSION) ?><br />
      SAPI: <?= h(PHP_SAPI) ?><br />
      Loaded ini: <?= h((string)php_ini_loaded_file()) ?>
    </div>
  </div>

</div>
</body>
</html>
