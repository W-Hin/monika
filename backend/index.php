<?php
header('Content-Type: application/json');
echo json_encode([
    'status' => 'ok',
    'service' => 'MONIKA backend',
    'php_version' => PHP_VERSION,
]);
