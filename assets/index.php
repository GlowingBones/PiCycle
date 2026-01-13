<?php
declare(strict_types=1);

/*
  PiCycle Control Panel
  Features:
  1. File upload to USB mass storage
  2. Network information display (USB and real interfaces)
  3. Virtual HID keyboard
  4. DuckyScript execution from Scripts directory
  5. Built-in script text editor
*/

// Configuration
define('HID_DEVICE', '/dev/hidg0');
define('USB_IMAGE', '/piusb.img');
define('USB_MOUNT', '/mnt/piusb');
define('SCRIPTS_DIR', __DIR__ . '/Scripts');
define('WEBSERVER_UPLOADS', __DIR__ . '/uploads');

// Security helper
function h(string $s): string {
    return htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

// HID Keycodes
$KEYCODES = [
    'a' => 0x04, 'b' => 0x05, 'c' => 0x06, 'd' => 0x07, 'e' => 0x08, 'f' => 0x09,
    'g' => 0x0a, 'h' => 0x0b, 'i' => 0x0c, 'j' => 0x0d, 'k' => 0x0e, 'l' => 0x0f,
    'm' => 0x10, 'n' => 0x11, 'o' => 0x12, 'p' => 0x13, 'q' => 0x14, 'r' => 0x15,
    's' => 0x16, 't' => 0x17, 'u' => 0x18, 'v' => 0x19, 'w' => 0x1a, 'x' => 0x1b,
    'y' => 0x1c, 'z' => 0x1d,
    '1' => 0x1e, '2' => 0x1f, '3' => 0x20, '4' => 0x21, '5' => 0x22,
    '6' => 0x23, '7' => 0x24, '8' => 0x25, '9' => 0x26, '0' => 0x27,
    'enter' => 0x28, 'esc' => 0x29, 'backspace' => 0x2a, 'tab' => 0x2b,
    'space' => 0x2c, '-' => 0x2d, '=' => 0x2e, '[' => 0x2f, ']' => 0x30,
    '\\' => 0x31, ';' => 0x33, "'" => 0x34, '`' => 0x35, ',' => 0x36,
    '.' => 0x37, '/' => 0x38, 'caps' => 0x39,
    'f1' => 0x3a, 'f2' => 0x3b, 'f3' => 0x3c, 'f4' => 0x3d, 'f5' => 0x3e,
    'f6' => 0x3f, 'f7' => 0x40, 'f8' => 0x41, 'f9' => 0x42, 'f10' => 0x43,
    'f11' => 0x44, 'f12' => 0x45, 'print' => 0x46, 'scroll' => 0x47,
    'pause' => 0x48, 'insert' => 0x49, 'home' => 0x4a, 'pageup' => 0x4b,
    'delete' => 0x4c, 'end' => 0x4d, 'pagedown' => 0x4e,
    'right' => 0x4f, 'left' => 0x50, 'down' => 0x51, 'up' => 0x52
];

// Characters needing shift
$SHIFT_MAP = [
    '!' => '1', '@' => '2', '#' => '3', '$' => '4', '%' => '5', '^' => '6',
    '&' => '7', '*' => '8', '(' => '9', ')' => '0', '_' => '-', '+' => '=',
    '{' => '[', '}' => ']', '|' => '\\', ':' => ';', '"' => "'",
    '<' => ',', '>' => '.', '?' => '/', '~' => '`',
    'A' => 'a', 'B' => 'b', 'C' => 'c', 'D' => 'd', 'E' => 'e', 'F' => 'f',
    'G' => 'g', 'H' => 'h', 'I' => 'i', 'J' => 'j', 'K' => 'k', 'L' => 'l',
    'M' => 'm', 'N' => 'n', 'O' => 'o', 'P' => 'p', 'Q' => 'q', 'R' => 'r',
    'S' => 's', 'T' => 't', 'U' => 'u', 'V' => 'v', 'W' => 'w', 'X' => 'x',
    'Y' => 'y', 'Z' => 'z'
];

// Modifier keys
$MODIFIERS = [
    'ctrl' => 0x01, 'shift' => 0x02, 'alt' => 0x04, 'gui' => 0x08,
    'right_ctrl' => 0x10, 'right_shift' => 0x20, 'right_alt' => 0x40, 'right_gui' => 0x80
];

// DuckyScript key mapping
$DUCKY_MAP = [
    'GUI' => 'gui', 'WINDOWS' => 'gui', 'CTRL' => 'ctrl', 'CONTROL' => 'ctrl',
    'SHIFT' => 'shift', 'ALT' => 'alt', 'ENTER' => 'enter', 'ESCAPE' => 'esc',
    'ESC' => 'esc', 'TAB' => 'tab', 'SPACE' => 'space', 'BACKSPACE' => 'backspace',
    'DELETE' => 'delete', 'HOME' => 'home', 'END' => 'end', 'PAGEUP' => 'pageup',
    'PAGEDOWN' => 'pagedown', 'UP' => 'up', 'DOWN' => 'down', 'LEFT' => 'left',
    'RIGHT' => 'right', 'UPARROW' => 'up', 'DOWNARROW' => 'down',
    'LEFTARROW' => 'left', 'RIGHTARROW' => 'right',
    'F1' => 'f1', 'F2' => 'f2', 'F3' => 'f3', 'F4' => 'f4', 'F5' => 'f5',
    'F6' => 'f6', 'F7' => 'f7', 'F8' => 'f8', 'F9' => 'f9', 'F10' => 'f10',
    'F11' => 'f11', 'F12' => 'f12', 'CAPSLOCK' => 'caps', 'PRINTSCREEN' => 'print',
    'SCROLLLOCK' => 'scroll', 'PAUSE' => 'pause', 'INSERT' => 'insert',
    'BREAK' => 'pause', 'MENU' => 'app'
];

// Send HID report
function sendHIDReport(int $modifier, int $keycode): bool {
    if (!file_exists(HID_DEVICE)) {
        return false;
    }
    $report = pack('C8', $modifier, 0, $keycode, 0, 0, 0, 0, 0);
    $fp = @fopen(HID_DEVICE, 'rb+');
    if ($fp === false) {
        return false;
    }
    $result = fwrite($fp, $report);
    fclose($fp);
    return $result !== false;
}

// Release all keys
function releaseAllKeys(): bool {
    return sendHIDReport(0, 0);
}

// Press a single key
function pressKey(string $key, int $modifier = 0, int $durationMs = 50): bool {
    global $KEYCODES, $SHIFT_MAP;

    $keyLower = strtolower($key);

    // Handle shifted characters
    if (isset($SHIFT_MAP[$key])) {
        $modifier |= 0x02; // Add shift
        $keyLower = strtolower($SHIFT_MAP[$key]);
    }

    if (!isset($KEYCODES[$keyLower])) {
        return false;
    }

    $keycode = $KEYCODES[$keyLower];

    // Press
    if (!sendHIDReport($modifier, $keycode)) {
        return false;
    }
    usleep($durationMs * 1000);

    // Release
    releaseAllKeys();
    usleep(10000); // 10ms between keys

    return true;
}

// Type a string
function typeString(string $text, int $delayMs = 50): bool {
    for ($i = 0; $i < strlen($text); $i++) {
        $char = $text[$i];
        if ($char === "\n") {
            pressKey('enter', 0, $delayMs);
        } else {
            pressKey($char, 0, $delayMs);
        }
    }
    return true;
}

// Press key combination
function pressCombo(array $keys): bool {
    global $KEYCODES, $MODIFIERS;

    $modifier = 0;
    $keycode = 0;

    foreach ($keys as $key) {
        $keyLower = strtolower(trim($key));
        if (isset($MODIFIERS[$keyLower])) {
            $modifier |= $MODIFIERS[$keyLower];
        } elseif (isset($KEYCODES[$keyLower])) {
            $keycode = $KEYCODES[$keyLower];
        }
    }

    // Press combo
    if (!sendHIDReport($modifier, $keycode)) {
        return false;
    }
    usleep(100000); // 100ms hold

    // Release
    releaseAllKeys();
    return true;
}

// Execute DuckyScript
function executeDuckyScript(string $script): array {
    global $DUCKY_MAP;

    $results = [];
    $lines = explode("\n", str_replace("\r\n", "\n", $script));
    $defaultDelay = 0;

    foreach ($lines as $lineNum => $line) {
        $line = trim($line);
        if (empty($line) || strpos($line, '#') === 0 || strpos($line, 'REM') === 0) {
            continue;
        }

        $parts = preg_split('/\s+/', $line, 2);
        $command = strtoupper($parts[0]);
        $args = isset($parts[1]) ? $parts[1] : '';

        if ($command === 'STRING') {
            typeString($args);
            $results[] = "Typed: " . substr($args, 0, 50) . (strlen($args) > 50 ? '...' : '');
        } elseif ($command === 'DELAY') {
            $delayMs = intval($args);
            usleep($delayMs * 1000);
            $results[] = "Delayed: {$delayMs}ms";
        } elseif ($command === 'DEFAULT_DELAY' || $command === 'DEFAULTDELAY') {
            $defaultDelay = intval($args);
            $results[] = "Default delay set: {$defaultDelay}ms";
        } elseif ($command === 'REPEAT') {
            // Not implemented
            $results[] = "REPEAT not supported";
        } else {
            // Key press or combo
            $keyNames = preg_split('/\s+/', $line);
            $mappedKeys = [];
            foreach ($keyNames as $keyName) {
                $upper = strtoupper($keyName);
                if (isset($DUCKY_MAP[$upper])) {
                    $mappedKeys[] = $DUCKY_MAP[$upper];
                } else {
                    $mappedKeys[] = strtolower($keyName);
                }
            }

            if (count($mappedKeys) === 1) {
                pressKey($mappedKeys[0]);
            } else {
                pressCombo($mappedKeys);
            }
            $results[] = "Key(s): " . implode(' + ', $mappedKeys);
        }

        if ($defaultDelay > 0) {
            usleep($defaultDelay * 1000);
        }
    }

    return $results;
}

// Get network interface info
function getNetworkInfo(string $interface): array {
    $info = [
        'interface' => $interface,
        'exists' => false,
        'ip' => null,
        'netmask' => null,
        'broadcast' => null,
        'mac' => null,
        'gateway' => null,
        'dns' => [],
        'state' => 'down'
    ];

    // Check if interface exists
    if (!file_exists("/sys/class/net/{$interface}")) {
        return $info;
    }
    $info['exists'] = true;

    // Get state
    $state = @file_get_contents("/sys/class/net/{$interface}/operstate");
    if ($state !== false) {
        $info['state'] = trim($state);
    }

    // Get MAC address
    $mac = @file_get_contents("/sys/class/net/{$interface}/address");
    if ($mac !== false) {
        $info['mac'] = trim($mac);
    }

    // Get IP info using ip command
    $output = shell_exec("ip addr show {$interface} 2>/dev/null");
    if ($output) {
        if (preg_match('/inet (\d+\.\d+\.\d+\.\d+)\/(\d+)/', $output, $matches)) {
            $info['ip'] = $matches[1];
            $cidr = intval($matches[2]);
            $info['netmask'] = long2ip(-1 << (32 - $cidr));
        }
        if (preg_match('/brd (\d+\.\d+\.\d+\.\d+)/', $output, $matches)) {
            $info['broadcast'] = $matches[1];
        }
    }

    // Get gateway
    $routeOutput = shell_exec("ip route show dev {$interface} 2>/dev/null");
    if ($routeOutput && preg_match('/default via (\d+\.\d+\.\d+\.\d+)/', $routeOutput, $matches)) {
        $info['gateway'] = $matches[1];
    }

    // Get DNS from resolv.conf
    $resolvConf = @file_get_contents('/etc/resolv.conf');
    if ($resolvConf && preg_match_all('/nameserver\s+(\d+\.\d+\.\d+\.\d+)/', $resolvConf, $matches)) {
        $info['dns'] = $matches[1];
    }

    return $info;
}

// Get all network interfaces
function getAllNetworkInterfaces(): array {
    $interfaces = [];
    $dirs = @scandir('/sys/class/net');
    if ($dirs) {
        foreach ($dirs as $iface) {
            if ($iface[0] !== '.' && $iface !== 'lo') {
                $interfaces[] = $iface;
            }
        }
    }
    return $interfaces;
}

// Mount USB storage
function mountUSBStorage(): array {
    $result = ['success' => false, 'message' => '', 'mounted' => false];

    if (!file_exists(USB_IMAGE)) {
        $result['message'] = 'USB image not found: ' . USB_IMAGE;
        return $result;
    }

    // Create mount point if needed
    if (!is_dir(USB_MOUNT)) {
        if (!@mkdir(USB_MOUNT, 0755, true)) {
            $result['message'] = 'Cannot create mount point: ' . USB_MOUNT;
            return $result;
        }
    }

    // Check if already mounted
    $mounts = @file_get_contents('/proc/mounts');
    if ($mounts && strpos($mounts, USB_MOUNT) !== false) {
        $result['success'] = true;
        $result['mounted'] = true;
        $result['message'] = 'Already mounted';
        return $result;
    }

    // Mount the image
    $cmd = "sudo mount -o loop,rw " . escapeshellarg(USB_IMAGE) . " " . escapeshellarg(USB_MOUNT) . " 2>&1";
    $output = shell_exec($cmd);

    // Check if mount succeeded
    $mounts = @file_get_contents('/proc/mounts');
    if ($mounts && strpos($mounts, USB_MOUNT) !== false) {
        $result['success'] = true;
        $result['mounted'] = true;
        $result['message'] = 'Mounted successfully';
    } else {
        $result['message'] = 'Mount failed: ' . ($output ?: 'unknown error');
    }

    return $result;
}

// Unmount USB storage
function unmountUSBStorage(): array {
    $result = ['success' => false, 'message' => ''];

    $cmd = "sudo umount " . escapeshellarg(USB_MOUNT) . " 2>&1";
    $output = shell_exec($cmd);

    // Check if unmount succeeded
    $mounts = @file_get_contents('/proc/mounts');
    if ($mounts === false || strpos($mounts, USB_MOUNT) === false) {
        $result['success'] = true;
        $result['message'] = 'Unmounted successfully';
    } else {
        $result['message'] = 'Unmount failed: ' . ($output ?: 'unknown error');
    }

    return $result;
}

// Get USB storage files
function getUSBFiles(): array {
    $mount = mountUSBStorage();
    if (!$mount['mounted']) {
        return ['error' => $mount['message'], 'files' => []];
    }

    $files = [];
    $items = @scandir(USB_MOUNT);
    if ($items) {
        foreach ($items as $item) {
            if ($item[0] === '.') continue;
            $path = USB_MOUNT . '/' . $item;
            $files[] = [
                'name' => $item,
                'is_dir' => is_dir($path),
                'size' => is_file($path) ? filesize($path) : 0,
                'mtime' => filemtime($path)
            ];
        }
    }

    usort($files, function($a, $b) {
        if ($a['is_dir'] !== $b['is_dir']) return $a['is_dir'] ? -1 : 1;
        return strcasecmp($a['name'], $b['name']);
    });

    return ['error' => null, 'files' => $files];
}

// Get script files
function getScriptFiles(): array {
    $scripts = [];
    if (!is_dir(SCRIPTS_DIR)) {
        @mkdir(SCRIPTS_DIR, 0755, true);
    }
    $items = @scandir(SCRIPTS_DIR);
    if ($items) {
        foreach ($items as $item) {
            if ($item[0] === '.') continue;
            $path = SCRIPTS_DIR . '/' . $item;
            if (is_file($path) && pathinfo($item, PATHINFO_EXTENSION) === 'txt') {
                $scripts[] = [
                    'name' => $item,
                    'size' => filesize($path),
                    'mtime' => filemtime($path)
                ];
            }
        }
    }
    usort($scripts, function($a, $b) {
        return strcasecmp($a['name'], $b['name']);
    });
    return $scripts;
}

// ============ WiFi Management Functions ============

// Scan for available WiFi networks
function scanWifiNetworks(): array {
    $networks = [];

    // Use iwlist to scan for networks
    $output = shell_exec('sudo iwlist wlan0 scan 2>/dev/null');
    if (!$output) {
        // Try alternative: nmcli if available
        $output = shell_exec('nmcli -t -f SSID,SIGNAL,SECURITY device wifi list 2>/dev/null');
        if ($output) {
            $lines = explode("\n", trim($output));
            foreach ($lines as $line) {
                if (empty($line)) continue;
                $parts = explode(':', $line);
                if (count($parts) >= 2 && !empty($parts[0])) {
                    $networks[] = [
                        'ssid' => $parts[0],
                        'signal' => isset($parts[1]) ? intval($parts[1]) : 0,
                        'security' => isset($parts[2]) ? $parts[2] : 'Unknown'
                    ];
                }
            }
            return $networks;
        }
        return ['error' => 'WiFi scan failed'];
    }

    // Parse iwlist output
    $cells = preg_split('/Cell \d+ -/', $output);
    foreach ($cells as $cell) {
        if (empty(trim($cell))) continue;

        $ssid = '';
        $signal = 0;
        $security = 'Open';

        // Extract SSID
        if (preg_match('/ESSID:"([^"]*)"/', $cell, $matches)) {
            $ssid = $matches[1];
        }

        // Extract signal strength
        if (preg_match('/Signal level=(-?\d+)\s*dBm/', $cell, $matches)) {
            // Convert dBm to percentage (rough approximation)
            $dbm = intval($matches[1]);
            $signal = max(0, min(100, 2 * ($dbm + 100)));
        } elseif (preg_match('/Quality=(\d+)\/(\d+)/', $cell, $matches)) {
            $signal = intval(($matches[1] / $matches[2]) * 100);
        }

        // Check security
        if (preg_match('/Encryption key:on/', $cell)) {
            if (preg_match('/WPA2/', $cell)) {
                $security = 'WPA2';
            } elseif (preg_match('/WPA/', $cell)) {
                $security = 'WPA';
            } else {
                $security = 'WEP';
            }
        }

        if (!empty($ssid)) {
            $networks[] = [
                'ssid' => $ssid,
                'signal' => $signal,
                'security' => $security
            ];
        }
    }

    // Sort by signal strength
    usort($networks, function($a, $b) {
        return $b['signal'] - $a['signal'];
    });

    // Remove duplicates (keep strongest signal)
    $seen = [];
    $unique = [];
    foreach ($networks as $net) {
        if (!isset($seen[$net['ssid']])) {
            $seen[$net['ssid']] = true;
            $unique[] = $net;
        }
    }

    return $unique;
}

// Get currently connected WiFi network
function getCurrentWifi(): array {
    $result = [
        'connected' => false,
        'ssid' => null,
        'ip' => null
    ];

    // Get current SSID
    $ssid = trim(shell_exec('iwgetid -r 2>/dev/null') ?? '');
    if (!empty($ssid)) {
        $result['connected'] = true;
        $result['ssid'] = $ssid;
    }

    // Get IP address
    $output = shell_exec('ip addr show wlan0 2>/dev/null');
    if ($output && preg_match('/inet (\d+\.\d+\.\d+\.\d+)/', $output, $matches)) {
        $result['ip'] = $matches[1];
    }

    return $result;
}

// Connect to a WiFi network
function connectToWifi(string $ssid, string $password): array {
    $result = ['success' => false, 'message' => ''];

    if (empty($ssid)) {
        $result['message'] = 'SSID cannot be empty';
        return $result;
    }

    // Escape special characters for wpa_passphrase
    $ssidEscaped = escapeshellarg($ssid);
    $passwordEscaped = escapeshellarg($password);

    // Method 1: Try using wpa_cli (most reliable)
    $wpaConf = "/etc/wpa_supplicant/wpa_supplicant.conf";

    // Backup existing config
    shell_exec("sudo cp {$wpaConf} {$wpaConf}.bak 2>/dev/null");

    // Generate network block
    if (!empty($password)) {
        $pskOutput = shell_exec("wpa_passphrase {$ssidEscaped} {$passwordEscaped} 2>/dev/null");
        if ($pskOutput && preg_match('/psk=([a-f0-9]{64})/', $pskOutput, $matches)) {
            $psk = $matches[1];
            $networkBlock = "\nnetwork={\n    ssid=\"{$ssid}\"\n    psk={$psk}\n    key_mgmt=WPA-PSK\n}\n";
        } else {
            $result['message'] = 'Failed to generate PSK';
            return $result;
        }
    } else {
        // Open network
        $networkBlock = "\nnetwork={\n    ssid=\"{$ssid}\"\n    key_mgmt=NONE\n}\n";
    }

    // Read current config
    $currentConfig = @file_get_contents($wpaConf);
    if ($currentConfig === false) {
        // Create new config
        $currentConfig = "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\nupdate_config=1\ncountry=US\n";
    }

    // Remove existing network block for this SSID (if any)
    $currentConfig = preg_replace('/\nnetwork=\{[^}]*ssid="' . preg_quote($ssid, '/') . '"[^}]*\}\n?/', "\n", $currentConfig);

    // Add new network block
    $newConfig = trim($currentConfig) . "\n" . $networkBlock;

    // Write config
    $tempFile = '/tmp/wpa_supplicant_new.conf';
    if (file_put_contents($tempFile, $newConfig) === false) {
        $result['message'] = 'Failed to write config';
        return $result;
    }

    // Apply new config
    shell_exec("sudo cp {$tempFile} {$wpaConf}");
    shell_exec("sudo chmod 600 {$wpaConf}");

    // Reconfigure wpa_supplicant
    shell_exec("sudo wpa_cli -i wlan0 reconfigure 2>/dev/null");

    // Wait for connection (up to 15 seconds)
    for ($i = 0; $i < 15; $i++) {
        sleep(1);
        $currentSsid = trim(shell_exec('iwgetid -r 2>/dev/null') ?? '');
        if ($currentSsid === $ssid) {
            $result['success'] = true;
            $result['message'] = "Connected to {$ssid}";

            // Get IP (may take a moment)
            sleep(2);
            $ip = getCurrentWifi()['ip'];
            if ($ip) {
                $result['message'] .= " (IP: {$ip})";
            }
            return $result;
        }
    }

    $result['message'] = "Failed to connect to {$ssid}. Check password and try again.";
    return $result;
}

// Disconnect from current WiFi
function disconnectWifi(): array {
    shell_exec('sudo wpa_cli -i wlan0 disconnect 2>/dev/null');
    return ['success' => true, 'message' => 'Disconnected from WiFi'];
}

// Handle AJAX requests
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
    header('Content-Type: application/json');
    $response = ['success' => false, 'message' => ''];

    switch ($_POST['action']) {
        case 'send_key':
            $key = $_POST['key'] ?? '';
            $modifier = intval($_POST['modifier'] ?? 0);
            if ($key) {
                $response['success'] = pressKey($key, $modifier);
                $response['message'] = $response['success'] ? 'Key sent' : 'Failed to send key';
            }
            break;

        case 'send_combo':
            $keys = $_POST['keys'] ?? '';
            if ($keys) {
                $keyArray = explode(' ', $keys);
                $response['success'] = pressCombo($keyArray);
                $response['message'] = $response['success'] ? 'Combo sent' : 'Failed to send combo';
            }
            break;

        case 'type_string':
            $text = $_POST['text'] ?? '';
            if ($text) {
                $response['success'] = typeString($text);
                $response['message'] = $response['success'] ? 'Text typed' : 'Failed to type text';
            }
            break;

        case 'run_script':
            $scriptName = $_POST['script'] ?? '';
            $scriptPath = SCRIPTS_DIR . '/' . basename($scriptName);
            if (file_exists($scriptPath)) {
                $content = file_get_contents($scriptPath);
                $results = executeDuckyScript($content);
                $response['success'] = true;
                $response['message'] = 'Script executed';
                $response['results'] = $results;
            } else {
                $response['message'] = 'Script not found';
            }
            break;

        case 'run_ducky':
            $script = $_POST['script'] ?? '';
            if ($script) {
                $results = executeDuckyScript($script);
                $response['success'] = true;
                $response['message'] = 'DuckyScript executed';
                $response['results'] = $results;
            }
            break;

        case 'get_script':
            $scriptName = $_POST['script'] ?? '';
            $scriptPath = SCRIPTS_DIR . '/' . basename($scriptName);
            if (file_exists($scriptPath)) {
                $response['success'] = true;
                $response['content'] = file_get_contents($scriptPath);
            } else {
                $response['message'] = 'Script not found';
            }
            break;

        case 'save_script':
            $scriptName = $_POST['name'] ?? '';
            $content = $_POST['content'] ?? '';
            if ($scriptName) {
                // Ensure .txt extension
                if (pathinfo($scriptName, PATHINFO_EXTENSION) !== 'txt') {
                    $scriptName .= '.txt';
                }
                // Sanitize filename
                $scriptName = preg_replace('/[^a-zA-Z0-9_\-\.]/', '', $scriptName);
                $scriptPath = SCRIPTS_DIR . '/' . $scriptName;

                if (!is_dir(SCRIPTS_DIR)) {
                    @mkdir(SCRIPTS_DIR, 0755, true);
                }

                if (file_put_contents($scriptPath, $content) !== false) {
                    $response['success'] = true;
                    $response['message'] = 'Script saved';
                    $response['filename'] = $scriptName;
                } else {
                    $response['message'] = 'Failed to save script';
                }
            }
            break;

        case 'delete_script':
            $scriptName = $_POST['script'] ?? '';
            $scriptPath = SCRIPTS_DIR . '/' . basename($scriptName);
            if (file_exists($scriptPath) && unlink($scriptPath)) {
                $response['success'] = true;
                $response['message'] = 'Script deleted';
            } else {
                $response['message'] = 'Failed to delete script';
            }
            break;

        case 'list_scripts':
            $response['success'] = true;
            $response['scripts'] = getScriptFiles();
            break;

        case 'upload_file':
            if (isset($_FILES['file'])) {
                $destination = $_POST['destination'] ?? 'usb';
                $filename = basename($_FILES['file']['name']);
                $uploadError = $_FILES['file']['error'];

                // Check for upload errors first
                if ($uploadError !== UPLOAD_ERR_OK) {
                    $errorMessages = [
                        UPLOAD_ERR_INI_SIZE => 'File exceeds upload_max_filesize',
                        UPLOAD_ERR_FORM_SIZE => 'File exceeds MAX_FILE_SIZE',
                        UPLOAD_ERR_PARTIAL => 'File only partially uploaded',
                        UPLOAD_ERR_NO_FILE => 'No file was uploaded',
                        UPLOAD_ERR_NO_TMP_DIR => 'Missing temp folder',
                        UPLOAD_ERR_CANT_WRITE => 'Failed to write to disk',
                        UPLOAD_ERR_EXTENSION => 'Upload stopped by extension'
                    ];
                    $response['message'] = $errorMessages[$uploadError] ?? 'Upload error: ' . $uploadError;
                    break;
                }

                if ($destination === 'webserver') {
                    // Upload to webserver directory
                    if (!is_dir(WEBSERVER_UPLOADS)) {
                        @mkdir(WEBSERVER_UPLOADS, 0755, true);
                    }
                    $destPath = WEBSERVER_UPLOADS . '/' . $filename;
                    if (move_uploaded_file($_FILES['file']['tmp_name'], $destPath)) {
                        $response['success'] = true;
                        $response['message'] = 'Uploaded to webserver: ' . $filename;
                    } else {
                        $response['message'] = 'Failed to save file to webserver';
                    }
                } else {
                    // Upload to USB mass storage
                    $mount = mountUSBStorage();
                    if ($mount['mounted']) {
                        $destPath = USB_MOUNT . '/' . $filename;
                        if (move_uploaded_file($_FILES['file']['tmp_name'], $destPath)) {
                            // Sync filesystem to ensure data is written
                            shell_exec('sync');
                            // Unmount so Windows can see the changes
                            unmountUSBStorage();
                            $response['success'] = true;
                            $response['message'] = 'Uploaded to USB: ' . $filename . ' (unmounted for Windows access)';
                        } else {
                            $response['message'] = 'Failed to copy file to USB storage';
                        }
                    } else {
                        $response['message'] = 'USB storage not available: ' . $mount['message'];
                    }
                }
            } else {
                $response['message'] = 'No file uploaded';
            }
            break;

        case 'list_webserver_files':
            if (!is_dir(WEBSERVER_UPLOADS)) {
                @mkdir(WEBSERVER_UPLOADS, 0755, true);
            }
            $files = [];
            $items = @scandir(WEBSERVER_UPLOADS);
            if ($items) {
                foreach ($items as $item) {
                    if ($item[0] === '.') continue;
                    $path = WEBSERVER_UPLOADS . '/' . $item;
                    if (is_file($path)) {
                        $files[] = [
                            'name' => $item,
                            'size' => filesize($path),
                            'mtime' => filemtime($path)
                        ];
                    }
                }
            }
            usort($files, function($a, $b) { return strcasecmp($a['name'], $b['name']); });
            $response['success'] = true;
            $response['files'] = $files;
            break;

        case 'delete_webserver_file':
            $filename = $_POST['filename'] ?? '';
            if ($filename) {
                $filePath = WEBSERVER_UPLOADS . '/' . basename($filename);
                if (file_exists($filePath) && is_file($filePath) && unlink($filePath)) {
                    $response['success'] = true;
                    $response['message'] = 'File deleted';
                } else {
                    $response['message'] = 'Failed to delete file';
                }
            }
            break;

        case 'list_usb_files':
            $result = getUSBFiles();
            $response['success'] = ($result['error'] === null);
            $response['files'] = $result['files'];
            $response['message'] = $result['error'] ?? 'OK';
            break;

        case 'delete_usb_file':
            $filename = $_POST['filename'] ?? '';
            if ($filename) {
                $mount = mountUSBStorage();
                if ($mount['mounted']) {
                    $filePath = USB_MOUNT . '/' . basename($filename);
                    if (file_exists($filePath)) {
                        if (is_dir($filePath)) {
                            $response['message'] = 'Cannot delete directories';
                        } elseif (unlink($filePath)) {
                            $response['success'] = true;
                            $response['message'] = 'File deleted';
                        } else {
                            $response['message'] = 'Failed to delete file';
                        }
                    } else {
                        $response['message'] = 'File not found';
                    }
                } else {
                    $response['message'] = 'USB storage not available';
                }
            }
            break;

        case 'get_network':
            $interfaces = getAllNetworkInterfaces();
            $networkData = [];
            foreach ($interfaces as $iface) {
                $networkData[$iface] = getNetworkInfo($iface);
            }
            $response['success'] = true;
            $response['interfaces'] = $networkData;
            break;

        case 'wifi_scan':
            $networks = scanWifiNetworks();
            if (isset($networks['error'])) {
                $response['message'] = $networks['error'];
            } else {
                $response['success'] = true;
                $response['networks'] = $networks;
            }
            break;

        case 'wifi_status':
            $response['success'] = true;
            $response['wifi'] = getCurrentWifi();
            break;

        case 'wifi_connect':
            $ssid = $_POST['ssid'] ?? '';
            $password = $_POST['password'] ?? '';
            $result = connectToWifi($ssid, $password);
            $response['success'] = $result['success'];
            $response['message'] = $result['message'];
            break;

        case 'wifi_disconnect':
            $result = disconnectWifi();
            $response['success'] = $result['success'];
            $response['message'] = $result['message'];
            break;
    }

    echo json_encode($response);
    exit;
}

