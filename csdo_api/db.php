<?php
/**
 * Shared DB connection + CORS/JSON setup, included by every endpoint here.
 *
 * Edit DB_HOST / DB_NAME / DB_USER / DB_PASS below to match your MySQL /
 * phpMyAdmin setup. Defaults assume a local XAMPP/WAMP install (root, no
 * password).
 */

const DB_HOST = 'localhost';
const DB_NAME = 'csdo_asset_db';
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

/**
 * Appends a row to an asset's timeline (see the `asset_events` table and
 * lib/models/asset_event.dart). $eventType is a short slug the app knows how
 * to render: 'added', 'available', 'maintenance', 'in_stock', 'borrowed',
 * 'returned', 'released'. $detail is optional context (e.g. a request
 * title); $requestId is informational; $performedBy is the acting admin's
 * name (there's no server-side session — every caller sends whatever name
 * the client had, same as `requests.decided_by_name`), null for a caller
 * that hasn't been updated to send one yet. Best-effort — a logging
 * failure is swallowed so it never breaks the caller.
 */
function log_asset_event(
    mysqli $mysqli,
    int $assetId,
    string $eventType,
    ?string $detail = null,
    ?int $requestId = null,
    ?string $performedBy = null
): void {
    $stmt = $mysqli->prepare(
        'INSERT INTO asset_events (asset_id, event_type, detail, request_id, performed_by) ' .
        'VALUES (?, ?, ?, ?, ?)'
    );
    if ($stmt === false) return;
    $stmt->bind_param('issis', $assetId, $eventType, $detail, $requestId, $performedBy);
    @$stmt->execute();
    $stmt->close();
}

/**
 * Appends a row to a BULK asset's stock ledger (see `stock_movements` and
 * lib/models/stock.dart). $kind is one of: 'purchase', 'lent', 'returned',
 * 'damaged', 'disposed', 'adjusted'. $delta is signed; $balanceAfter is the
 * new quantity_total when this row changed the total (else null);
 * $performedBy is the acting admin's name, same convention as
 * log_asset_event's. Unlike log_asset_event this is called inside the
 * caller's transaction, so a failure is surfaced, not swallowed.
 */
function log_stock_movement(
    mysqli $mysqli,
    int $assetId,
    string $kind,
    int $delta,
    ?int $balanceAfter = null,
    ?string $note = null,
    ?int $requestId = null,
    ?string $performedBy = null
): void {
    $stmt = $mysqli->prepare(
        'INSERT INTO stock_movements ' .
        '(asset_id, kind, quantity_delta, balance_after, note, request_id, performed_by) ' .
        'VALUES (?, ?, ?, ?, ?, ?, ?)'
    );
    if ($stmt === false) return;
    $stmt->bind_param('isiisis', $assetId, $kind, $delta, $balanceAfter, $note, $requestId, $performedBy);
    $stmt->execute();
    $stmt->close();
}

/**
 * Normalises a date to a 'Y-m-d' string, accepting either an ISO date
 * ('2026-09-15') or the app's display format ('Sep 15, 2026'). Returns null
 * when the value is empty or can't be parsed.
 */
function iso_date_or_null($value): ?string {
    if (!is_string($value)) return null;
    $value = trim($value);
    if ($value === '') return null;
    foreach (['Y-m-d', 'M j, Y', 'M d, Y'] as $fmt) {
        $d = DateTime::createFromFormat('!' . $fmt, $value);
        if ($d instanceof DateTime) {
            $errors = DateTime::getLastErrors();
            $clean = $errors === false
                || ((($errors['warning_count'] ?? 0) === 0) && (($errors['error_count'] ?? 0) === 0));
            if ($clean) return $d->format('Y-m-d');
        }
    }
    $ts = strtotime($value);
    return $ts === false ? null : date('Y-m-d', $ts);
}

/**
 * How many units of each asset are already committed to OTHER approved
 * requests whose loan window overlaps the candidate window [$from, $to]
 * (inclusive, 'Y-m-d' strings), keyed by asset id:
 *   [ assetId => [
 *       'committed' => <int total units across the overlapping requests>,
 *       'conflicts' => [ {request_id, title, borrow_on, return_on, quantity}, ... ],
 *   ] ]
 * $excludeRequestId is skipped so re-approving / editing a request's own
 * assignment never conflicts with itself. Both a reservation ('approved')
 * and an active loan ('checked_out') hold the window. An approved request
 * whose borrow_on/return_on is NULL (unparseable legacy dates) is treated
 * as spanning all time, so it always counts — deliberately conservative.
 *
 * Pass $forUpdate = true from inside the approval transaction: it makes this
 * a locking read so it sees rows a competing approval committed while this
 * one was blocked on the shared asset lock, instead of this transaction's
 * older snapshot.
 */
