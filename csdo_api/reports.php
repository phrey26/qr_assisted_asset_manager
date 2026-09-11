<?php
require __DIR__ . '/db.php';

// Aggregated, read-only analytics for the admin dashboard's charts. Every
// section here is a GROUP BY over tables that already exist (requests,
// assets, asset_events, stock_movements) — no schema changes, no writes.
//
//   GET reports.php[?weeks=N][&top=N]
//
// `weeks` bounds how far back the two weekly trends look (default 12, max
// 52). `top` caps how many rows come back in `top_assets` (default 8, max
// 20).
//
// Returns:
//   {
//     requests_by_week:       [ { week_start, status, count }, ... ],
//     status_breakdown:       [ { status, count }, ... ],
//     top_assets:             [ { tag_id, name, category, times_borrowed }, ... ],
//     department_demand:      [ { department, count }, ... ],
//     stock_movement_summary: [ { week_start, direction, units }, ... ],
//   }
//
// `week_start` is the Monday (YYYY-MM-DD) of that ISO week. `direction` is
// 'in' or 'out', derived from stock_movements.quantity_delta's sign (so it
// covers purchase/return/positive-adjust vs. lent/damaged/disposed/
// negative-adjust without hard-coding every `kind`). Only status/department/
// week combinations that actually occurred are returned — rows with a zero
// count simply don't appear; the app fills the gaps for a continuous chart.

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    fail(405, 'Method not allowed');
}

$weeks = isset($_GET['weeks']) ? (int) $_GET['weeks'] : 12;
if ($weeks < 1 || $weeks > 52) $weeks = 12;
$sinceIso = date('Y-m-d', strtotime("-{$weeks} weeks"));

$topLimit = isset($_GET['top']) ? (int) $_GET['top'] : 8;
if ($topLimit < 1 || $topLimit > 20) $topLimit = 8;

// --- requests over time, by status --------------------------------------
$requestsByWeek = [];
$stmt = $mysqli->prepare(
    'SELECT DATE_SUB(DATE(created_at), INTERVAL WEEKDAY(created_at) DAY) AS week_start, ' .
    'status, COUNT(*) AS cnt FROM requests WHERE created_at >= ? ' .
    'GROUP BY week_start, status ORDER BY week_start'
);
$stmt->bind_param('s', $sinceIso);
$stmt->execute();
$res = $stmt->get_result();
while ($r = $res->fetch_assoc()) {
    $requestsByWeek[] = [
        'week_start' => $r['week_start'],
        'status' => $r['status'],
        'count' => (int) $r['cnt'],
    ];
}
$stmt->close();

// --- current asset status breakdown --------------------------------------
$statusBreakdown = [];
$res = $mysqli->query('SELECT status, COUNT(*) AS cnt FROM assets GROUP BY status');
while ($r = $res->fetch_assoc()) {
    $statusBreakdown[] = ['status' => $r['status'], 'count' => (int) $r['cnt']];
}

// --- top borrowed assets --------------------------------------------------
// Individual assets log a 'borrowed' asset_events row per loan; bulk assets
// instead log a 'lent' stock_movements row per hand-out (see requests.php).
// Union the two counts per asset so individually-tracked and bulk items
// compete on the same leaderboard.
$topAssets = [];
$stmt = $mysqli->prepare(
    'SELECT a.tag_id, a.name, c.value AS category, SUM(t.times) AS total ' .
    'FROM ( ' .
    "  SELECT asset_id, COUNT(*) AS times FROM asset_events WHERE event_type = 'borrowed' GROUP BY asset_id " .
    '  UNION ALL ' .
    "  SELECT asset_id, COUNT(*) AS times FROM stock_movements WHERE kind = 'lent' GROUP BY asset_id " .
    ') t JOIN assets a ON a.id = t.asset_id JOIN categories c ON c.id = a.category_id ' .
    'GROUP BY a.id, a.tag_id, a.name, c.value ORDER BY total DESC LIMIT ?'
);
$stmt->bind_param('i', $topLimit);
$stmt->execute();
$res = $stmt->get_result();
while ($r = $res->fetch_assoc()) {
    $topAssets[] = [
        'tag_id' => $r['tag_id'],
        'name' => $r['name'],
        'category' => $r['category'],
        'times_borrowed' => (int) $r['total'],
    ];
}
$stmt->close();

// --- department demand -----------------------------------------------------
$departmentDemand = [];
$res = $mysqli->query(
    'SELECT department, COUNT(*) AS cnt FROM requests GROUP BY department ORDER BY cnt DESC LIMIT 10'
);
while ($r = $res->fetch_assoc()) {
    $departmentDemand[] = ['department' => $r['department'], 'count' => (int) $r['cnt']];
}

// --- stock movement summary: units in vs. out, per week --------------------
$stockSummary = [];
$stmt = $mysqli->prepare(
    'SELECT DATE_SUB(DATE(created_at), INTERVAL WEEKDAY(created_at) DAY) AS week_start, ' .
    "IF(quantity_delta >= 0, 'in', 'out') AS direction, " .
    'SUM(ABS(quantity_delta)) AS units ' .
    'FROM stock_movements WHERE created_at >= ? AND quantity_delta <> 0 ' .
    'GROUP BY week_start, direction ORDER BY week_start'
);
$stmt->bind_param('s', $sinceIso);
$stmt->execute();
$res = $stmt->get_result();
while ($r = $res->fetch_assoc()) {
    $stockSummary[] = [
        'week_start' => $r['week_start'],
        'direction' => $r['direction'],
        'units' => (int) $r['units'],
    ];
}
$stmt->close();

echo json_encode([
    'requests_by_week' => $requestsByWeek,
    'status_breakdown' => $statusBreakdown,
    'top_assets' => $topAssets,
    'department_demand' => $departmentDemand,
    'stock_movement_summary' => $stockSummary,
]);
