<?php

require_once __DIR__ . '/../../src/JsonResponse.php';
require_once __DIR__ . '/../../src/DatabaseConnection.php';

header('Access-Control-Allow-Origin: *');
require_method('POST');

$body = json_body();
$email = trim($body['email'] ?? '');

if ($email === '') {
    json_response(['error' => 'Email is required'], 422);
}

$stmt = db()->prepare('SELECT id FROM users WHERE email = ? AND is_active = 1');
$stmt->execute([$email]);
$user = $stmt->fetch();

// Always return the same generic response whether or not the account
// exists — matches lib/view/auth/forgot_password.dart's "if an account
// exists..." messaging and avoids leaking which emails are registered.
if ($user) {
    $token = bin2hex(random_bytes(32));
    $tokenHash = hash('sha256', $token);
    $expiresAt = date('Y-m-d H:i:s', time() + 30 * 60);

    db()->prepare('INSERT INTO password_reset_tokens (user_id, token_hash, expires_at) VALUES (?, ?, ?)')
        ->execute([$user['id'], $tokenHash, $expiresAt]);

    // No SMTP wired up yet — log the raw token locally instead of emailing
    // it, so the reset flow can be exercised end-to-end during dev/demo.
    // Swap this block for a real mailer call before deploying anywhere
    // beyond localhost; storage/ is gitignored, same reasoning as config.php.
    $logDir = __DIR__ . '/../../storage';
    if (!is_dir($logDir)) {
        mkdir($logDir, 0777, true);
    }
    file_put_contents(
        $logDir . '/reset_tokens.log',
        sprintf("[%s] %s -> %s (expires %s)\n", date('c'), $email, $token, $expiresAt),
        FILE_APPEND
    );
}

json_response(['message' => 'If an account exists for that email, a password reset link has been sent.']);
