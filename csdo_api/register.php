<?php
require __DIR__ . '/db.php';
require __DIR__ . '/includes/mailer.php';
require __DIR__ . '/includes/auth_codes.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail(405, 'Method not allowed');

$body = read_json_body();
$employeeId = trim($body['employee_id'] ?? '');
$fullName = trim($body['full_name'] ?? '');
$email = strtolower(trim($body['email'] ?? ''));
$department = trim($body['department'] ?? '');
$password = (string) ($body['password'] ?? '');

if ($employeeId === '' || $fullName === '' || $email === '' || $department === '' || $password === '') {
    fail(400, 'All fields are required.');
}
if (!valid_email($email)) {
    fail(400, 'Please enter a valid email address.');
}
if (!email_domain_allowed($email)) {
    fail(400, 'Please sign up with a Gmail, Yahoo, or Outlook email address.');
}
if (strlen($password) < 8) {
    fail(400, 'Password must be at least 8 characters.');
}

// Employee ID taken?
$stmt = $mysqli->prepare('SELECT id FROM user WHERE employee_id = ? LIMIT 1');
$stmt->bind_param('s', $employeeId);
$stmt->execute();
if ($stmt->get_result()->fetch_assoc()) {
    $stmt->close();
    fail(409, 'An account with this employee ID already exists.');
}
$stmt->close();

// Email taken?
$stmt = $mysqli->prepare('SELECT id FROM user WHERE email = ? LIMIT 1');
$stmt->bind_param('s', $email);
$stmt->execute();
if ($stmt->get_result()->fetch_assoc()) {
    $stmt->close();
    fail(409, 'An account with this email already exists.');
}
$stmt->close();

$hash = password_hash($password, PASSWORD_DEFAULT);

$stmt = $mysqli->prepare(
    'INSERT INTO user (employee_id, full_name, email, department, password, email_verified) ' .
    'VALUES (?, ?, ?, ?, ?, 0)'
);
$stmt->bind_param('sssss', $employeeId, $fullName, $email, $department, $hash);

if (!$stmt->execute()) {
    $stmt->close();
    fail(500, 'Failed to create account: ' . $mysqli->error);
}
$stmt->close();

// Issue + send the email verification code.
try {
    $code = issue_auth_code($mysqli, $email, AUTH_PURPOSE_VERIFY);
} catch (RuntimeException $e) {
    // Account exists but we couldn't mint a code; the user can hit "Resend".
    http_response_code(201);
    echo json_encode([
        'message' => 'Account created. Request a verification code to continue.',
        'email' => $email,
    ]);
    exit;
}

$delivery = send_mail($email, 'Your QREMS verification code', verify_email_body($code));

http_response_code(201);
echo json_encode(array_merge([
    'message' => 'Account created. Check your email for a verification code.',
    'email' => $email,
], dev_code_payload($code, $delivery)));
