<?php
require __DIR__ . '/db.php';
require __DIR__ . '/includes/mailer.php';
require __DIR__ . '/includes/auth_codes.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail(405, 'Method not allowed');

$body = read_json_body();
$email = strtolower(trim($body['email'] ?? ''));
$code = trim($body['code'] ?? '');
$newPassword = (string) ($body['new_password'] ?? '');

if ($email === '' || $code === '' || $newPassword === '') {
    fail(400, 'Email, reset code, and new password are required.');
}
if (strlen($newPassword) < 8) {
    fail(400, 'Password must be at least 8 characters.');
}

$stmt = $mysqli->prepare('SELECT id FROM user WHERE email = ? LIMIT 1');
$stmt->bind_param('s', $email);
$stmt->execute();
$user = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$user) {
    fail(400, 'That code is incorrect or has expired. Request a new one and try again.');
}

if (!verify_auth_code($mysqli, $email, AUTH_PURPOSE_RESET, $code)) {
    fail(400, 'That code is incorrect or has expired. Request a new one and try again.');
}

$hash = password_hash($newPassword, PASSWORD_DEFAULT);

// Resetting via a code emailed to the address also proves ownership, so
// clear any pending verification block at the same time.
$stmt = $mysqli->prepare('UPDATE user SET password = ?, email_verified = 1 WHERE id = ?');
$stmt->bind_param('si', $hash, $user['id']);
if (!$stmt->execute()) {
    $stmt->close();
    fail(500, 'Failed to update the password: ' . $mysqli->error);
}
$stmt->close();

echo json_encode(['message' => 'Your password has been reset. You can now sign in.']);
