<?php
require __DIR__ . '/db.php';

// The per-asset timeline. GET only: /asset_events.php?tag_id=CSDO-IT-0231
// Returns the asset's events newest-first, each:
//   { id, event_type, detail, request_id, performed_by, created_at }
// See lib/models/asset_event.dart for how the app renders each event_type.

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    fail(405, 'Method not allowed');
}

$tagId = trim($_GET['tag_id'] ?? '');
if ($tagId === '') fail(400, 'tag_id query parameter is required.');

$stmt = $mysqli->prepare('SELECT id, created_at, purchase_date FROM assets WHERE tag_id = ?');
$stmt->bind_param('s', $tagId);
$stmt->execute();
$asset = $stmt->get_result()->fetch_assoc();
$stmt->close();
if (!$asset) fail(404, 'No asset with that tag_id.');

$assetId = (int) $asset['id'];

$stmt = $mysqli->prepare(
    'SELECT id, event_type, detail, request_id, performed_by, created_at ' .
    'FROM asset_events WHERE asset_id = ? ORDER BY id DESC'
);
$stmt->bind_param('i', $assetId);
$stmt->execute();
$res = $stmt->get_result();

$events = [];
$hasAdded = false;
while ($row = $res->fetch_assoc()) {
    $row['id'] = (int) $row['id'];
    $row['request_id'] = $row['request_id'] === null ? null : (int) $row['request_id'];
    if ($row['event_type'] === 'added') $hasAdded = true;
    $events[] = $row;
}
$stmt->close();

// Assets created before this feature existed have no 'added' row — synthesise
// one from the asset's created_at (falling back to its purchase date) so the
// timeline always has a starting point. Appended last since it's the oldest.
// No performed_by — predates that column entirely, so there's nothing to
// attribute it to.
if (!$hasAdded) {
    $events[] = [
        'id' => 0,
        'event_type' => 'added',
        'detail' => null,
        'request_id' => null,
        'performed_by' => null,
        'created_at' => $asset['created_at'] ?? $asset['purchase_date'],
    ];
}

echo json_encode($events);
