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
        "SELECT request_id, item_type, name, quantity FROM request_items WHERE request_id IN ($placeholders)"
    );
    $stmt->bind_param($types, ...$requestIds);
    $stmt->execute();
    $result = $stmt->get_result();
    while ($row = $result->fetch_assoc()) {
        $bucket = $row['item_type'] === 'equipment' ? 'equipment' : 'logistics';
        $byRequest[(int) $row['request_id']][$bucket][] = [
            'name' => $row['name'],
            'quantity' => (int) $row['quantity'],
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
        'SELECT ra.request_id, a.tag_id, a.name, c.value AS category_value, a.status ' .
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
 * is cancelled/rejected). Caller owns the surrounding transaction.
 */
function release_request_assets(mysqli $mysqli, int $requestId, string $eventType): void {
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
    if (empty($assetIds)) return;

    $titleStmt = $mysqli->prepare('SELECT title FROM requests WHERE id = ?');
    $titleStmt->bind_param('i', $requestId);
    $titleStmt->execute();
    $titleRow = $titleStmt->get_result()->fetch_assoc();
    $titleStmt->close();
    $title = $titleRow['title'] ?? null;

    $ph = implode(',', array_fill(0, count($assetIds), '?'));
    $ty = str_repeat('i', count($assetIds));
    $upd = $mysqli->prepare("UPDATE assets SET status = 'available' WHERE id IN ($ph)");
    $upd->bind_param($ty, ...$assetIds);
    $upd->execute();
    $upd->close();

    foreach ($assetIds as $assetId) {
        log_asset_event($mysqli, $assetId, $eventType, $title, $requestId);
    }
}

/**
 * Frees the request's assets ([release_request_assets]) and also drops the
 * request_assets link rows. Used whenever a request leaves the approved
 * state without completing a loan — a cancelled approval, a rejection, or a
 * deletion. Caller owns the surrounding transaction.
 */
function free_request_assets(mysqli $mysqli, int $requestId): void {
    release_request_assets($mysqli, $requestId, 'released');

    $stmt = $mysqli->prepare('DELETE FROM request_assets WHERE request_id = ?');
    $stmt->bind_param('i', $requestId);
    $stmt->execute();
    $stmt->close();
}

if ($method === 'GET') {
    $result = $mysqli->query(
        'SELECT id, title, requester, department, venue, borrow_date, return_date, status, ' .
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

    $mysqli->begin_transaction();
    try {
        $stmt = $mysqli->prepare(
            'INSERT INTO requests (title, requester, department, venue, borrow_date, return_date, status, ' .
            'requester_signature, adviser_signature, principal_signature, dean_signature, request_form_image) ' .
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
        );
        $stmt->bind_param(
            'ssssssssssss',
            $title,
            $requester,
            $department,
            $venue,
            $borrowDate,
            $returnDate,
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

        $itemStmt = $mysqli->prepare(
            'INSERT INTO request_items (request_id, item_type, name, quantity) VALUES (?, ?, ?, ?)'
        );
        foreach ([['logistics', $logistics], ['equipment', $equipment]] as [$type, $items]) {
            foreach ($items as $item) {
                $name = trim($item['name'] ?? '');
                if ($name === '') continue;
                $quantity = (int) ($item['quantity'] ?? 1);
                if ($quantity <= 0) $quantity = 1;
                $itemStmt->bind_param('issi', $requestId, $type, $name, $quantity);
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

    // Optional list of asset tag_ids to hand out for this request. Required
    // (non-empty) when approving; ignored for any other status.
    $assetTagIds = $body['asset_tag_ids'] ?? null;
    $assetTagIds = is_array($assetTagIds)
        ? array_values(array_unique(array_filter(array_map(
            fn($t) => trim((string) $t),
            $assetTagIds
        ), fn($t) => $t !== '')))
        : [];

    $mysqli->begin_transaction();
    try {
        if ($status === 'returned') {
            // Loan completed: free the assets but keep the request_assets
            // rows so the request still shows what was borrowed.
            release_request_assets($mysqli, $id, 'returned');
        } else {
            // Any other transition drops the assignment entirely. The
            // approved branch below then re-assigns from a clean slate;
            // pending/rejected leave the request holding nothing.
            free_request_assets($mysqli, $id);
        }

        if ($status === 'approved') {
            if (empty($assetTagIds)) {
                throw new Exception('Pick at least one asset to hand out before approving this request.');
            }

            // Resolve tag_ids -> asset ids (and make sure they all exist).
            $ph = implode(',', array_fill(0, count($assetTagIds), '?'));
            $ty = str_repeat('s', count($assetTagIds));
            $stmt = $mysqli->prepare("SELECT id, tag_id FROM assets WHERE tag_id IN ($ph)");
            $stmt->bind_param($ty, ...$assetTagIds);
            $stmt->execute();
            $res = $stmt->get_result();
            $assetIds = [];
            while ($r = $res->fetch_assoc()) {
                $assetIds[] = (int) $r['id'];
            }
            $stmt->close();
            if (count($assetIds) !== count($assetTagIds)) {
                throw new Exception('One or more of the selected assets no longer exists.');
            }

            $titleStmt = $mysqli->prepare('SELECT title FROM requests WHERE id = ?');
            $titleStmt->bind_param('i', $id);
            $titleStmt->execute();
            $titleRow = $titleStmt->get_result()->fetch_assoc();
            $titleStmt->close();
            $requestTitle = $titleRow['title'] ?? null;

            $link = $mysqli->prepare('INSERT INTO request_assets (request_id, asset_id) VALUES (?, ?)');
            $mark = $mysqli->prepare("UPDATE assets SET status = 'in_use' WHERE id = ?");
            foreach ($assetIds as $assetId) {
                $link->bind_param('ii', $id, $assetId);
                $link->execute();
                $mark->bind_param('i', $assetId);
                $mark->execute();
                log_asset_event($mysqli, $assetId, 'borrowed', $requestTitle, $id);
            }
            $link->close();
            $mark->close();
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
        // Release any assets this request is holding before it goes away
        // (the request_assets rows themselves cascade-delete with it).
        free_request_assets($mysqli, $id);

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
