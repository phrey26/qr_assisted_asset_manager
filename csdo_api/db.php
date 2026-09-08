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
 * title); $requestId is informational. Best-effort — a logging failure is
 * swallowed so it never breaks the caller.
 */
function log_asset_event(mysqli $mysqli, int $assetId, string $eventType, ?string $detail = null, ?int $requestId = null): void {
    $stmt = $mysqli->prepare(
        'INSERT INTO asset_events (asset_id, event_type, detail, request_id) VALUES (?, ?, ?, ?)'
    );
    if ($stmt === false) return;
    $stmt->bind_param('issi', $assetId, $eventType, $detail, $requestId);
    @$stmt->execute();
    $stmt->close();
}

/**
 * Appends a row to a BULK asset's stock ledger (see `stock_movements` and
 * lib/models/stock.dart). $kind is one of: 'purchase', 'lent', 'returned',
 * 'damaged', 'disposed', 'adjusted'. $delta is signed; $balanceAfter is the
 * new quantity_total when this row changed the total (else null). Unlike
 * log_asset_event this is called inside the caller's transaction, so a
 * failure is surfaced, not swallowed.
 */
function log_stock_movement(
    mysqli $mysqli,
    int $assetId,
    string $kind,
    int $delta,
    ?int $balanceAfter = null,
    ?string $note = null,
    ?int $requestId = null
): void {
    $stmt = $mysqli->prepare(
        'INSERT INTO stock_movements (asset_id, kind, quantity_delta, balance_after, note, request_id) ' .
        'VALUES (?, ?, ?, ?, ?, ?)'
    );
    if ($stmt === false) return;
    $stmt->bind_param('isiisi', $assetId, $kind, $delta, $balanceAfter, $note, $requestId);
    $stmt->execute();
    $stmt->close();
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
