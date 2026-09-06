<?php
require __DIR__ . '/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail(405, 'Method not allowed');

$body = read_json_body();

// Accepts any of: `identifier` (email OR employee ID, preferred), `email`,
// or the legacy `employee_id`.
$identifier = trim(
    $body['identifier']
    ?? $body['email']
    ?? $body['employee_id']
    ?? ''
);
$password = (string) ($body['password'] ?? '');

if ($identifier === '' || $password === '') {
    fail(400, 'Email (or employee ID) and password are required.');
}

$normalisedEmail = strtolower($identifier);
$stmt = $mysqli->prepare(
    'SELECT id, employee_id, full_name, email, department, password, email_verified ' .
    'FROM user WHERE LOWER(email) = ? OR employee_id = ? LIMIT 1'
);
$stmt->bind_param('ss', $normalisedEmail, $identifier);
$stmt->execute();
$user = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$user || !password_verify($password, $user['password'])) {
    fail(401, 'Invalid email/employee ID or password.');
}

if ((int) $user['email_verified'] !== 1) {
    // 403 + a machine-readable code so the app can route to the
    // verification screen instead of just showing an error.
    fail(403, 'Please verify your email address before signing in.', [
        'code' => 'email_not_verified',
        'email' => $user['email'],
    ]);
}

unset($user['password']);
$user['email_verified'] = (int) $user['email_verified'];
echo json_encode(['user' => $user]);
