<?php
require __DIR__ . '/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail(405, 'Method not allowed');

$body = read_json_body();
$employeeId = trim($body['employee_id'] ?? '');
$fullName = trim($body['full_name'] ?? '');
$email = trim($body['email'] ?? '');
$department = trim($body['department'] ?? '');
$password = (string) ($body['password'] ?? '');

if ($employeeId === '' || $fullName === '' || $email === '' || $department === '' || $password === '') {
    fail(400, 'All fields are required.');
}

$stmt = $mysqli->prepare('SELECT id FROM user WHERE employee_id = ? LIMIT 1');
$stmt->bind_param('s', $employeeId);
$stmt->execute();
if ($stmt->get_result()->fetch_assoc()) {
    $stmt->close();
    fail(409, 'An account with this employee ID already exists.');
}
$stmt->close();

$hash = password_hash($password, PASSWORD_DEFAULT);

$stmt = $mysqli->prepare(
    'INSERT INTO user (employee_id, full_name, email, department, password) VALUES (?, ?, ?, ?, ?)'
);
$stmt->bind_param('sssss', $employeeId, $fullName, $email, $department, $hash);

if (!$stmt->execute()) {
    $stmt->close();
    fail(500, 'Failed to create account: ' . $mysqli->error);
}
$stmt->close();

http_response_code(201);
echo json_encode(['message' => 'Account created.']);