function overlapping_asset_commitments(
    mysqli $mysqli,
    string $from,
    string $to,
    int $excludeRequestId = 0,
    bool $forUpdate = false
): array {
    $stmt = $mysqli->prepare(
        'SELECT ra.asset_id, ra.quantity, r.id AS request_id, r.title, ' .
        'r.borrow_on, r.return_on, r.borrow_date, r.return_date ' .
        'FROM request_assets ra JOIN requests r ON r.id = ra.request_id ' .
        "WHERE r.status IN ('approved', 'checked_out') AND r.id <> ? " .
        "AND COALESCE(r.borrow_on, '1000-01-01') <= ? " .
        "AND COALESCE(r.return_on, '9999-12-31') >= ?" .
        ($forUpdate ? ' FOR UPDATE' : '')
    );
    if ($stmt === false) return [];
    $stmt->bind_param('iss', $excludeRequestId, $to, $from);
    $stmt->execute();
    $res = $stmt->get_result();
    $out = [];
    while ($row = $res->fetch_assoc()) {
        $assetId = (int) $row['asset_id'];
        if (!isset($out[$assetId])) $out[$assetId] = ['committed' => 0, 'conflicts' => []];
        $out[$assetId]['committed'] += (int) $row['quantity'];
        $out[$assetId]['conflicts'][] = [
            'request_id' => (int) $row['request_id'],
            'title' => $row['title'],
            'borrow_on' => $row['borrow_on'] ?? $row['borrow_date'],
            'return_on' => $row['return_on'] ?? $row['return_date'],
            'quantity' => (int) $row['quantity'],
        ];
    }
    $stmt->close();
    return $out;
}

/**
 * A short human label for a list of conflicting requests (as produced by
 * [overlapping_asset_commitments]) — e.g.
 *   "ICT week seminar" (2026-09-15 to 2026-09-16) and 1 more
 * Names at most the first two, then a count of the rest.
 */
function conflict_summary(array $conflicts): string {
    if (empty($conflicts)) return 'another approved request';
    $labels = [];
    foreach (array_slice($conflicts, 0, 2) as $c) {
        $fromLabel = (string) ($c['borrow_on'] ?? '');
        $toLabel = (string) ($c['return_on'] ?? '');
        $range = ($fromLabel !== '' && $toLabel !== '') ? " ($fromLabel to $toLabel)" : '';
        $title = (string) ($c['title'] ?? ('Request #' . ($c['request_id'] ?? '?')));
        $labels[] = '"' . $title . '"' . $range;
    }
    $extra = count($conflicts) - count($labels);
    $text = implode(', ', $labels);
    if ($extra > 0) $text .= " and $extra more";
    return $text;
}

/**
 * Loads the adviser -> principal -> dean routing rows for each request in
 * $requestIds, keyed by request_id, ordered by seq. Each entry is
 * {role, seq, status, printed_name, note, decided_by_name, decided_at}.
 */
function load_request_approvals(mysqli $mysqli, array $requestIds): array {
    $byRequest = [];
    foreach ($requestIds as $id) $byRequest[$id] = [];
    if (empty($requestIds)) return $byRequest;

    $placeholders = implode(',', array_fill(0, count($requestIds), '?'));
    $types = str_repeat('i', count($requestIds));
    $stmt = $mysqli->prepare(
        'SELECT request_id, role, seq, status, printed_name, note, decided_by_name, decided_at ' .
        "FROM request_approvals WHERE request_id IN ($placeholders) ORDER BY seq ASC"
    );
    if ($stmt === false) return $byRequest;
    $stmt->bind_param($types, ...$requestIds);
    $stmt->execute();
    $result = $stmt->get_result();
    while ($row = $result->fetch_assoc()) {
        $byRequest[(int) $row['request_id']][] = [
            'role' => $row['role'],
            'seq' => (int) $row['seq'],
            'status' => $row['status'],
            'printed_name' => $row['printed_name'],
            'note' => $row['note'],
            'decided_by_name' => $row['decided_by_name'],
            'decided_at' => $row['decided_at'],
        ];
    }
    $stmt->close();
    return $byRequest;
}

