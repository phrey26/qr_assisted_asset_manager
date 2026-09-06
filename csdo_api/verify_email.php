<?php
require __DIR__ . '/db.php';
require __DIR__ . '/includes/mailer.php';
require __DIR__ . '/includes/auth_codes.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail(405, 'Method not allowed');

$body = read_json_body();
$email = strtolower(trim($body['email'] ?? ''));
$code = trim($body['code'] ?? '');

if ($email === '' || $code === '') {
    fail(400, 'Email and verification code are required.');
}

$stmt = $mysqli->prepare(
    'SELECT id, employee_id, full_name, email, department, email_verified ' .
    'FROM user WHERE email = ? LIMIT 1'
);
$stmt->bind_param('s', $email);
$stmt->execute();
$user = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$user) {
    fail(404, 'No account was found for that email.');
}

if ((int) $user['email_verified'] === 1) {
    unset($user['email_verified']);
    $user['email_verified'] = 1;
    echo json_encode(['user' => $user, 'message' => 'Email already verified.']);
    exit;
}

if (!verify_auth_code($mysqli, $email, AUTH_PURPOSE_VERIFY, $code)) {
    fail(400, 'That code is incorrect or has expired. Request a new one and try again.');
}

$stmt = $mysqli->prepare('UPDATE user SET email_verified = 1 WHERE id = ?');
$stmt->bind_param('i', $user['id']);
if (!$stmt->execute()) {
    $stmt->close();
    fail(500, 'Failed to activate the account: ' . $mysqli->error);
}
$stmt->close();

$user['email_verified'] = 1;
echo json_encode(['user' => $user, 'message' => 'Email verified.']);
