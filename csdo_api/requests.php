<?php
require __DIR__ . '/db.php';

$method = $_SERVER['REQUEST_METHOD'];

/** Loads the logistics/equipment rows for one or more request IDs, grouped by request_id. */
function load_items(mysqli $mysqli, array $requestIds): array {
    $byRequest = [];
    foreach ($requestIds as $id) {
        $byRequest[$id] = ['logistics' => [], 'equipment' => []];
    }
    if (empty($requestIds)) return $byRequest;

    $placeholders = implode(',', array_fill(0, count($requestIds), '?'));
    $types = str_repeat('i', count($requestIds));
    $stmt = $mysqli->prepare(
        'SELECT ri.request_id, ri.item_type, ri.category_id, ri.name, ri.quantity, ' .
        'c.value AS category_value ' .
        'FROM request_items ri LEFT JOIN categories c ON c.id = ri.category_id ' .
        "WHERE ri.request_id IN ($placeholders)"
    );
    $stmt->bind_param($types, ...$requestIds);
    $stmt->execute();
    $result = $stmt->get_result();
    while ($row = $result->fetch_assoc()) {
        $bucket = $row['item_type'] === 'equipment' ? 'equipment' : 'logistics';
        $byRequest[(int) $row['request_id']][$bucket][] = [
            'name' => $row['name'],
            'quantity' => (int) $row['quantity'],
            'category_id' => $row['category_id'] === null ? null : (int) $row['category_id'],
            'category_value' => $row['category_value'],
        ];
    }
    $stmt->close();
    return $byRequest;
}

/**
 * Loads the assets assigned to each request in $requestIds (via
 * request_assets), keyed by request_id. Each entry is a list of
 * {tag_id, name, category_value, status} for display in the app.
 */
function load_request_assets(mysqli $mysqli, array $requestIds): array {
    $byRequest = [];
    foreach ($requestIds as $id) {
        $byRequest[$id] = [];
    }
    if (empty($requestIds)) return $byRequest;

    $placeholders = implode(',', array_fill(0, count($requestIds), '?'));
    $types = str_repeat('i', count($requestIds));
    $stmt = $mysqli->prepare(
        'SELECT ra.request_id, ra.quantity, a.tag_id, a.name, c.value AS category_value, ' .
        'a.status, a.tracking ' .
        'FROM request_assets ra ' .
        'JOIN assets a ON a.id = ra.asset_id ' .
        'JOIN categories c ON c.id = a.category_id ' .
        "WHERE ra.request_id IN ($placeholders) ORDER BY a.name ASC"
    );
    $stmt->bind_param($types, ...$requestIds);
    $stmt->execute();
    $result = $stmt->get_result();
    while ($row = $result->fetch_assoc()) {
        $byRequest[(int) $row['request_id']][] = [
            'tag_id' => $row['tag_id'],
            'name' => $row['name'],
            'category_value' => $row['category_value'],
            'status' => $row['status'],
            'tracking' => $row['tracking'] ?: 'individual',
            'quantity' => (int) $row['quantity'],
        ];
    }
    $stmt->close();
    return $byRequest;
}

/**
 * Sets every asset currently assigned to $requestId back to 'available'
 * (only touching ones still marked 'in_use'), leaving the request_assets
 * link rows in place, and writes a timeline entry per freed asset with
 * $eventType ('returned' when a loan completes, 'released' when an approval
 * is cancelled/rejected). $extraDetail, if given, is appended to the
 * timeline line (e.g. "Condition: Fair"). Returns the ids of the assets it
 * actually freed. Caller owns the surrounding transaction.
 */
/**
 * Puts the units of every BULK line on $requestId back into available stock
 * (quantity_out -= line quantity, floored at 0) and logs a 'returned'
 * movement on each pool's ledger. Called from [release_request_assets] so it
 * runs for both a completed return and a cancelled/rejected approval. Caller
 * owns the transaction. No-op for a request with no bulk lines.
 */
