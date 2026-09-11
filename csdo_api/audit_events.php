<?php
require __DIR__ . '/db.php';

// The cross-inventory activity feed — every asset_events row, across every
// asset that still exists, newest first. asset_events.php (singular
// endpoint name, plural table) only ever answers "what happened to *this*
// asset" (it requires tag_id); this is the audit-report counterpart —
// "what happened, across the whole inventory".
//
//   GET audit_events.php[?limit=N][&since=YYYY-MM-DD]
//
// `limit` caps how many rows come back (default 200, max 1000) — an office
// can accrue thousands of these over time and nothing here needs them all
// at once. `since` restricts to events on or after that date.
//
// Returns, newest first:
//   [ { id, event_type, detail, request_id, created_at, tag_id,
//       asset_name }, ... ]
//
// An asset that's since been permanently deleted drops out of this feed
// (the join excludes it) — its own history lives in asset_removals.php /
// bulk_disposals.php instead, same as request_removals.php covers a
// deleted request's audit trail separately from this one.

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    fail(405, 'Method not allowed');
}

$limit = isset($_GET['limit']) ? (int) $_GET['limit'] : 200;
if ($limit < 1 || $limit > 1000) $limit = 200;

$since = trim($_GET['since'] ?? '');
$sinceIso = null;
if ($since !== '') {
    $sinceIso = iso_date_or_null($since);
    if ($sinceIso === null) fail(400, 'since must be a valid date (YYYY-MM-DD).');
}

$sql = 'SELECT e.id, e.event_type, e.detail, e.request_id, e.created_at, ' .
    'a.tag_id, a.name AS asset_name ' .
    'FROM asset_events e JOIN assets a ON a.id = e.asset_id ';
if ($sinceIso !== null) {
    $sql .= 'WHERE e.created_at >= ? ';
}
$sql .= 'ORDER BY e.id DESC LIMIT ?';

$stmt = $mysqli->prepare($sql);
if ($sinceIso !== null) {
    $stmt->bind_param('si', $sinceIso, $limit);
} else {
    $stmt->bind_param('i', $limit);
}
$stmt->execute();
$res = $stmt->get_result();

$events = [];
while ($row = $res->fetch_assoc()) {
    $row['id'] = (int) $row['id'];
    $row['request_id'] = $row['request_id'] === null ? null : (int) $row['request_id'];
    $events[] = $row;
}
$stmt->close();

echo json_encode($events);
