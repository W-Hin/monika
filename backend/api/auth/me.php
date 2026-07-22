<?php

require_once __DIR__ . '/../../src/JsonResponse.php';
require_once __DIR__ . '/../../src/DatabaseConnection.php';
require_once __DIR__ . '/../../src/JwtAuth.php';

header('Access-Control-Allow-Origin: *');
require_method('GET');

$claims = require_auth();

$stmt = db()->prepare(
    'SELECT id, employee_code, name, email, user_role, job_title, department_id, avatar_initials, risk_level, risk_score
     FROM users WHERE id = ?'
);
$stmt->execute([$claims['sub']]);
$user = $stmt->fetch();

if (!$user) {
    json_response(['error' => 'User not found'], 404);
}

json_response(['user' => $user]);