function restore_bulk_request_assets(mysqli $mysqli, int $requestId, ?string $note): void {
    $stmt = $mysqli->prepare(
        'SELECT a.id, ra.quantity FROM request_assets ra ' .
        'JOIN assets a ON a.id = ra.asset_id ' .
        "WHERE ra.request_id = ? AND a.tracking = 'bulk' AND ra.quantity > 0"
    );
    $stmt->bind_param('i', $requestId);
    $stmt->execute();
    $res = $stmt->get_result();
    $lines = [];
    while ($r = $res->fetch_assoc()) {
        $lines[] = ['id' => (int) $r['id'], 'qty' => (int) $r['quantity']];
    }
    $stmt->close();
    if (empty($lines)) return;

    $upd = $mysqli->prepare(
        'UPDATE assets SET quantity_out = GREATEST(0, quantity_out - ?) WHERE id = ?'
    );
    foreach ($lines as $line) {
        $upd->bind_param('ii', $line['qty'], $line['id']);
        $upd->execute();
        log_stock_movement($mysqli, $line['id'], 'returned', -$line['qty'], null, $note, $requestId);
    }
    $upd->close();
}

function release_request_assets(mysqli $mysqli, int $requestId, string $eventType, ?string $extraDetail = null): array {
    // Bulk pools: hand their lent units back to available stock.
    restore_bulk_request_assets(
        $mysqli,
        $requestId,
        $eventType === 'returned' ? 'Returned from loan' : 'Loan cancelled'
    );

    // Which assets are actually being freed (still in_use for this request)?
    $stmt = $mysqli->prepare(
        'SELECT a.id FROM assets a JOIN request_assets ra ON ra.asset_id = a.id ' .
        "WHERE ra.request_id = ? AND a.status = 'in_use'"
    );
    $stmt->bind_param('i', $requestId);
    $stmt->execute();
    $res = $stmt->get_result();
    $assetIds = [];
    while ($r = $res->fetch_assoc()) $assetIds[] = (int) $r['id'];
    $stmt->close();
    if (empty($assetIds)) return [];

    $titleStmt = $mysqli->prepare('SELECT title FROM requests WHERE id = ?');
    $titleStmt->bind_param('i', $requestId);
    $titleStmt->execute();
    $titleRow = $titleStmt->get_result()->fetch_assoc();
    $titleStmt->close();
    $title = $titleRow['title'] ?? null;
    $detail = $extraDetail === null || $extraDetail === ''
        ? $title
        : trim(($title ?? '') . ' · ' . $extraDetail, ' ·');

    $ph = implode(',', array_fill(0, count($assetIds), '?'));
    $ty = str_repeat('i', count($assetIds));
    $upd = $mysqli->prepare("UPDATE assets SET status = 'available' WHERE id IN ($ph)");
    $upd->bind_param($ty, ...$assetIds);
    $upd->execute();
    $upd->close();

    foreach ($assetIds as $assetId) {
        log_asset_event($mysqli, $assetId, $eventType, $detail, $requestId);
    }
    return $assetIds;
}

/**
 * Records a return inspection (condition + notes + photos) for a completed
 * loan, linking it to every asset that was on the request. $inspection is
 * the decoded `return_inspection` object from the PUT body. No-op if it's
 * not an array or there are no assets to link. Caller owns the transaction.
 */
