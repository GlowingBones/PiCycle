<html>
<head>
</head>
<body>
<br>
<?php header('Content-Type: text/plain; charset=utf-8');
echo "PiCycle web server OK\n";
echo "Client IP: " . ($_SERVER['REMOTE_ADDR'] ?? 'unknown') . "\n";
echo "Server IP: " . ($_SERVER['SERVER_ADDR'] ?? 'unknown') . "\n";
echo "Time: " . date('c') . "\n";?>
<BR>
<img style="width: 327px; height: 327px;" alt="PiCycle" src="https://raw.githubusercontent.com/GlowingBones/PiCycle/refs/heads/main/assets/picycle.png">
</body>
</html>
