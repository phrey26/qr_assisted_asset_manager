<?php
require __DIR__ . '/db.php';

// The permanent bulk-stock disposal log. GET only.
//   GET /bulk_disposals.php
// Returns every disposal, newest first:
//   [ { id, tag_id, name, category, quantity, reason, disposed_at }, ... ]

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    fail(405, 'Method not allowed');
}

$result = $mysqli->query(
    'SELECT id, tag_id, name, category, quantity, reason, disposed_at ' .
    'FROM bulk_disposals ORDER BY id DESC'
);

$rows = [];
while ($row = $result->fetch_assoc()) {
    $row['id'] = (int) $row['id'];
    $row['quantity'] = (int) $row['quantity'];
    $rows[] = $row;
}

echo json_encode($rows);