function record_return_inspection(mysqli $mysqli, int $requestId, array $assetIds, $inspection): void {
    if (!is_array($inspection) || empty($assetIds)) return;

    $condition = strtolower(trim((string) ($inspection['asset_condition'] ?? 'good')));
    if (!in_array($condition, ['good', 'fair', 'poor', 'damaged'], true)) $condition = 'good';
    $notes = trim((string) ($inspection['notes'] ?? ''));
    if ($notes === '') $notes = null;
    $daysUsed = isset($inspection['days_used']) && is_numeric($inspection['days_used'])
        ? max(0, (int) $inspection['days_used'])
        : null;
    $photos = is_array($inspection['photos'] ?? null) ? $inspection['photos'] : [];

    $meta = $mysqli->prepare('SELECT title, borrow_date, return_date FROM requests WHERE id = ?');
    $meta->bind_param('i', $requestId);
    $meta->execute();
    $metaRow = $meta->get_result()->fetch_assoc() ?: [];
    $meta->close();
    $title = $metaRow['title'] ?? null;
    $borrowDate = $metaRow['borrow_date'] ?? null;
    $returnDate = $metaRow['return_date'] ?? null;

    $ins = $mysqli->prepare(
        'INSERT INTO asset_returns (request_id, request_title, borrow_date, return_date, days_used, asset_condition, notes) ' .
        'VALUES (?, ?, ?, ?, ?, ?, ?)'
    );
    $ins->bind_param('isssiss', $requestId, $title, $borrowDate, $returnDate, $daysUsed, $condition, $notes);
    $ins->execute();
    $returnId = $ins->insert_id;
    $ins->close();

    $linkStmt = $mysqli->prepare('INSERT INTO asset_return_assets (return_id, asset_id) VALUES (?, ?)');
    foreach ($assetIds as $assetId) {
        $linkStmt->bind_param('ii', $returnId, $assetId);
        $linkStmt->execute();
    }
    $linkStmt->close();

    $photoStmt = $mysqli->prepare('INSERT INTO asset_return_photos (return_id, image_base64) VALUES (?, ?)');
    foreach ($photos as $photo) {
        $photo = (string) $photo;
        if ($photo === '') continue;
        $photoStmt->bind_param('is', $returnId, $photo);
        $photoStmt->execute();
    }
    $photoStmt->close();
}

/** Human label for a condition slug, for the timeline line. */
function condition_label(string $slug): string {
    switch ($slug) {
        case 'fair': return 'Condition: Fair';
        case 'poor': return 'Condition: Poor';
        case 'damaged': return 'Condition: Damaged';
        default: return 'Condition: Good';
    }
}

if ($method === 'GET') {
    $result = $mysqli->query(
        'SELECT id, title, requester, department, venue, borrow_date, return_date, ' .
        'borrow_on, return_on, status, ' .
        'requester_signature, adviser_signature, principal_signature, dean_signature, ' .
        'request_form_image, created_at FROM requests ORDER BY id DESC'
    );
    $rows = [];
    $ids = [];
    while ($row = $result->fetch_assoc()) {
        $row['id'] = (int) $row['id'];
        $ids[] = $row['id'];
        $rows[] = $row;
    }

    $itemsByRequest = load_items($mysqli, $ids);
    $assetsByRequest = load_request_assets($mysqli, $ids);
    foreach ($rows as &$row) {
        $row['logistics'] = $itemsByRequest[$row['id']]['logistics'];
        $row['equipment'] = $itemsByRequest[$row['id']]['equipment'];
        $row['assets'] = $assetsByRequest[$row['id']];
    }
    unset($row);

    echo json_encode($rows);
    exit;
}

