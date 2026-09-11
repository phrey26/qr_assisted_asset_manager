<?php
require __DIR__ . '/db.php';

// The permanent-removal audit log. GET only.
//   GET /asset_removals.php
// Returns every deleted asset, newest first:
//   [ { id, tag_id, name, category, reason, removed_by_name, removed_at }, ... ]

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    fail(405, 'Method not allowed');
}

$result = $mysqli->query(
    'SELECT id, tag_id, name, category, reason, removed_by_name, removed_at ' .
    'FROM asset_removals ORDER BY id DESC'
);

$rows = [];
while ($row = $result->fetch_assoc()) {
    $row['id'] = (int) $row['id'];
    $rows[] = $row;
}

echo json_encode($rows);
