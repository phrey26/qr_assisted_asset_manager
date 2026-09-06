<?php
require __DIR__ . '/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST' && $_SERVER['REQUEST_METHOD'] !== 'PUT') {
    fail(405, 'Method not allowed');
}

$body = read_json_body();

// The account to update is identified by its (immutable) employee ID — this
// app has no auth token, same as every other endpoint here.
$employeeId = trim($body['employee_id'] ?? '');
$fullName = trim($body['full_name'] ?? '');
$department = trim($body['department'] ?? '');
$email = strtolower(trim($body['email'] ?? ''));

if ($employeeId === '' || $fullName === '' || $department === '' || $email === '') {
    fail(400, 'Name, department, and email are all required.');
}
if (!valid_email($email)) {
    fail(400, 'Please enter a valid email address.');
}
if (!email_domain_allowed($email)) {
    fail(400, 'Please use a Gmail, Yahoo, or Outlook email address.');
}

$stmt = $mysqli->prepare('SELECT id FROM user WHERE employee_id = ? LIMIT 1');
$stmt->bind_param('s', $employeeId);
$stmt->execute();
$row = $stmt->get_result()->fetch_assoc();
$stmt->close();
if (!$row) {
    fail(404, 'Account not found.');
}
$userId = (int) $row['id'];

// New email must not belong to a different account.
$stmt = $mysqli->prepare('SELECT id FROM user WHERE email = ? AND id <> ? LIMIT 1');
$stmt->bind_param('si', $email, $userId);
$stmt->execute();
if ($stmt->get_result()->fetch_assoc()) {
    $stmt->close();
    fail(409, 'That email is already used by another account.');
}
$stmt->close();

$stmt = $mysqli->prepare(
    'UPDATE user SET full_name = ?, department = ?, email = ? WHERE id = ?'
);
$stmt->bind_param('sssi', $fullName, $department, $email, $userId);
if (!$stmt->execute()) {
    $stmt->close();
    fail(500, 'Failed to update the profile: ' . $mysqli->error);
}
$stmt->close();

// Return the fresh row in the same shape as login.php.
$stmt = $mysqli->prepare(
    'SELECT id, employee_id, full_name, email, department, email_verified ' .
    'FROM user WHERE id = ? LIMIT 1'
);
$stmt->bind_param('i', $userId);
$stmt->execute();
$user = $stmt->get_result()->fetch_assoc();
$stmt->close();
$user['id'] = (int) $user['id'];
$user['email_verified'] = (int) $user['email_verified'];

echo json_encode(['user' => $user, 'message' => 'Profile updated.']);