if ($method === 'POST') {
    $body = read_json_body();
    $title = trim($body['title'] ?? '');
    $requester = trim($body['requester'] ?? '');
    $department = trim($body['department'] ?? '');
    $venue = $body['venue'] ?? null;
    $venue = $venue === null ? null : trim($venue);
    if ($venue === '') $venue = null;
    $borrowDate = trim($body['borrow_date'] ?? '');
    $returnDate = trim($body['return_date'] ?? '');
    // Machine-comparable loan window. Prefer an explicit ISO value sent by
    // the app; fall back to parsing the human string ("Sep 15, 2026").
    $borrowOn = iso_date_or_null($body['borrow_on'] ?? null) ?? iso_date_or_null($borrowDate);
    $returnOn = iso_date_or_null($body['return_on'] ?? null) ?? iso_date_or_null($returnDate);
    $status = trim($body['status'] ?? 'pending');
    $requesterSignature = trim($body['requester_signature'] ?? '');
    $adviserSignature = trim($body['adviser_signature'] ?? '');
    $principalSignature = trim($body['principal_signature'] ?? '');
    $deanSignature = trim($body['dean_signature'] ?? '');
    $requestFormImage = $body['request_form_image'] ?? null;
    $logistics = is_array($body['logistics'] ?? null) ? $body['logistics'] : [];
    $equipment = is_array($body['equipment'] ?? null) ? $body['equipment'] : [];

    if ($title === '' || $requester === '' || $department === '' || $borrowDate === '' || $returnDate === '') {
        fail(400, 'title, requester, department, borrow_date, and return_date are required.');
    }
    if ($borrowOn !== null && $returnOn !== null && $borrowOn > $returnOn) {
        fail(400, 'The borrow date must be on or before the return date.');
    }

    $mysqli->begin_transaction();
    try {
        $stmt = $mysqli->prepare(
            'INSERT INTO requests (title, requester, department, venue, borrow_date, return_date, ' .
            'borrow_on, return_on, status, ' .
            'requester_signature, adviser_signature, principal_signature, dean_signature, request_form_image) ' .
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
        );
        $stmt->bind_param(
            'ssssssssssssss',
            $title,
            $requester,
            $department,
            $venue,
            $borrowDate,
            $returnDate,
            $borrowOn,
            $returnOn,
            $status,
            $requesterSignature,
            $adviserSignature,
            $principalSignature,
            $deanSignature,
            $requestFormImage
        );
        if (!$stmt->execute()) {
            throw new Exception($mysqli->error);
        }
        $requestId = $stmt->insert_id;
        $stmt->close();

        // Map category value -> id so a request line can link to inventory
        // by either category_id (numeric) or category_value (the string the
        // app carries), case-insensitively.
        $categoryIdByValue = [];
        if ($res = $mysqli->query('SELECT id, value FROM categories')) {
            while ($cr = $res->fetch_assoc()) {
                $categoryIdByValue[strtolower(trim($cr['value']))] = (int) $cr['id'];
            }
            $res->free();
        }

        $itemStmt = $mysqli->prepare(
            'INSERT INTO request_items (request_id, item_type, category_id, name, quantity) VALUES (?, ?, ?, ?, ?)'
        );
        foreach ([['logistics', $logistics], ['equipment', $equipment]] as [$type, $items]) {
            foreach ($items as $item) {
                $name = trim($item['name'] ?? '');
                if ($name === '') continue;
                $quantity = (int) ($item['quantity'] ?? 1);
                if ($quantity <= 0) $quantity = 1;
                $categoryId = null;
                if (isset($item['category_id']) && is_numeric($item['category_id'])) {
                    $categoryId = (int) $item['category_id'];
                } elseif (isset($item['category_value']) && is_string($item['category_value'])) {
                    $categoryId = $categoryIdByValue[strtolower(trim($item['category_value']))] ?? null;
                }
                $itemStmt->bind_param('isisi', $requestId, $type, $categoryId, $name, $quantity);
                if (!$itemStmt->execute()) {
                    throw new Exception($mysqli->error);
                }
            }
        }
        $itemStmt->close();

        $mysqli->commit();
    } catch (Exception $e) {
        $mysqli->rollback();
        fail(500, 'Failed to create request: ' . $e->getMessage());
    }

    http_response_code(201);
    echo json_encode(['id' => $requestId]);
    exit;
}