/**
 * Loads the comment thread for each request in $requestIds, keyed by
 * request_id, newest first. Each entry is {id, author_name, body, created_at}.
 */
function load_request_comments(mysqli $mysqli, array $requestIds): array {
    $byRequest = [];
    foreach ($requestIds as $id) $byRequest[$id] = [];
    if (empty($requestIds)) return $byRequest;

    $placeholders = implode(',', array_fill(0, count($requestIds), '?'));
    $types = str_repeat('i', count($requestIds));
    $stmt = $mysqli->prepare(
        'SELECT id, request_id, author_name, body, created_at ' .
        "FROM request_comments WHERE request_id IN ($placeholders) ORDER BY id DESC"
    );
    if ($stmt === false) return $byRequest;
    $stmt->bind_param($types, ...$requestIds);
    $stmt->execute();
    $result = $stmt->get_result();
    while ($row = $result->fetch_assoc()) {
        $byRequest[(int) $row['request_id']][] = [
            'id' => (int) $row['id'],
            'author_name' => $row['author_name'],
            'body' => $row['body'],
            'created_at' => $row['created_at'],
        ];
    }
    $stmt->close();
    return $byRequest;
}

/**
 * True when every routing row for $requestId is 'approved' — i.e. adviser,
 * principal and dean have all signed off and CSDO may now approve.
 */
function approval_chain_complete(mysqli $mysqli, int $requestId): bool {
    $stmt = $mysqli->prepare(
        "SELECT COUNT(*) AS total, SUM(status = 'approved') AS approved " .
        'FROM request_approvals WHERE request_id = ?'
    );
    if ($stmt === false) return false;
    $stmt->bind_param('i', $requestId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    $total = (int) ($row['total'] ?? 0);
    $approved = (int) ($row['approved'] ?? 0);
    return $total > 0 && $total === $approved;
}

/** Reads and JSON-decodes the request body as an assoc array (empty array if none/invalid). */
function read_json_body(): array {
    $raw = file_get_contents('php://input');
    if ($raw === false || $raw === '') return [];
    $decoded = json_decode($raw, true);
    return is_array($decoded) ? $decoded : [];
}

/** Sends a JSON error response and exits. Extra fields are merged into the body. */
function fail(int $status, string $message, array $extra = []) {
    http_response_code($status);
    echo json_encode(array_merge(['error' => $message], $extra));
    exit;
}

/** True if $value looks like a valid email address. */
function valid_email(string $value): bool {
    return filter_var($value, FILTER_VALIDATE_EMAIL) !== false;
}

/**
 * Email providers an account may be registered with. Exact-domain match,
 * case-insensitive. Edit this list to add or drop providers; the register
 * screen (lib/screens/register_screen.dart) keeps a matching copy for its
 * client-side check.
 */
const ALLOWED_EMAIL_DOMAINS = [
    // Gmail
    'gmail.com', 'googlemail.com',
    // Yahoo
    'yahoo.com', 'yahoo.com.ph', 'ymail.com', 'rocketmail.com',
    // Outlook / Microsoft
    'outlook.com', 'outlook.ph', 'hotmail.com', 'live.com', 'msn.com',
    // Holy Angel University (Microsoft 365)
    'hau.edu.ph',
];

/** True if $email's domain is in ALLOWED_EMAIL_DOMAINS. */
function email_domain_allowed(string $email): bool {
    $at = strrpos($email, '@');
    if ($at === false) return false;
    $domain = strtolower(substr($email, $at + 1));
    return in_array($domain, ALLOWED_EMAIL_DOMAINS, true);
}

/**
 * In local dev (MAIL_DEV_MODE + MAIL_DEV_RETURN_CODE, and mail didn't really
 * send), returns ['dev_code' => $code, 'dev_delivery' => $status] so the app
 * can show the code without an inbox. Returns [] otherwise. Requires
 * lib/mailer.php to have been included.
 */
function dev_code_payload(string $code, string $deliveryStatus): array {
    if (
        defined('MAIL_DEV_MODE') && MAIL_DEV_MODE
        && defined('MAIL_DEV_RETURN_CODE') && MAIL_DEV_RETURN_CODE
        && $deliveryStatus !== 'sent'
    ) {
        return ['dev_code' => $code, 'dev_delivery' => $deliveryStatus];
    }
    return $deliveryStatus === 'sent' ? [] : ['dev_delivery' => $deliveryStatus];
}
