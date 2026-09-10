<?php
require __DIR__ . '/db.php';

// Condition & usage history for one asset.
//   GET /asset_returns.php?tag_id=CSDO-IT-0231
// Returns:
//   {
//     "summary": { "times_borrowed": int, "days_used": int,
//                  "current_condition": string|null, "currently_out": bool },
//     "inspections": [ { id, request_title, borrow_date, return_date,
//                        days_used, asset_condition, notes, created_at,
//                        photos: [base64, ...] }, ... ]   // newest first
//   }

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    fail(405, 'Method not allowed');
}

$tagId = trim($_GET['tag_id'] ?? '');
if ($tagId === '') fail(400, 'tag_id query parameter is required.');

$stmt = $mysqli->prepare('SELECT id, status FROM assets WHERE tag_id = ?');
$stmt->bind_param('s', $tagId);
$stmt->execute();
$asset = $stmt->get_result()->fetch_assoc();
$stmt->close();
if (!$asset) fail(404, 'No asset with that tag_id.');
$assetId = (int) $asset['id'];
$currentlyOut = $asset['status'] === 'in_use';

// Inspections linked to this asset, newest first.
$stmt = $mysqli->prepare(
    'SELECT r.id, r.request_title, r.borrow_date, r.return_date, r.days_used, r.days_late, ' .
    'r.asset_condition, r.notes, r.created_at ' .
    'FROM asset_returns r JOIN asset_return_assets ra ON ra.return_id = r.id ' .
    'WHERE ra.asset_id = ? ORDER BY r.id DESC'
);
$stmt->bind_param('i', $assetId);
$stmt->execute();
$res = $stmt->get_result();

$inspections = [];
$returnIds = [];
$daysTotal = 0;
while ($row = $res->fetch_assoc()) {
    $row['id'] = (int) $row['id'];
    $row['days_used'] = $row['days_used'] === null ? null : (int) $row['days_used'];
    $row['days_late'] = $row['days_late'] === null ? null : (int) $row['days_late'];
    if ($row['days_used'] !== null) $daysTotal += $row['days_used'];
    $row['photos'] = [];
    $inspections[$row['id']] = $row;
    $returnIds[] = $row['id'];
}
$stmt->close();

// Photos for those inspections.
if (!empty($returnIds)) {
    $ph = implode(',', array_fill(0, count($returnIds), '?'));
    $ty = str_repeat('i', count($returnIds));
    $stmt = $mysqli->prepare(
        "SELECT return_id, image_base64 FROM asset_return_photos WHERE return_id IN ($ph) ORDER BY id ASC"
    );
    $stmt->bind_param($ty, ...$returnIds);
    $stmt->execute();
    $pres = $stmt->get_result();
    while ($p = $pres->fetch_assoc()) {
        $rid = (int) $p['return_id'];
        if (isset($inspections[$rid])) {
            $inspections[$rid]['photos'][] = $p['image_base64'];
        }
    }
    $stmt->close();
}

$list = array_values($inspections);

$summary = [
    'times_borrowed' => count($list) + ($currentlyOut ? 1 : 0),
    'days_used' => $daysTotal,
    'current_condition' => $list[0]['asset_condition'] ?? null,
    'currently_out' => $currentlyOut,
];

echo json_encode(['summary' => $summary, 'inspections' => $list]);
