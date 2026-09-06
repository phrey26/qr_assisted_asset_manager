<?php
require __DIR__ . '/db.php';
require __DIR__ . '/includes/mailer.php';
require __DIR__ . '/includes/auth_codes.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail(405, 'Method not allowed');

$body = read_json_body();
$email = strtolower(trim($body['email'] ?? ''));

if ($email === '') {
    fail(400, 'Email is required.');
}
if (!valid_email($email)) {
    fail(400, 'Please enter a valid email address.');
}

$stmt = $mysqli->prepare('SELECT id FROM admin_user WHERE email = ? LIMIT 1');
$stmt->bind_param('s', $email);
$stmt->execute();
$user = $stmt->get_result()->fetch_assoc();
$stmt->close();

// Always answer the same way so this can't be used to probe for accounts.
$generic = ['message' => 'If that email has an account, a reset code has been sent.'];

if (!$user) {
    echo json_encode($generic);
    exit;
}

try {
    $code = issue_auth_code($mysqli, $email, AUTH_PURPOSE_RESET);
} catch (RuntimeException $e) {
    fail(429, $e->getMessage());
}

$delivery = send_mail($email, 'Your QREMS password reset code', reset_email_body($code));

echo json_encode(array_merge($generic, dev_code_payload($code, $delivery)));
