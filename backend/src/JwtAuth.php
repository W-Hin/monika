<?php

require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/JsonResponse.php';

use Firebase\JWT\JWT;
use Firebase\JWT\Key;

function jwt_secret(): string
{
    static $secret = null;
    if ($secret === null) {
        $config = require __DIR__ . '/../config.php';
        $secret = $config['jwt_secret'];
    }
    return $secret;
}

function issue_jwt(int $userId, string $role): string
{
    $now = time();
    return JWT::encode([
        'sub' => $userId,
        'role' => $role,
        'iat' => $now,
        'exp' => $now + 8 * 60 * 60,
    ], jwt_secret(), 'HS256');
}

function verify_jwt(string $token): ?array
{
    try {
        return (array) JWT::decode($token, new Key(jwt_secret(), 'HS256'));
    } catch (\Throwable $e) {
        return null;
    }
}

/** Reads the Authorization: Bearer header, halts the request with 401 if missing/invalid. */
function require_auth(): array
{
    $headers = getallheaders();
    $auth = $headers['Authorization'] ?? $headers['authorization'] ?? '';
    if (!preg_match('/^Bearer\s+(.+)$/i', $auth, $m)) {
        json_response(['error' => 'Missing bearer token'], 401);
    }
    $claims = verify_jwt($m[1]);
    if ($claims === null) {
        json_response(['error' => 'Invalid or expired token'], 401);
    }
    return $claims;
}