if ($method === 'PUT') {
    $body = read_json_body();
    $id = $body['id'] ?? null;
    $status = trim($body['status'] ?? '');
    if ($id === null || $status === '') fail(400, 'id and status are required.');
    $id = (int) $id;

    // Assets to hand out for this request, as [{tag_id, quantity}]. Required
    // (non-empty) when approving; ignored otherwise. `assignments` is the
    // current shape (quantity matters for bulk pools); `asset_tag_ids` is
    // still accepted for older callers and treated as quantity 1 each.
    $assignments = [];
    if (is_array($body['assignments'] ?? null)) {
        foreach ($body['assignments'] as $a) {
            $tag = trim((string) ($a['tag_id'] ?? ''));
            if ($tag === '') continue;
            $qty = (int) ($a['quantity'] ?? 1);
            if ($qty <= 0) $qty = 1;
            $assignments[$tag] = $qty; // dedupe by tag, last wins
        }
    } elseif (is_array($body['asset_tag_ids'] ?? null)) {
        foreach ($body['asset_tag_ids'] as $t) {
            $tag = trim((string) $t);
            if ($tag !== '') $assignments[$tag] = 1;
        }
    }

    // Optional return inspection (condition + notes + photos), sent with a
    // 'returned' status. Ignored for any other status. May also carry
    // `bulk_returns`: [{tag_id, damaged}] — units that came back unusable.
    $returnInspection = $body['return_inspection'] ?? null;
    $bulkReturns = [];
    if (is_array($returnInspection) && is_array($returnInspection['bulk_returns'] ?? null)) {
        foreach ($returnInspection['bulk_returns'] as $b) {
            $tag = trim((string) ($b['tag_id'] ?? ''));
            $dmg = (int) ($b['damaged'] ?? 0);
            if ($tag !== '' && $dmg > 0) $bulkReturns[$tag] = $dmg;
        }
    }

    $mysqli->begin_transaction();
    try {
        // The request's current state — every transition below is validated
        // against it. FOR UPDATE so a concurrent status change on the same
        // request serialises behind this one.
        $curStmt = $mysqli->prepare(
            'SELECT status, title, borrow_on, return_on, borrow_date, return_date ' .
            'FROM requests WHERE id = ? FOR UPDATE'
        );
        $curStmt->bind_param('i', $id);
        $curStmt->execute();
        $reqRow = $curStmt->get_result()->fetch_assoc();
        $curStmt->close();
        if (!$reqRow) throw new Exception('No request with that id.');
        $cur = $reqRow['status'];
        $requestTitle = $reqRow['title'] ?? null;

        if (!in_array($status, ['pending', 'approved', 'checked_out', 'rejected', 'returned'], true)) {
            throw new Exception("Unknown request status '$status'.");
        }

        // ---- Reserve: {pending|approved} -> approved ----------------------
        // Approval only RESERVES the assets for the loan window. Nothing
        // physical moves until hand-out ('checked_out').
        if ($status === 'approved') {
            if ($cur === 'checked_out') {
                throw new Exception('Mark this request returned before re-assigning it.');
            }
            if (empty($assignments)) {
                throw new Exception('Pick at least one asset to reserve before approving this request.');
            }

            // Re-approve from a clean slate: drop any prior reservation rows
            // (nothing physical to undo — a reservation holds no asset).
            $d = $mysqli->prepare('DELETE FROM request_assets WHERE request_id = ?');
            $d->bind_param('i', $id);
            $d->execute();
            $d->close();

            $tagList = array_keys($assignments);
            $ph = implode(',', array_fill(0, count($tagList), '?'));
            $ty = str_repeat('s', count($tagList));
            // FOR UPDATE locks the candidate rows for the rest of this
            // transaction, so two admins reserving overlapping requests that
            // share an asset are serialised — the second blocks here until
            // the first commits, then sees its committed quantity.
            $stmt = $mysqli->prepare(
                'SELECT id, tag_id, name, tracking, quantity_total, quantity_out, quantity_damaged ' .
                "FROM assets WHERE tag_id IN ($ph) FOR UPDATE"
            );
            $stmt->bind_param($ty, ...$tagList);
            $stmt->execute();
            $res = $stmt->get_result();
            $found = [];
            while ($r = $res->fetch_assoc()) {
                $found[$r['tag_id']] = $r;
            }
            $stmt->close();
            if (count($found) !== count($tagList)) {
                throw new Exception('One or more of the selected assets no longer exists.');
            }

            // Double-booking guard: reject if any picked asset is already
            // reserved OR out ('approved'/'checked_out') for another request
            // whose loan window overlaps this one. Falls back to parsing the
            // display date strings for legacy rows; if the window still can't
            // be resolved the check is skipped.
            $winFrom = $reqRow['borrow_on'] ?? iso_date_or_null($reqRow['borrow_date'] ?? null);
            $winTo = $reqRow['return_on'] ?? iso_date_or_null($reqRow['return_date'] ?? null);
            if ($winFrom !== null && $winTo !== null) {
                $commitments = overlapping_asset_commitments($mysqli, $winFrom, $winTo, $id, true);
                foreach ($found as $tag => $asset) {
                    $entry = $commitments[(int) $asset['id']] ?? null;
                    if ($entry === null) continue;
                    $committed = (int) $entry['committed'];
                    $clashLabel = conflict_summary($entry['conflicts']);
                    if (($asset['tracking'] ?? 'individual') === 'bulk') {
                        $windowFree = (int) $asset['quantity_total']
                            - (int) $asset['quantity_damaged'] - $committed;
                        if ($assignments[$tag] > $windowFree) {
                            throw new Exception(
                                "Not enough \"{$asset['name']}\" for $winFrom to $winTo — asked for "
                                . "{$assignments[$tag]}, only " . max(0, $windowFree)
                                . " free for that period ($committed already booked by $clashLabel)."
                            );
                        }
                    } elseif ($committed >= 1) {
                        throw new Exception(
                            "\"{$asset['name']}\" is already booked for an overlapping period by $clashLabel."
                        );
                    }
                }
            }

            $link = $mysqli->prepare(
                'INSERT INTO request_assets (request_id, asset_id, quantity) VALUES (?, ?, ?)'
            );
            foreach ($found as $tag => $asset) {
                $assetId = (int) $asset['id'];
                $qty = ($asset['tracking'] ?? 'individual') === 'bulk' ? $assignments[$tag] : 1;
                $link->bind_param('iii', $id, $assetId, $qty);
                $link->execute();
            }
            $link->close();
        }

        // ---- Hand out: approved -> checked_out --------------------------
        // The reserved assets are physically handed over now: individual
        // units flip to 'in_use', bulk pools decrement available stock.
        elseif ($status === 'checked_out') {
            if ($cur !== 'approved') {
                throw new Exception('Only an approved (reserved) request can be handed out.');
            }
            $q = $mysqli->prepare(
                'SELECT a.id, a.name, a.tracking, a.status, a.quantity_total, a.quantity_out, ' .
                'ra.quantity ' .
                'FROM request_assets ra JOIN assets a ON a.id = ra.asset_id ' .
                'WHERE ra.request_id = ? FOR UPDATE'
            );
            $q->bind_param('i', $id);
            $q->execute();
            $qres = $q->get_result();
            $lines = [];
            while ($r = $qres->fetch_assoc()) {
                $lines[] = $r;
            }
            $q->close();
            if (empty($lines)) {
                throw new Exception('This request has no reserved assets to hand out.');
            }

            $markIndividual = $mysqli->prepare(
                "UPDATE assets SET status = 'in_use' WHERE id = ? AND status = 'available'"
            );
            $takeBulk = $mysqli->prepare(
                'UPDATE assets SET quantity_out = quantity_out + ? ' .
                'WHERE id = ? AND quantity_total - quantity_out >= ?'
            );
            foreach ($lines as $line) {
                $assetId = (int) $line['id'];
                $qty = (int) $line['quantity'];
                if (($line['tracking'] ?? 'individual') === 'bulk') {
                    $takeBulk->bind_param('iii', $qty, $assetId, $qty);
                    $takeBulk->execute();
                    if ($takeBulk->affected_rows < 1) {
                        $free = (int) $line['quantity_total'] - (int) $line['quantity_out'];
                        throw new Exception(
                            "Not enough \"{$line['name']}\" in stock to hand out — asked for $qty, $free available."
                        );
                    }
                    log_stock_movement($mysqli, $assetId, 'lent', $qty, null, $requestTitle, $id);
                } else {
                    $markIndividual->bind_param('i', $assetId);
                    $markIndividual->execute();
                    if ($markIndividual->affected_rows < 1) {
                        throw new Exception(
                            "\"{$line['name']}\" is no longer available to hand out — it may have been moved "
                            . "to stock or maintenance, or already handed to another loan."
                        );
                    }
                    log_asset_event($mysqli, $assetId, 'borrowed', $requestTitle, $id);
                }
            }
            $markIndividual->close();
            $takeBulk->close();
        }

        // ---- Return: checked_out -> returned ---------------------------
        elseif ($status === 'returned') {
            if ($cur !== 'checked_out') {
                throw new Exception('Only a handed-out request can be marked returned.');
            }
            // Loan completed: free the assets but keep the request_assets
            // rows so the request still shows what was borrowed. Record the
            // return inspection (condition + photos) against those assets.
            $conditionSlug = is_array($returnInspection)
                ? strtolower(trim((string) ($returnInspection['asset_condition'] ?? 'good')))
                : 'good';
            $freedIds = release_request_assets(
                $mysqli,
                $id,
                'returned',
                is_array($returnInspection) ? condition_label($conditionSlug) : null
            );
            record_return_inspection($mysqli, $id, $freedIds, $returnInspection);
            // Bulk lines reported damaged/lost on return: set those units
            // ASIDE (quantity_damaged) rather than disposing them — the pool
            // total is untouched. release_request_assets already handed every
            // lent unit back to available above; this moves the damaged share
            // out of available into the holding bucket. The admin later
            // repairs them back to stock, or disposes them for good (which is
            // where bulk_disposals gets written).
            if (!empty($bulkReturns)) {
                $titleStmt = $mysqli->prepare('SELECT title FROM requests WHERE id = ?');
                $titleStmt->bind_param('i', $id);
                $titleStmt->execute();
                $rt = $titleStmt->get_result()->fetch_assoc();
                $titleStmt->close();
                $rTitle = $rt['title'] ?? ('Request #' . $id);

                foreach ($bulkReturns as $tag => $dmg) {
                    $q = $mysqli->prepare(
                        "SELECT id, quantity_total, quantity_out, quantity_damaged FROM assets " .
                        "WHERE tag_id = ? AND tracking = 'bulk'"
                    );
                    $q->bind_param('s', $tag);
                    $q->execute();
                    $ba = $q->get_result()->fetch_assoc();
                    $q->close();
                    if (!$ba) continue;
                    // Can't set aside more than is actually available now.
                    $freeNow = (int) $ba['quantity_total'] - (int) $ba['quantity_out'] - (int) $ba['quantity_damaged'];
                    $dmg = min($dmg, max(0, $freeNow));
                    if ($dmg <= 0) continue;
                    $newDamaged = (int) $ba['quantity_damaged'] + $dmg;

                    $u = $mysqli->prepare('UPDATE assets SET quantity_damaged = ? WHERE id = ?');
                    $u->bind_param('ii', $newDamaged, $ba['id']);
                    $u->execute();
                    $u->close();

                    log_stock_movement(
                        $mysqli,
                        (int) $ba['id'],
                        'damaged',
                        -$dmg,
                        null,
                        "Returned damaged — set aside from \"$rTitle\"",
                        $id
                    );
                }
            }
        }

        // ---- Cancel / reject: {pending|approved} -> {pending|rejected} --
        // A reservation holds nothing physical, so cancelling or rejecting
        // just drops its link rows. A checked-out request must be returned
        // first.
        else {
            if ($cur === 'checked_out') {
                throw new Exception(
                    'Mark this request returned before ' .
                    ($status === 'pending' ? 'cancelling its approval.' : 'rejecting it.')
                );
            }
            $d = $mysqli->prepare('DELETE FROM request_assets WHERE request_id = ?');
            $d->bind_param('i', $id);
            $d->execute();
            $d->close();
        }

        $stmt = $mysqli->prepare('UPDATE requests SET status = ? WHERE id = ?');
        $stmt->bind_param('si', $status, $id);
        $stmt->execute();
        $stmt->close();

        $mysqli->commit();
    } catch (Exception $e) {
        $mysqli->rollback();
        fail(500, 'Failed to update request: ' . $e->getMessage());
    }

    echo json_encode(['message' => 'Request updated.']);
    exit;
}

if ($method === 'DELETE') {
    $id = $_GET['id'] ?? null;
    if ($id === null) fail(400, 'id query parameter is required.');
    $id = (int) $id;

    $mysqli->begin_transaction();
    try {
        // Free assets only if this request had actually been handed out — a
        // reservation ('approved') or an untouched request holds nothing
        // physical. The request_assets rows cascade-delete with the request.
        $s = $mysqli->prepare('SELECT status FROM requests WHERE id = ? FOR UPDATE');
        $s->bind_param('i', $id);
        $s->execute();
        $sr = $s->get_result()->fetch_assoc();
        $s->close();
        if ($sr && $sr['status'] === 'checked_out') {
            release_request_assets($mysqli, $id, 'released');
        }

        $stmt = $mysqli->prepare('DELETE FROM requests WHERE id = ?');
        $stmt->bind_param('i', $id);
        $stmt->execute();
        $stmt->close();

        $mysqli->commit();
    } catch (Exception $e) {
        $mysqli->rollback();
        fail(500, 'Failed to delete request: ' . $e->getMessage());
    }
    echo json_encode(['message' => 'Request deleted.']);
    exit;
}

fail(405, 'Method not allowed');
