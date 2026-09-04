<?php
/**
 * Shared DB connection + CORS/JSON setup, included by every endpoint here.
 *
 * Edit DB_HOST / DB_NAME / DB_USER / DB_PASS below to match your MySQL /
 * phpMyAdmin setup. Defaults assume a local XAMPP/WAMP install (root, no
 * password).
 */

const DB_HOST = 'localhost';
const DB_NAME = 'csdo_asset_manager';
const DB_USER = 'root';
const DB_PASS = '';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json');

// Preflight requests (browsers only) end here with no body needed.
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

$mysqli = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);
if ($mysqli->connect_errno) {
    http_response_code(500);
    echo json_encode(['error' => 'Database connection failed: ' . $mysqli->connect_error]);
    exit;
}
$mysqli->set_charset('utf8mb4');

/** Reads and JSON-decodes the request body as an assoc array (empty array if none/invalid). */
function read_json_body(): array {
    $raw = file_get_contents('php://input');
    if ($raw === false || $raw === '') return [];
    $decoded = json_decode($raw, true);
    return is_array($decoded) ? $decoded : [];
}

/** Sends a JSON error response and exits. */
function fail(int $status, string $message) {
    http_response_code($status);
    echo json_encode(['error' => $message]);
    exit;
}
