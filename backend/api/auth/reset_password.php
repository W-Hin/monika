<?php

require_once __DIR__ . '/../../src/JsonResponse.php';
require_once __DIR__ . '/../../src/DatabaseConnection.php';

header('Access-Control-Allow-Origin: *');
require_method('POST');

$body = json_body();
$token = $body['token'] ?? '';
$newPassword = $body['password'] ?? '';

if ($token === '' || $newPassword === '') {
    json_response(['error' => 'Token and new password are required'], 422);
}
if (strlen($newPassword) < 8) {
    json_response(['error' => 'Password must be at least 8 characters'], 422);
}

$tokenHash = hash('sha256', $token);

$stmt = db()->prepare(
    'SELECT id, user_id FROM password_reset_tokens WHERE token_hash = ? AND expires_at > NOW() AND used_at IS NULL'
);
$stmt->execute([$tokenHash]);
$row = $stmt->fetch();

if (!$row) {
    json_response(['error' => 'Invalid or expired reset token'], 400);
}

$pdo = db();
$pdo->beginTransaction();
$pdo->prepare('UPDATE users SET password_hash = ? WHERE id = ?')
    ->execute([password_hash($newPassword, PASSWORD_DEFAULT), $row['user_id']]);
$pdo->prepare('UPDATE password_reset_tokens SET used_at = NOW() WHERE id = ?')
    ->execute([$row['id']]);
$pdo->commit();

json_response(['message' => 'Password has been reset. You can now log in.']);
