<?php
require __DIR__ . '/db.php';

// The deleted-request audit log — the request counterpart to
// asset_removals.php. GET only.
//   GET /request_removals.php
// Returns every hard-deleted request, newest first:
//   [ { id, request_id, title, requester, department, status_at_removal,
//       reason, removed_by_name, removed_at }, ... ]
// Written by the DELETE handler in requests.php; this is its first read
// endpoint — until now the table was write-only.

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    fail(405, 'Method not allowed');
}

$result = $mysqli->query(
    'SELECT id, request_id, title, requester, department, status_at_removal, ' .
    'reason, removed_by_name, removed_at ' .
    'FROM request_removals ORDER BY id DESC'
);

$rows = [];
while ($row = $result->fetch_assoc()) {
    $row['id'] = (int) $row['id'];
    $row['request_id'] = (int) $row['request_id'];
    $rows[] = $row;
}

echo json_encode($rows);