// Get initial data
$scripts = getScriptFiles();
$hidAvailable = file_exists(HID_DEVICE);
$usbImageExists = file_exists(USB_IMAGE);

// Logo path
$docroot = $_SERVER['DOCUMENT_ROOT'] ?? __DIR__;
$logoPath = '';
foreach (['images/picycle.png', 'assets/images/picycle.png', 'picycle.png'] as $try) {
    if (file_exists($docroot . '/' . $try)) {
        $logoPath = '/' . $try;
        break;
    }
}

header('Content-Type: text/html; charset=utf-8');
?><!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>PiCycle Control Panel</title>
    <style>
        * { box-sizing: border-box; }
        body {
            font-family: Arial, Helvetica, sans-serif;
            margin: 0;
            padding: 18px;
            line-height: 1.4;
            background: #f5f5f5;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        .header {
            display: flex;
            align-items: center;
            gap: 20px;
            margin-bottom: 20px;
        }
        .header img { max-width: 150px; height: auto; }
        .header h1 { margin: 0; color: #333; }

        .card {
            background: white;
            border: 1px solid #ddd;
            border-radius: 10px;
            padding: 16px;
            margin-bottom: 16px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.05);
        }
        .card h3 {
            margin: 0 0 12px 0;
            padding-bottom: 8px;
            border-bottom: 2px solid #007bff;
            color: #333;
        }

        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(350px, 1fr)); gap: 16px; }

        .status { display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 12px; }
        .status-ok { background: #d4edda; color: #155724; }
        .status-error { background: #f8d7da; color: #721c24; }
        .status-warn { background: #fff3cd; color: #856404; }

        table { width: 100%; border-collapse: collapse; font-size: 14px; }
        td, th { padding: 6px 8px; text-align: left; border-bottom: 1px solid #eee; }
        th { background: #f8f9fa; font-weight: 600; }

        .mono { font-family: Consolas, Monaco, 'Courier New', monospace; }

        button, .btn {
            display: inline-block;
            padding: 8px 16px;
            background: #007bff;
            color: white;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 14px;
            text-decoration: none;
        }
        button:hover, .btn:hover { background: #0056b3; }
        button:disabled { background: #ccc; cursor: not-allowed; }
        .btn-success { background: #28a745; }
        .btn-success:hover { background: #1e7e34; }
        .btn-danger { background: #dc3545; }
        .btn-danger:hover { background: #bd2130; }
        .btn-secondary { background: #6c757d; }
        .btn-secondary:hover { background: #545b62; }
        .btn-sm { padding: 4px 10px; font-size: 12px; }

        input[type="text"], input[type="file"], select, textarea {
            width: 100%;
            padding: 8px 12px;
            border: 1px solid #ddd;
            border-radius: 5px;
            font-size: 14px;
            font-family: inherit;
        }
        textarea { resize: vertical; min-height: 150px; font-family: Consolas, Monaco, monospace; }

        .form-group { margin-bottom: 12px; }
        .form-group label { display: block; margin-bottom: 4px; font-weight: 600; }

        .keyboard-container { margin-top: 12px; overflow-x: auto; }
        .keyboard-row { display: flex; gap: 3px; margin-bottom: 3px; justify-content: center; flex-wrap: wrap; }
        .key {
            min-width: 32px;
            height: 32px;
            padding: 0 4px;
            display: flex;
            align-items: center;
            justify-content: center;
            background: linear-gradient(180deg, #f8f9fa 0%, #e9ecef 100%);
            border: 1px solid #bbb;
            border-radius: 4px;
            cursor: pointer;
            font-size: 11px;
            font-weight: 500;
            user-select: none;
            transition: all 0.1s;
            flex-shrink: 0;
        }
        .key:hover { background: linear-gradient(180deg, #e9ecef 0%, #dee2e6 100%); }
        .key:active, .key.active {
            background: linear-gradient(180deg, #007bff 0%, #0056b3 100%);
            color: white;
            border-color: #004085;
        }
        .key-wide { min-width: 50px; }
        .key-wider { min-width: 65px; }
        .key-widest { min-width: 75px; }
        .key-space { min-width: 180px; }
        .key-fn { background: linear-gradient(180deg, #6c757d 0%, #545b62 100%); color: white; min-width: 36px; }
        .key-mod { background: linear-gradient(180deg, #495057 0%, #343a40 100%); color: white; }

        .modifier-row { margin-bottom: 10px; }
        .modifier-row label {
            display: inline-flex;
            align-items: center;
            margin-right: 15px;
            cursor: pointer;
        }
        .modifier-row input { margin-right: 5px; }

        .text-input-group { display: flex; gap: 8px; margin-bottom: 12px; }
        .text-input-group input { flex: 1; }

        .file-list { max-height: 200px; overflow-y: auto; }
        .file-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 6px 0;
            border-bottom: 1px solid #eee;
        }
        .file-item:last-child { border-bottom: none; }
        .file-info { display: flex; gap: 15px; font-size: 13px; color: #666; }

        .radio-group { display: flex; gap: 20px; margin-top: 4px; }
        .radio-label {
            display: inline-flex;
            align-items: center;
            cursor: pointer;
            font-weight: normal;
        }
        .radio-label input { margin-right: 6px; }

        .script-controls { display: flex; gap: 8px; margin-bottom: 12px; flex-wrap: wrap; }
        .script-controls select { max-width: 200px; }

        .log {
            background: #1e1e1e;
            color: #0f0;
            padding: 10px;
            border-radius: 5px;
            font-family: Consolas, Monaco, monospace;
            font-size: 12px;
            max-height: 150px;
            overflow-y: auto;
        }
        .log-entry { margin: 2px 0; }
        .log-error { color: #f44; }
        .log-success { color: #4f4; }

        .tabs { display: flex; border-bottom: 2px solid #ddd; margin-bottom: 12px; }
        .tab {
            padding: 8px 16px;
            cursor: pointer;
            border-bottom: 2px solid transparent;
            margin-bottom: -2px;
            color: #666;
        }
        .tab:hover { color: #333; }
        .tab.active { border-bottom-color: #007bff; color: #007bff; font-weight: 600; }
        .tab-content { display: none; }
        .tab-content.active { display: block; }

        /* Desktop keyboard visibility */
        .keyboard-desktop { display: block; }
        .keyboard-mobile { display: none; }

        @media (max-width: 768px) {
            body { padding: 10px; }
            .grid { grid-template-columns: 1fr; }
            .header { flex-direction: column; text-align: center; gap: 10px; }
            .header img { max-width: 100px; }

            /* Hide desktop keyboard on mobile */
            .keyboard-desktop { display: none; }
            .keyboard-mobile { display: block; }

            /* Mobile keyboard styles */
            .mobile-keyboard { margin-top: 10px; }
            .mobile-key-row { display: flex; gap: 4px; margin-bottom: 4px; justify-content: center; }
            .mobile-key {
                flex: 1;
                max-width: 42px;
                height: 48px;
                display: flex;
                align-items: center;
                justify-content: center;
                background: linear-gradient(180deg, #f8f9fa 0%, #e9ecef 100%);
                border: 1px solid #bbb;
                border-radius: 6px;
                cursor: pointer;
                font-size: 16px;
                font-weight: 500;
                user-select: none;
                transition: all 0.1s;
                -webkit-tap-highlight-color: transparent;
            }
            .mobile-key:active {
                background: linear-gradient(180deg, #007bff 0%, #0056b3 100%);
                color: white;
                transform: scale(0.95);
            }
            .mobile-key.active {
                background: linear-gradient(180deg, #007bff 0%, #0056b3 100%);
                color: white;
            }
            .mobile-key-wide { max-width: 60px; flex: 1.4; font-size: 12px; }
            .mobile-key-wider { max-width: 75px; flex: 1.7; font-size: 12px; }
            .mobile-key-space { max-width: none; flex: 4; }
            .mobile-key-special {
                background: linear-gradient(180deg, #495057 0%, #343a40 100%);
                color: white;
                font-size: 12px;
            }
            .mobile-key-action {
                background: linear-gradient(180deg, #28a745 0%, #1e7e34 100%);
                color: white;
            }

            .mobile-layer-tabs {
                display: flex;
                gap: 6px;
                margin-bottom: 10px;
                justify-content: center;
            }
            .mobile-layer-tab {
                padding: 8px 16px;
                background: #e9ecef;
                border: 1px solid #bbb;
                border-radius: 6px;
                cursor: pointer;
                font-size: 14px;
                font-weight: 500;
            }
            .mobile-layer-tab.active {
                background: #007bff;
                color: white;
                border-color: #0056b3;
            }
            .mobile-layer { display: none; }
            .mobile-layer.active { display: block; }

            /* Quick actions for mobile */
            .mobile-quick-actions {
                display: flex;
                gap: 6px;
                margin-bottom: 10px;
                flex-wrap: wrap;
                justify-content: center;
            }
            .mobile-quick-btn {
                padding: 10px 14px;
                background: #6c757d;
                color: white;
                border: none;
                border-radius: 6px;
                font-size: 12px;
                cursor: pointer;
            }
            .mobile-quick-btn:active {
                background: #495057;
            }
        }
    </style>
</head>
<body>
<div class="container">
    <div class="header">
        <?php if ($logoPath): ?>
            <img src="<?= h($logoPath) ?>" alt="PiCycle">
        <?php endif; ?>
        <div>
            <h1>PiCycle Control Panel</h1>
            <div style="margin-top: 5px;">
                <span class="status <?= $hidAvailable ? 'status-ok' : 'status-error' ?>">
                    HID: <?= $hidAvailable ? 'Ready' : 'Not Available' ?>
                </span>
                <span class="status <?= $usbImageExists ? 'status-ok' : 'status-warn' ?>">
                    USB Storage: <?= $usbImageExists ? 'Ready' : 'Not Found' ?>
                </span>
            </div>
        </div>
    </div>

    <div class="grid">
        <!-- Virtual Keyboard -->
        <div class="card">
            <h3>Virtual Keyboard</h3>

            <div class="text-input-group">
                <input type="text" id="textInput" placeholder="Type text to send...">
                <button onclick="sendText()">Send Text</button>
            </div>

            <div class="modifier-row">
                <label><input type="checkbox" id="mod-ctrl"> Ctrl</label>
                <label><input type="checkbox" id="mod-shift"> Shift</label>
                <label><input type="checkbox" id="mod-alt"> Alt</label>
                <label><input type="checkbox" id="mod-gui"> Win/Cmd</label>
            </div>

            <!-- Desktop Keyboard -->
            <div class="keyboard-container keyboard-desktop">
                <!-- Function keys -->
                <div class="keyboard-row">
                    <div class="key key-fn" data-key="esc">Esc</div>
                    <div class="key key-fn" data-key="f1">F1</div>
                    <div class="key key-fn" data-key="f2">F2</div>
                    <div class="key key-fn" data-key="f3">F3</div>
                    <div class="key key-fn" data-key="f4">F4</div>
                    <div class="key key-fn" data-key="f5">F5</div>
                    <div class="key key-fn" data-key="f6">F6</div>
                    <div class="key key-fn" data-key="f7">F7</div>
                    <div class="key key-fn" data-key="f8">F8</div>
                    <div class="key key-fn" data-key="f9">F9</div>
                    <div class="key key-fn" data-key="f10">F10</div>
                    <div class="key key-fn" data-key="f11">F11</div>
                    <div class="key key-fn" data-key="f12">F12</div>
                </div>

                <!-- Number row -->
                <div class="keyboard-row">
                    <div class="key" data-key="`">`</div>
                    <div class="key" data-key="1">1</div>
                    <div class="key" data-key="2">2</div>
                    <div class="key" data-key="3">3</div>
                    <div class="key" data-key="4">4</div>
                    <div class="key" data-key="5">5</div>
                    <div class="key" data-key="6">6</div>
                    <div class="key" data-key="7">7</div>
                    <div class="key" data-key="8">8</div>
                    <div class="key" data-key="9">9</div>
                    <div class="key" data-key="0">0</div>
                    <div class="key" data-key="-">-</div>
                    <div class="key" data-key="=">=</div>
                    <div class="key key-wide" data-key="backspace">Back</div>
                </div>

                <!-- QWERTY row -->
                <div class="keyboard-row">
                    <div class="key key-wide" data-key="tab">Tab</div>
                    <div class="key" data-key="q">Q</div>
                    <div class="key" data-key="w">W</div>
                    <div class="key" data-key="e">E</div>
                    <div class="key" data-key="r">R</div>
                    <div class="key" data-key="t">T</div>
                    <div class="key" data-key="y">Y</div>
                    <div class="key" data-key="u">U</div>
                    <div class="key" data-key="i">I</div>
                    <div class="key" data-key="o">O</div>
                    <div class="key" data-key="p">P</div>
                    <div class="key" data-key="[">[</div>
                    <div class="key" data-key="]">]</div>
                    <div class="key" data-key="\">\</div>
                </div>

                <!-- Home row -->
                <div class="keyboard-row">
                    <div class="key key-wider" data-key="caps">Caps</div>
                    <div class="key" data-key="a">A</div>
                    <div class="key" data-key="s">S</div>
                    <div class="key" data-key="d">D</div>
                    <div class="key" data-key="f">F</div>
                    <div class="key" data-key="g">G</div>
                    <div class="key" data-key="h">H</div>
                    <div class="key" data-key="j">J</div>
                    <div class="key" data-key="k">K</div>
                    <div class="key" data-key="l">L</div>
                    <div class="key" data-key=";">;</div>
                    <div class="key" data-key="'">'</div>
                    <div class="key key-wider" data-key="enter">Enter</div>
                </div>

                <!-- Shift row -->
                <div class="keyboard-row">
                    <div class="key key-widest key-mod" data-modifier="shift">Shift</div>
                    <div class="key" data-key="z">Z</div>
                    <div class="key" data-key="x">X</div>
                    <div class="key" data-key="c">C</div>
                    <div class="key" data-key="v">V</div>
                    <div class="key" data-key="b">B</div>
                    <div class="key" data-key="n">N</div>
                    <div class="key" data-key="m">M</div>
                    <div class="key" data-key=",">,</div>
                    <div class="key" data-key=".">.</div>
                    <div class="key" data-key="/">/</div>
                    <div class="key key-widest key-mod" data-modifier="shift">Shift</div>
                </div>

                <!-- Bottom row -->
                <div class="keyboard-row">
                    <div class="key key-wide key-mod" data-modifier="ctrl">Ctrl</div>
                    <div class="key key-wide key-mod" data-modifier="gui">Win</div>
                    <div class="key key-wide key-mod" data-modifier="alt">Alt</div>
                    <div class="key key-space" data-key="space">Space</div>
                    <div class="key key-wide key-mod" data-modifier="alt">Alt</div>
                    <div class="key key-wide key-mod" data-modifier="gui">Win</div>
                    <div class="key key-wide key-mod" data-modifier="ctrl">Ctrl</div>
                </div>

                <!-- Navigation row -->
                <div class="keyboard-row" style="margin-top: 8px;">
                    <div class="key key-fn" data-key="print">PrtSc</div>
                    <div class="key key-fn" data-key="scroll">ScrLk</div>
                    <div class="key key-fn" data-key="pause">Pause</div>
                    <div class="key key-fn" data-key="insert">Ins</div>
                    <div class="key key-fn" data-key="home">Home</div>
                    <div class="key key-fn" data-key="pageup">PgUp</div>
                    <div class="key key-fn" data-key="delete">Del</div>
                    <div class="key key-fn" data-key="end">End</div>
                    <div class="key key-fn" data-key="pagedown">PgDn</div>
                </div>

                <!-- Arrow keys -->
                <div class="keyboard-row">
                    <div class="key" data-key="up">&#9650;</div>
                </div>
                <div class="keyboard-row">
                    <div class="key" data-key="left">&#9664;</div>
                    <div class="key" data-key="down">&#9660;</div>
                    <div class="key" data-key="right">&#9654;</div>
                </div>
            </div>

            <!-- Mobile Keyboard -->
            <div class="keyboard-container keyboard-mobile">
                <!-- Quick action buttons -->
                <div class="mobile-quick-actions">
                    <button class="mobile-quick-btn" onclick="sendMobileCombo('ctrl', 'c')">Ctrl+C</button>
                    <button class="mobile-quick-btn" onclick="sendMobileCombo('ctrl', 'v')">Ctrl+V</button>
                    <button class="mobile-quick-btn" onclick="sendMobileCombo('ctrl', 'z')">Ctrl+Z</button>
                    <button class="mobile-quick-btn" onclick="sendMobileCombo('ctrl', 'a')">Ctrl+A</button>
                    <button class="mobile-quick-btn" onclick="sendMobileCombo('alt', 'tab')">Alt+Tab</button>
                    <button class="mobile-quick-btn" onclick="sendMobileCombo('gui', 'r')">Win+R</button>
                </div>

                <!-- Layer tabs -->
                <div class="mobile-layer-tabs">
                    <div class="mobile-layer-tab active" data-layer="abc">ABC</div>
                    <div class="mobile-layer-tab" data-layer="num">123</div>
                    <div class="mobile-layer-tab" data-layer="fn">Fn</div>
                    <div class="mobile-layer-tab" data-layer="nav">Nav</div>
                </div>

                <!-- ABC Layer (Letters) -->
                <div class="mobile-layer active" id="layer-abc">
                    <div class="mobile-key-row">
                        <div class="mobile-key" data-key="q">Q</div>
                        <div class="mobile-key" data-key="w">W</div>
                        <div class="mobile-key" data-key="e">E</div>
                        <div class="mobile-key" data-key="r">R</div>
                        <div class="mobile-key" data-key="t">T</div>
                        <div class="mobile-key" data-key="y">Y</div>
                        <div class="mobile-key" data-key="u">U</div>
                        <div class="mobile-key" data-key="i">I</div>
                        <div class="mobile-key" data-key="o">O</div>
                        <div class="mobile-key" data-key="p">P</div>
                    </div>
                    <div class="mobile-key-row">
                        <div class="mobile-key" data-key="a">A</div>
                        <div class="mobile-key" data-key="s">S</div>
                        <div class="mobile-key" data-key="d">D</div>
                        <div class="mobile-key" data-key="f">F</div>
                        <div class="mobile-key" data-key="g">G</div>
                        <div class="mobile-key" data-key="h">H</div>
                        <div class="mobile-key" data-key="j">J</div>
                        <div class="mobile-key" data-key="k">K</div>
                        <div class="mobile-key" data-key="l">L</div>
                    </div>
                    <div class="mobile-key-row">
                        <div class="mobile-key mobile-key-wide mobile-key-special" data-mobile-modifier="shift" id="mobile-shift">Shift</div>
                        <div class="mobile-key" data-key="z">Z</div>
                        <div class="mobile-key" data-key="x">X</div>
                        <div class="mobile-key" data-key="c">C</div>
                        <div class="mobile-key" data-key="v">V</div>
                        <div class="mobile-key" data-key="b">B</div>
                        <div class="mobile-key" data-key="n">N</div>
                        <div class="mobile-key" data-key="m">M</div>
                        <div class="mobile-key mobile-key-wide" data-key="backspace">&#9003;</div>
                    </div>
                    <div class="mobile-key-row">
                        <div class="mobile-key mobile-key-wide mobile-key-special" data-mobile-modifier="ctrl" id="mobile-ctrl">Ctrl</div>
                        <div class="mobile-key mobile-key-wide mobile-key-special" data-mobile-modifier="alt" id="mobile-alt">Alt</div>
                        <div class="mobile-key mobile-key-space" data-key="space">Space</div>
                        <div class="mobile-key" data-key=".">.</div>
                        <div class="mobile-key mobile-key-wider mobile-key-action" data-key="enter">Enter</div>
                    </div>
                </div>

                <!-- Numbers/Symbols Layer -->
                <div class="mobile-layer" id="layer-num">
                    <div class="mobile-key-row">
                        <div class="mobile-key" data-key="1">1</div>
                        <div class="mobile-key" data-key="2">2</div>
                        <div class="mobile-key" data-key="3">3</div>
                        <div class="mobile-key" data-key="4">4</div>
                        <div class="mobile-key" data-key="5">5</div>
                        <div class="mobile-key" data-key="6">6</div>
                        <div class="mobile-key" data-key="7">7</div>
                        <div class="mobile-key" data-key="8">8</div>
                        <div class="mobile-key" data-key="9">9</div>
                        <div class="mobile-key" data-key="0">0</div>
                    </div>
                    <div class="mobile-key-row">
                        <div class="mobile-key" data-key="-">-</div>
                        <div class="mobile-key" data-key="/">/</div>
                        <div class="mobile-key" data-key=":">:</div>
                        <div class="mobile-key" data-key=";">;</div>
                        <div class="mobile-key" data-key="(">(</div>
                        <div class="mobile-key" data-key=")">)</div>
                        <div class="mobile-key" data-key="$">$</div>
                        <div class="mobile-key" data-key="&">&</div>
                        <div class="mobile-key" data-key="@">@</div>
                    </div>
                    <div class="mobile-key-row">
                        <div class="mobile-key mobile-key-wide mobile-key-special" onclick="switchMobileSymbols()">#+=</div>
                        <div class="mobile-key" data-key=".">.</div>
                        <div class="mobile-key" data-key=",">,</div>
                        <div class="mobile-key" data-key="?">?</div>
                        <div class="mobile-key" data-key="!">!</div>
                        <div class="mobile-key" data-key="'">'</div>
                        <div class="mobile-key" data-key='"'>"</div>
                        <div class="mobile-key mobile-key-wide" data-key="backspace">&#9003;</div>
                    </div>
                    <div class="mobile-key-row">
                        <div class="mobile-key mobile-key-wide mobile-key-special" data-mobile-modifier="ctrl" id="mobile-ctrl-num">Ctrl</div>
                        <div class="mobile-key mobile-key-wide mobile-key-special" data-mobile-modifier="alt" id="mobile-alt-num">Alt</div>
                        <div class="mobile-key mobile-key-space" data-key="space">Space</div>
                        <div class="mobile-key" data-key=".">.</div>
                        <div class="mobile-key mobile-key-wider mobile-key-action" data-key="enter">Enter</div>
                    </div>
                </div>

                <!-- Function Keys Layer -->
                <div class="mobile-layer" id="layer-fn">
                    <div class="mobile-key-row">
                        <div class="mobile-key" data-key="esc">Esc</div>
                        <div class="mobile-key" data-key="f1">F1</div>
                        <div class="mobile-key" data-key="f2">F2</div>
                        <div class="mobile-key" data-key="f3">F3</div>
                        <div class="mobile-key" data-key="f4">F4</div>
                        <div class="mobile-key" data-key="f5">F5</div>
                        <div class="mobile-key" data-key="f6">F6</div>
                    </div>
                    <div class="mobile-key-row">
                        <div class="mobile-key" data-key="f7">F7</div>
                        <div class="mobile-key" data-key="f8">F8</div>
                        <div class="mobile-key" data-key="f9">F9</div>
                        <div class="mobile-key" data-key="f10">F10</div>
                        <div class="mobile-key" data-key="f11">F11</div>
                        <div class="mobile-key" data-key="f12">F12</div>
                    </div>
                    <div class="mobile-key-row">
                        <div class="mobile-key" data-key="print">PrtSc</div>
                        <div class="mobile-key" data-key="scroll">ScrLk</div>
                        <div class="mobile-key" data-key="pause">Pause</div>
                        <div class="mobile-key" data-key="tab">Tab</div>
                        <div class="mobile-key" data-key="caps">Caps</div>
                    </div>
                    <div class="mobile-key-row">
                        <div class="mobile-key mobile-key-wide mobile-key-special" data-mobile-modifier="ctrl">Ctrl</div>
                        <div class="mobile-key mobile-key-wide mobile-key-special" data-mobile-modifier="shift">Shift</div>
                        <div class="mobile-key mobile-key-wide mobile-key-special" data-mobile-modifier="alt">Alt</div>
                        <div class="mobile-key mobile-key-wide mobile-key-special" data-mobile-modifier="gui">Win</div>
                        <div class="mobile-key mobile-key-wide" data-key="backspace">&#9003;</div>
                    </div>
                </div>

                <!-- Navigation Layer -->
                <div class="mobile-layer" id="layer-nav">
                    <div class="mobile-key-row">
                        <div class="mobile-key" data-key="insert">Ins</div>
                        <div class="mobile-key" data-key="home">Home</div>
                        <div class="mobile-key" data-key="pageup">PgUp</div>
                        <div class="mobile-key" data-key="up">&#9650;</div>
                        <div class="mobile-key" data-key="pagedown">PgDn</div>
                        <div class="mobile-key" data-key="end">End</div>
                    </div>
                    <div class="mobile-key-row">
                        <div class="mobile-key" data-key="delete">Del</div>
                        <div class="mobile-key"></div>
                        <div class="mobile-key" data-key="left">&#9664;</div>
                        <div class="mobile-key" data-key="down">&#9660;</div>
                        <div class="mobile-key" data-key="right">&#9654;</div>
                        <div class="mobile-key"></div>
                    </div>
                    <div class="mobile-key-row">
                        <div class="mobile-key" data-key="tab">Tab</div>
                        <div class="mobile-key" data-key="backspace">Bksp</div>
                        <div class="mobile-key mobile-key-action" data-key="enter">Enter</div>
                        <div class="mobile-key" data-key="esc">Esc</div>
                        <div class="mobile-key" data-key="space">Space</div>
                    </div>
                    <div class="mobile-key-row">
                        <div class="mobile-key mobile-key-wide mobile-key-special" data-mobile-modifier="ctrl">Ctrl</div>
                        <div class="mobile-key mobile-key-wide mobile-key-special" data-mobile-modifier="shift">Shift</div>
                        <div class="mobile-key mobile-key-wide mobile-key-special" data-mobile-modifier="alt">Alt</div>
                        <div class="mobile-key mobile-key-wide mobile-key-special" data-mobile-modifier="gui">Win</div>
                    </div>
                </div>
            </div>

            <div class="log" id="keyboardLog">
                <div class="log-entry">Keyboard ready. Click keys to send to target.</div>
            </div>
        </div>

        <!-- DuckyScript Panel -->
        <div class="card">
            <h3>DuckyScript</h3>

            <div class="tabs">
                <div class="tab active" data-tab="run">Run Script</div>
                <div class="tab" data-tab="edit">Editor</div>
            </div>

            <div class="tab-content active" id="tab-run">
                <div class="script-controls">
                    <select id="scriptSelect">
                        <option value="">-- Select Script --</option>
                        <?php foreach ($scripts as $script): ?>
                            <option value="<?= h($script['name']) ?>"><?= h($script['name']) ?></option>
                        <?php endforeach; ?>
                    </select>
                    <button onclick="runSelectedScript()" class="btn-success">Run Script</button>
                    <button onclick="loadScriptForEdit()">Edit</button>
                    <button onclick="deleteSelectedScript()" class="btn-danger btn-sm">Delete</button>
                    <button onclick="refreshScriptList()" class="btn-secondary btn-sm">Refresh</button>
                </div>

                <div class="form-group">
                    <label>Quick DuckyScript (run directly):</label>
                    <textarea id="quickDucky" placeholder="GUI r&#10;DELAY 500&#10;STRING notepad&#10;ENTER"></textarea>
                </div>
                <button onclick="runQuickDucky()" class="btn-success">Execute DuckyScript</button>
            </div>

            <div class="tab-content" id="tab-edit">
                <div class="form-group">
                    <label>Filename:</label>
                    <input type="text" id="scriptFilename" placeholder="MyScript.txt">
                </div>
                <div class="form-group">
                    <label>Script Content:</label>
                    <textarea id="scriptContent" style="min-height: 200px;" placeholder="REM My DuckyScript&#10;GUI r&#10;DELAY 500&#10;STRING notepad&#10;ENTER&#10;DELAY 1000&#10;STRING Hello World!"></textarea>
                </div>
                <div style="display: flex; gap: 8px;">
                    <button onclick="saveScript()" class="btn-success">Save Script</button>
                    <button onclick="newScript()" class="btn-secondary">New</button>
                </div>
            </div>

            <div class="log" id="duckyLog" style="margin-top: 12px;">
                <div class="log-entry">DuckyScript ready.</div>
            </div>
        </div>
    </div>

    <div class="grid">
        <!-- Network Information -->
        <div class="card">
            <h3>Network Information</h3>
            <div id="networkInfo">Loading network information...</div>
            <button onclick="refreshNetwork()" class="btn-secondary btn-sm" style="margin-top: 10px;">Refresh Network</button>
        </div>

        <!-- WiFi Management -->
        <div class="card">
            <h3>WiFi Management</h3>
            <div id="wifiStatus" style="margin-bottom: 12px; padding: 8px; background: #f5f5f5; border-radius: 4px;">
                <strong>Current:</strong> <span id="currentWifi">Checking...</span>
            </div>

            <div style="display: flex; gap: 8px; margin-bottom: 12px;">
                <button onclick="scanWifi()" id="scanBtn">Scan Networks</button>
                <button onclick="disconnectWifi()" class="btn-secondary">Disconnect</button>
            </div>

            <div id="wifiNetworks" style="max-height: 200px; overflow-y: auto; border: 1px solid #ddd; border-radius: 4px; display: none;">
                <!-- Networks will be populated here -->
            </div>

            <div id="wifiConnectForm" style="margin-top: 12px; padding: 12px; background: #f9f9f9; border-radius: 4px; display: none;">
                <div style="margin-bottom: 8px;">
                    <strong>Connect to: </strong><span id="selectedSSID"></span>
                </div>
                <div class="form-group" style="margin-bottom: 8px;">
                    <label>Password:</label>
                    <input type="password" id="wifiPassword" placeholder="Enter WiFi password" style="width: 100%;">
                </div>
                <div style="display: flex; gap: 8px;">
                    <button onclick="connectToSelectedWifi()">Connect</button>
                    <button onclick="cancelWifiConnect()" class="btn-secondary">Cancel</button>
                </div>
            </div>

            <div id="wifiLog" class="log" style="margin-top: 12px;">
                <div class="log-entry">WiFi manager ready.</div>
            </div>
        </div>

        <!-- File Upload -->
        <div class="card">
            <h3>File Upload</h3>

            <div class="form-group">
                <label>Upload Destination:</label>
                <div class="radio-group">
                    <label class="radio-label">
                        <input type="radio" name="uploadDest" value="usb" checked> USB Mass Storage
                    </label>
                    <label class="radio-label">
                        <input type="radio" name="uploadDest" value="webserver"> Webserver Directory
                    </label>
                </div>
            </div>

            <div class="form-group">
                <label>Select File:</label>
                <div style="display: flex; gap: 8px;">
                    <input type="file" id="uploadFile">
                    <button onclick="uploadFile()">Upload</button>
                </div>
            </div>

            <div class="tabs" style="margin-top: 16px;">
                <div class="tab active" data-tab="usb-files">USB Storage</div>
                <div class="tab" data-tab="web-files">Webserver</div>
            </div>

            <div class="tab-content active" id="tab-usb-files">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
                    <strong>Files on USB Storage:</strong>
                    <button onclick="refreshUSBFiles()" class="btn-secondary btn-sm">Refresh</button>
                </div>
                <div class="file-list" id="usbFileList">
                    <div class="file-item">Loading...</div>
                </div>
            </div>

            <div class="tab-content" id="tab-web-files">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
                    <strong>Files on Webserver:</strong>
                    <button onclick="refreshWebserverFiles()" class="btn-secondary btn-sm">Refresh</button>
                </div>
                <div class="file-list" id="webFileList">
                    <div class="file-item">Loading...</div>
                </div>
            </div>

            <div id="usbLog" class="log" style="margin-top: 12px;">
                <div class="log-entry">USB Storage: <?= $usbImageExists ? 'Image found at ' . USB_IMAGE : 'Image not found' ?></div>
            </div>
        </div>
    </div>
</div>

<script>
// API helper
async function api(action, data = {}) {
    const formData = new FormData();
    formData.append('action', action);
    for (const [key, value] of Object.entries(data)) {
        if (value instanceof File) {
            formData.append(key, value);
        } else {
            formData.append(key, value);
        }
    }

    try {
        const response = await fetch(window.location.href, {
            method: 'POST',
            body: formData
        });
        return await response.json();
    } catch (error) {
        return { success: false, message: error.message };
    }
}

// Logging helpers
function log(elementId, message, type = '') {
    const logEl = document.getElementById(elementId);
    const entry = document.createElement('div');
    entry.className = 'log-entry' + (type ? ' log-' + type : '');
    entry.textContent = '[' + new Date().toLocaleTimeString() + '] ' + message;
    logEl.appendChild(entry);
    logEl.scrollTop = logEl.scrollHeight;
}

// Get current modifiers
function getModifiers() {
    let mod = 0;
    if (document.getElementById('mod-ctrl').checked) mod |= 0x01;
    if (document.getElementById('mod-shift').checked) mod |= 0x02;
    if (document.getElementById('mod-alt').checked) mod |= 0x04;
    if (document.getElementById('mod-gui').checked) mod |= 0x08;
    return mod;
}

// Send a key
async function sendKey(key) {
    const modifier = getModifiers();
    const result = await api('send_key', { key, modifier });
    log('keyboardLog', result.success ? `Sent: ${key}` : `Error: ${result.message}`, result.success ? 'success' : 'error');
}

// Send text
async function sendText() {
    const text = document.getElementById('textInput').value;
    if (!text) return;
    const result = await api('type_string', { text });
    log('keyboardLog', result.success ? `Typed: ${text}` : `Error: ${result.message}`, result.success ? 'success' : 'error');
    document.getElementById('textInput').value = '';
}

// Keyboard click handler
document.querySelectorAll('.key[data-key]').forEach(key => {
    key.addEventListener('click', () => {
        sendKey(key.dataset.key);
    });
});

// Modifier toggle keys
document.querySelectorAll('.key[data-modifier]').forEach(key => {
    key.addEventListener('click', () => {
        const mod = key.dataset.modifier;
        const checkbox = document.getElementById('mod-' + mod);
        checkbox.checked = !checkbox.checked;
        key.classList.toggle('active', checkbox.checked);
    });
});

// Text input enter key
document.getElementById('textInput').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') sendText();
});

// Tab switching
document.querySelectorAll('.tab').forEach(tab => {
    tab.addEventListener('click', () => {
        const tabName = tab.dataset.tab;
        document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
        tab.classList.add('active');
        document.getElementById('tab-' + tabName).classList.add('active');
    });
});

// Mobile keyboard layer switching
document.querySelectorAll('.mobile-layer-tab').forEach(tab => {
    tab.addEventListener('click', () => {
        const layerName = tab.dataset.layer;
        document.querySelectorAll('.mobile-layer-tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.mobile-layer').forEach(l => l.classList.remove('active'));
        tab.classList.add('active');
        document.getElementById('layer-' + layerName).classList.add('active');
    });
});

// Mobile keyboard modifier state
let mobileModifiers = { ctrl: false, shift: false, alt: false, gui: false };

// Mobile modifier key toggle
document.querySelectorAll('.mobile-key[data-mobile-modifier]').forEach(key => {
    key.addEventListener('click', (e) => {
        e.stopPropagation();
        const mod = key.dataset.mobileModifier;
        mobileModifiers[mod] = !mobileModifiers[mod];

        // Toggle active class on all modifier keys of this type
        document.querySelectorAll(`.mobile-key[data-mobile-modifier="${mod}"]`).forEach(k => {
            k.classList.toggle('active', mobileModifiers[mod]);
        });

        // Also sync with desktop checkboxes
        const checkbox = document.getElementById('mod-' + mod);
        if (checkbox) checkbox.checked = mobileModifiers[mod];
    });
});

// Mobile key press handler
document.querySelectorAll('.mobile-key[data-key]').forEach(key => {
    key.addEventListener('click', () => {
        const keyValue = key.dataset.key;
        if (keyValue) {
            sendMobileKey(keyValue);
        }
    });
});

// Get mobile modifiers as number
function getMobileModifiers() {
    let mod = 0;
    if (mobileModifiers.ctrl) mod |= 0x01;
    if (mobileModifiers.shift) mod |= 0x02;
    if (mobileModifiers.alt) mod |= 0x04;
    if (mobileModifiers.gui) mod |= 0x08;
    return mod;
}

// Send key from mobile keyboard
async function sendMobileKey(key) {
    const modifier = getMobileModifiers();
    const result = await api('send_key', { key, modifier });
    log('keyboardLog', result.success ? `Sent: ${key}` : `Error: ${result.message}`, result.success ? 'success' : 'error');

    // Clear modifiers after sending (like phone keyboard behavior)
    if (modifier !== 0) {
        clearMobileModifiers();
    }
}

// Send combo from mobile quick buttons
async function sendMobileCombo(mod, key) {
    const keys = mod + ' ' + key;
    const result = await api('send_combo', { keys });
    log('keyboardLog', result.success ? `Combo: ${mod}+${key}` : `Error: ${result.message}`, result.success ? 'success' : 'error');
}

// Clear all mobile modifiers
function clearMobileModifiers() {
    mobileModifiers = { ctrl: false, shift: false, alt: false, gui: false };
    document.querySelectorAll('.mobile-key[data-mobile-modifier]').forEach(k => {
        k.classList.remove('active');
    });
    // Also clear desktop checkboxes
    ['ctrl', 'shift', 'alt', 'gui'].forEach(mod => {
        const checkbox = document.getElementById('mod-' + mod);
        if (checkbox) checkbox.checked = false;
    });
}

// Placeholder for symbol switching (can be expanded later)
function switchMobileSymbols() {
    log('keyboardLog', 'Symbol layer: use 123 tab for numbers and symbols');
}

// DuckyScript functions
async function runSelectedScript() {
    const select = document.getElementById('scriptSelect');
    const script = select.value;
    if (!script) {
        log('duckyLog', 'No script selected', 'error');
        return;
    }
    log('duckyLog', 'Running: ' + script);
    const result = await api('run_script', { script });
    if (result.success) {
        log('duckyLog', 'Script completed', 'success');
        if (result.results) {
            result.results.forEach(r => log('duckyLog', '  ' + r));
        }
    } else {
        log('duckyLog', 'Error: ' + result.message, 'error');
    }
}

async function runQuickDucky() {
    const script = document.getElementById('quickDucky').value;
    if (!script.trim()) {
        log('duckyLog', 'No script to run', 'error');
        return;
    }
    log('duckyLog', 'Executing DuckyScript...');
    const result = await api('run_ducky', { script });
    if (result.success) {
        log('duckyLog', 'Execution completed', 'success');
        if (result.results) {
            result.results.forEach(r => log('duckyLog', '  ' + r));
        }
    } else {
        log('duckyLog', 'Error: ' + result.message, 'error');
    }
}

async function loadScriptForEdit() {
    const select = document.getElementById('scriptSelect');
    const script = select.value;
    if (!script) {
        log('duckyLog', 'No script selected', 'error');
        return;
    }
    const result = await api('get_script', { script });
    if (result.success) {
        document.getElementById('scriptFilename').value = script;
        document.getElementById('scriptContent').value = result.content;
        // Switch to edit tab
        document.querySelector('.tab[data-tab="edit"]').click();
        log('duckyLog', 'Loaded: ' + script, 'success');
    } else {
        log('duckyLog', 'Error loading script: ' + result.message, 'error');
    }
}

async function saveScript() {
    const name = document.getElementById('scriptFilename').value.trim();
    const content = document.getElementById('scriptContent').value;
    if (!name) {
        log('duckyLog', 'Please enter a filename', 'error');
        return;
    }
    const result = await api('save_script', { name, content });
    if (result.success) {
        log('duckyLog', 'Saved: ' + result.filename, 'success');
        refreshScriptList();
    } else {
        log('duckyLog', 'Error: ' + result.message, 'error');
    }
}

function newScript() {
    document.getElementById('scriptFilename').value = '';
    document.getElementById('scriptContent').value = '';
    log('duckyLog', 'New script started');
}

async function deleteSelectedScript() {
    const select = document.getElementById('scriptSelect');
    const script = select.value;
    if (!script) {
        log('duckyLog', 'No script selected', 'error');
        return;
    }
    if (!confirm('Delete script: ' + script + '?')) return;
    const result = await api('delete_script', { script });
    if (result.success) {
        log('duckyLog', 'Deleted: ' + script, 'success');
        refreshScriptList();
    } else {
        log('duckyLog', 'Error: ' + result.message, 'error');
    }
}

async function refreshScriptList() {
    const result = await api('list_scripts');
    const select = document.getElementById('scriptSelect');
    select.innerHTML = '<option value="">-- Select Script --</option>';
    if (result.success && result.scripts) {
        result.scripts.forEach(s => {
            const opt = document.createElement('option');
            opt.value = s.name;
            opt.textContent = s.name;
            select.appendChild(opt);
        });
    }
    log('duckyLog', 'Script list refreshed');
}

// Network functions
async function refreshNetwork() {
    const container = document.getElementById('networkInfo');
    container.innerHTML = 'Loading...';

    const result = await api('get_network');
    if (!result.success) {
        container.innerHTML = '<span class="status status-error">Error loading network info</span>';
        return;
    }

    let html = '';
    for (const [iface, info] of Object.entries(result.interfaces)) {
        const isUSB = iface === 'usb0';
        const stateClass = info.state === 'up' ? 'status-ok' : 'status-error';

        html += `<div style="margin-bottom: 15px;">
            <strong>${iface}</strong> ${isUSB ? '(USB Network)' : '(System Network)'}
            <span class="status ${stateClass}">${info.state}</span>
            <table style="margin-top: 5px;">
                <tr><td>IP Address</td><td class="mono">${info.ip || 'Not assigned'}</td></tr>
                <tr><td>Netmask</td><td class="mono">${info.netmask || '-'}</td></tr>
                <tr><td>Broadcast</td><td class="mono">${info.broadcast || '-'}</td></tr>
                <tr><td>MAC Address</td><td class="mono">${info.mac || '-'}</td></tr>
                <tr><td>Gateway</td><td class="mono">${info.gateway || '-'}</td></tr>
                <tr><td>DNS</td><td class="mono">${info.dns.length ? info.dns.join(', ') : '-'}</td></tr>
            </table>
        </div>`;
    }

    container.innerHTML = html || '<span class="status status-warn">No network interfaces found</span>';
}

// WiFi Management functions
let selectedWifiSSID = '';

async function refreshWifiStatus() {
    const statusEl = document.getElementById('currentWifi');
    const result = await api('wifi_status');
    if (result.success && result.wifi) {
        if (result.wifi.connected) {
            statusEl.innerHTML = `<span class="status status-ok">${result.wifi.ssid}</span> (${result.wifi.ip || 'Getting IP...'})`;
        } else {
            statusEl.innerHTML = '<span class="status status-warn">Not connected</span>';
        }
    } else {
        statusEl.innerHTML = '<span class="status status-error">Unknown</span>';
    }
}

async function scanWifi() {
    const btn = document.getElementById('scanBtn');
    const container = document.getElementById('wifiNetworks');

    btn.disabled = true;
    btn.textContent = 'Scanning...';
    container.style.display = 'block';
    container.innerHTML = '<div style="padding: 12px; text-align: center;">Scanning for networks...</div>';
    log('wifiLog', 'Scanning for WiFi networks...');

    const result = await api('wifi_scan');

    btn.disabled = false;
    btn.textContent = 'Scan Networks';

    if (!result.success) {
        container.innerHTML = '<div style="padding: 12px; color: #d32f2f;">Scan failed. Try again.</div>';
        log('wifiLog', 'Scan failed: ' + (result.message || 'Unknown error'), 'error');
        return;
    }

    if (!result.networks || result.networks.length === 0) {
        container.innerHTML = '<div style="padding: 12px;">No networks found</div>';
        log('wifiLog', 'No networks found');
        return;
    }

    container.innerHTML = result.networks.map(net => {
        const signalBars = getSignalBars(net.signal);
        const security = net.security !== 'Open' ? '&#128274;' : '';
        return `
            <div class="wifi-network" onclick="selectWifi('${escapeHtml(net.ssid)}', '${net.security}')"
                 style="padding: 10px; border-bottom: 1px solid #eee; cursor: pointer; display: flex; justify-content: space-between; align-items: center;">
                <div>
                    <strong>${escapeHtml(net.ssid)}</strong>
                    <span style="font-size: 0.85em; color: #666;">${security} ${net.security}</span>
                </div>
                <div style="font-family: monospace;">${signalBars} ${net.signal}%</div>
            </div>
        `;
    }).join('');

    log('wifiLog', `Found ${result.networks.length} networks`);
}

function getSignalBars(signal) {
    if (signal >= 75) return '&#9608;&#9608;&#9608;&#9608;';
    if (signal >= 50) return '&#9608;&#9608;&#9608;&#9617;';
    if (signal >= 25) return '&#9608;&#9608;&#9617;&#9617;';
    return '&#9608;&#9617;&#9617;&#9617;';
}

function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}

function selectWifi(ssid, security) {
    selectedWifiSSID = ssid;
    document.getElementById('selectedSSID').textContent = ssid;
    document.getElementById('wifiConnectForm').style.display = 'block';
    document.getElementById('wifiPassword').value = '';

    // Focus password field if network requires password
    if (security !== 'Open') {
        document.getElementById('wifiPassword').focus();
    }
}

function cancelWifiConnect() {
    document.getElementById('wifiConnectForm').style.display = 'none';
    selectedWifiSSID = '';
}

async function connectToSelectedWifi() {
    if (!selectedWifiSSID) return;

    const password = document.getElementById('wifiPassword').value;
    log('wifiLog', `Connecting to ${selectedWifiSSID}...`);

    // Disable form while connecting
    const buttons = document.querySelectorAll('#wifiConnectForm button');
    buttons.forEach(b => b.disabled = true);

    const result = await api('wifi_connect', { ssid: selectedWifiSSID, password: password });

    buttons.forEach(b => b.disabled = false);

    if (result.success) {
        log('wifiLog', result.message, 'success');
        cancelWifiConnect();
        refreshWifiStatus();
        refreshNetwork();
    } else {
        log('wifiLog', result.message || 'Connection failed', 'error');
    }
}

async function disconnectWifi() {
    log('wifiLog', 'Disconnecting...');
    const result = await api('wifi_disconnect');
    log('wifiLog', result.message, result.success ? 'success' : 'error');
    refreshWifiStatus();
    refreshNetwork();
}

// USB Storage functions
async function refreshUSBFiles() {
    const container = document.getElementById('usbFileList');
    container.innerHTML = '<div class="file-item">Loading...</div>';

    const result = await api('list_usb_files');
    if (!result.success) {
        container.innerHTML = `<div class="file-item"><span class="status status-error">${result.message}</span></div>`;
        log('usbLog', 'Error: ' + result.message, 'error');
        return;
    }

    if (!result.files || result.files.length === 0) {
        container.innerHTML = '<div class="file-item">No files found</div>';
        return;
    }

    container.innerHTML = result.files.map(f => `
        <div class="file-item">
            <span class="mono">${f.is_dir ? '&#128193; ' : '&#128196; '}${f.name}</span>
            <div class="file-info">
                <span>${f.is_dir ? 'Directory' : formatSize(f.size)}</span>
                ${!f.is_dir ? `<button class="btn-danger btn-sm" onclick="deleteUSBFile('${f.name}')">Delete</button>` : ''}
            </div>
        </div>
    `).join('');
}

function formatSize(bytes) {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}

async function uploadFile() {
    const fileInput = document.getElementById('uploadFile');
    const file = fileInput.files[0];
    if (!file) {
        log('usbLog', 'No file selected', 'error');
        return;
    }

    const destination = document.querySelector('input[name="uploadDest"]:checked').value;
    log('usbLog', 'Uploading to ' + destination + ': ' + file.name);
    const result = await api('upload_file', { file, destination });
    if (result.success) {
        log('usbLog', result.message, 'success');
        if (destination === 'usb') {
            refreshUSBFiles();
        } else {
            refreshWebserverFiles();
            // Switch to webserver tab
            document.querySelector('.tab[data-tab="web-files"]').click();
        }
        fileInput.value = '';
    } else {
        log('usbLog', 'Error: ' + result.message, 'error');
    }
}

async function refreshWebserverFiles() {
    const container = document.getElementById('webFileList');
    container.innerHTML = '<div class="file-item">Loading...</div>';

    const result = await api('list_webserver_files');
    if (!result.success) {
        container.innerHTML = `<div class="file-item"><span class="status status-error">${result.message || 'Error'}</span></div>`;
        return;
    }

    if (!result.files || result.files.length === 0) {
        container.innerHTML = '<div class="file-item">No files found</div>';
        return;
    }

    container.innerHTML = result.files.map(f => `
        <div class="file-item">
            <span class="mono">&#128196; ${f.name}</span>
            <div class="file-info">
                <span>${formatSize(f.size)}</span>
                <button class="btn-danger btn-sm" onclick="deleteWebserverFile('${f.name}')">Delete</button>
            </div>
        </div>
    `).join('');
}

async function deleteWebserverFile(filename) {
    if (!confirm('Delete file: ' + filename + '?')) return;
    const result = await api('delete_webserver_file', { filename });
    if (result.success) {
        log('usbLog', 'Deleted: ' + filename, 'success');
        refreshWebserverFiles();
    } else {
        log('usbLog', 'Error: ' + result.message, 'error');
    }
}

async function deleteUSBFile(filename) {
    if (!confirm('Delete file: ' + filename + '?')) return;
    const result = await api('delete_usb_file', { filename });
    if (result.success) {
        log('usbLog', 'Deleted: ' + filename, 'success');
        refreshUSBFiles();
    } else {
        log('usbLog', 'Error: ' + result.message, 'error');
    }
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
    refreshNetwork();
    refreshWifiStatus();
    refreshUSBFiles();
    refreshWebserverFiles();
});
</script>
</body>
</html>
