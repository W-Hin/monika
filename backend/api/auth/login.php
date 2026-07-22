<?php

require_once __DIR__ . '/../../src/JsonResponse.php';
require_once __DIR__ . '/../../src/DatabaseConnection.php';
require_once __DIR__ . '/../../src/JwtAuth.php';

header('Access-Control-Allow-Origin: *');
require_method('POST');

$body = json_body();
$email = trim($body['email'] ?? '');
$password = $body['password'] ?? '';

if ($email === '' || $password === '') {
    json_response(['error' => 'Email and password are required'], 422);
}

$stmt = db()->prepare(
    'SELECT id, employee_code, name, email, password_hash, user_role, job_title, department_id, avatar_initials, risk_level
     FROM users WHERE email = ? AND is_active = 1'
);
$stmt->execute([$email]);
$user = $stmt->fetch();

if (!$user || !password_verify($password, $user['password_hash'])) {
    json_response(['error' => 'Invalid email or password'], 401);
}

$token = issue_jwt((int) $user['id'], $user['user_role']);
unset($user['password_hash']);

json_response([
    'token' => $token,
    'user' => $user,
]);
