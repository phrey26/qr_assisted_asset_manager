<?php
require __DIR__ . '/db.php';
require __DIR__ . '/includes/mailer.php';
require __DIR__ . '/includes/auth_codes.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail(405, 'Method not allowed');

$body = read_json_body();
$email = strtolower(trim($body['email'] ?? ''));
$purpose = trim($body['purpose'] ?? AUTH_PURPOSE_VERIFY);

if ($email === '') {
    fail(400, 'Email is required.');
}
if ($purpose !== AUTH_PURPOSE_VERIFY && $purpose !== AUTH_PURPOSE_RESET) {
    fail(400, 'Unknown code purpose.');
}

$stmt = $mysqli->prepare('SELECT id, email_verified FROM admin_user WHERE email = ? LIMIT 1');
$stmt->bind_param('s', $email);
$stmt->execute();
$user = $stmt->get_result()->fetch_assoc();
$stmt->close();

// Don't reveal whether the address is registered.
$genericOk = ['message' => 'If that email has an account, a new code is on its way.'];

if (!$user) {
    echo json_encode($genericOk);
    exit;
}
if ($purpose === AUTH_PURPOSE_VERIFY && (int) $user['email_verified'] === 1) {
    echo json_encode(['message' => 'That email is already verified. You can sign in.']);
    exit;
}

try {
    $code = issue_auth_code($mysqli, $email, $purpose);
} catch (RuntimeException $e) {
    fail(429, $e->getMessage());
}

$subject = $purpose === AUTH_PURPOSE_RESET
    ? 'Your QREMS password reset code'
    : 'Your QREMS verification code';
$text = $purpose === AUTH_PURPOSE_RESET ? reset_email_body($code) : verify_email_body($code);
$delivery = send_mail($email, $subject, $text);

echo json_encode(array_merge($genericOk, dev_code_payload($code, $delivery)));
