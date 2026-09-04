<?php
require __DIR__ . '/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail(405, 'Method not allowed');

$body = read_json_body();
$employeeId = trim($body['employee_id'] ?? '');
$password = (string) ($body['password'] ?? '');

if ($employeeId === '' || $password === '') {
    fail(400, 'Employee ID and password are required.');
}

$stmt = $mysqli->prepare(
    'SELECT id, employee_id, full_name, email, department, password FROM user WHERE employee_id = ? LIMIT 1'
);
$stmt->bind_param('s', $employeeId);
$stmt->execute();
$result = $stmt->get_result();
$user = $result->fetch_assoc();
$stmt->close();

if (!$user || !password_verify($password, $user['password'])) {
    fail(401, 'Invalid employee ID or password.');
}

unset($user['password']);
echo json_encode(['user' => $user]);
