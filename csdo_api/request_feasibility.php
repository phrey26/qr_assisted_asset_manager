<?php
require __DIR__ . '/db.php';

// Requester-facing, DELIBERATELY COARSE availability check for the
// new-request form.
//
//   GET request_feasibility.php?category=<value>&from=<date>&to=<date>&quantity=<n>
//
// Returns only an outlook bucket for one category over one loan window —
// never asset names, tag IDs, counts, or which requests hold what. The
// itemised view (availability.php) is for admins at approval time; a
// requester must not be able to read the inventory through this endpoint.
//
//   { "category": "Furniture", "from": "2026-09-15", "to": "2026-09-16",
//     "requested": 120, "outlook": "ok" | "partial" | "none" | "unknown" }
//
//   ok      – the category can cover the requested amount for those dates
//   partial – some units are free, but fewer than requested
//   none    – nothing in that category is free for those dates
//   unknown – no assets are catalogued under that category (can't tell)

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    fail(405, 'Method not allowed');
}

$category = trim($_GET['category'] ?? '');
$fromIso = iso_date_or_null($_GET['from'] ?? null);
$toIso = iso_date_or_null($_GET['to'] ?? null);
$quantity = max(1, (int) ($_GET['quantity'] ?? 1));

if ($category === '' || $fromIso === null || $toIso === null) {
    fail(400, 'category, from and to are required (from/to must be valid dates).');
}
if ($fromIso > $toIso) {
    fail(400, 'from must be on or before to.');
}

// Per-asset units already committed to reserved / checked-out requests that
// overlap this window (no request identifying info is surfaced to the
// caller — only the numbers are used, below).
$commitments = overlapping_asset_commitments($mysqli, $fromIso, $toIso, 0);

$stmt = $mysqli->prepare(
    'SELECT a.id, a.tracking, a.status, a.quantity_total, a.quantity_damaged ' .
    'FROM assets a JOIN categories c ON c.id = a.category_id ' .
    'WHERE LOWER(c.value) = LOWER(?)'
);
$stmt->bind_param('s', $category);
$stmt->execute();
$res = $stmt->get_result();

$assetCount = 0;
$available = 0;
while ($row = $res->fetch_assoc()) {
    $assetCount++;
    $id = (int) $row['id'];
    $committed = (int) ($commitments[$id]['committed'] ?? 0);
    if (($row['tracking'] ?? 'individual') === 'bulk') {
        $free = (int) $row['quantity_total'] - (int) $row['quantity_damaged'] - $committed;
        if ($free > 0) $available += $free;
    } else {
        $lendable = in_array($row['status'], ['available', 'in_use'], true);
        if ($lendable && $committed === 0) $available += 1;
    }
    // Stop counting once we've clearly cleared the ask — no need for a
    // precise total, and it keeps the figure from being reconstructable.
    if ($available >= $quantity) break;
}
$stmt->close();

if ($assetCount === 0) {
    $outlook = 'unknown';
} elseif ($available >= $quantity) {
    $outlook = 'ok';
} elseif ($available > 0) {
    $outlook = 'partial';
} else {
    $outlook = 'none';
}

echo json_encode([
    'category' => $category,
    'from' => $fromIso,
    'to' => $toIso,
    'requested' => $quantity,
    'outlook' => $outlook,
]);
