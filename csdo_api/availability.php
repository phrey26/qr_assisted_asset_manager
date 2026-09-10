<?php
require __DIR__ . '/db.php';

// Read-only: how much of each asset is free for a given loan window, for
// the ADMIN approval picker (lib/widgets/asset_assignment_sheet.dart). The
// response itemises the inventory (tag IDs, per-asset counts, the titles of
// clashing requests), so it must not be exposed to requesters — the
// new-request form uses request_feasibility.php, which returns only a
// coarse outlook. When this project grows real roles, gate this endpoint
// behind an admin check.
//
//   GET availability.php?from=YYYY-MM-DD&to=YYYY-MM-DD[&exclude_request=ID]
//
// `exclude_request` is the request being (re)approved — its own current
// assignment is left out of the "already committed" totals so re-opening the
// picker for an approved request doesn't count it against itself.

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    fail(405, 'Method not allowed');
}

$from = trim($_GET['from'] ?? '');
$to = trim($_GET['to'] ?? '');
$excludeRequest = isset($_GET['exclude_request']) ? (int) $_GET['exclude_request'] : 0;

$fromIso = iso_date_or_null($from);
$toIso = iso_date_or_null($to);
if ($fromIso === null || $toIso === null) {
    fail(400, 'from and to are required and must be valid dates (YYYY-MM-DD).');
}
if ($fromIso > $toIso) {
    fail(400, 'from must be on or before to.');
}

$commitments = overlapping_asset_commitments($mysqli, $fromIso, $toIso, $excludeRequest);

$result = $mysqli->query(
    'SELECT a.id, a.tag_id, a.name, a.status, a.tracking, ' .
    'a.quantity_total, a.quantity_out, a.quantity_damaged ' .
    'FROM assets a ORDER BY a.id DESC'
);

$assets = [];
while ($row = $result->fetch_assoc()) {
    $id = (int) $row['id'];
    $isBulk = ($row['tracking'] ?? 'individual') === 'bulk';
    $entry = $commitments[$id] ?? ['committed' => 0, 'conflicts' => []];
    $committed = (int) $entry['committed'];

    if ($isBulk) {
        $owned = (int) $row['quantity_total'];
        $damaged = (int) $row['quantity_damaged'];
        // Free for the window: what's owned, less what's set aside damaged,
        // less what's committed to other approved requests that overlap it.
        $windowFree = max(0, $owned - $damaged - $committed);
        // Free right now: the point-in-time figure the current flow uses.
        $availableNow = max(0, $owned - $damaged - (int) $row['quantity_out']);
    } else {
        // An individual asset is either wholly free for the window or not.
        // It must be part of the borrowable pool ('available' or 'in_use';
        // 'maintenance' / 'in_stock' are filed out) and unclaimed by any
        // overlapping approved request.
        $lendable = in_array($row['status'], ['available', 'in_use'], true);
        $windowFree = ($lendable && $committed === 0) ? 1 : 0;
        $availableNow = $row['status'] === 'available' ? 1 : 0;
    }

    $assets[] = [
        'tag_id' => $row['tag_id'],
        'tracking' => $isBulk ? 'bulk' : 'individual',
        'window_committed' => $committed,
        'window_free' => $windowFree,
        'available_now' => $availableNow,
        'conflicts' => array_values($entry['conflicts']),
    ];
}

echo json_encode(['from' => $fromIso, 'to' => $toIso, 'assets' => $assets]);
