<?php
require __DIR__ . '/db.php';

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    $result = $mysqli->query(
        'SELECT a.id, a.tag_id, a.name, a.category_id, c.value AS category_value, ' .
        'c.default_tracking AS category_default_tracking, ' .
        'a.description, a.status, a.purchase_date, a.image_base64, ' .
        'a.tracking, a.quantity_total, a.quantity_out, a.quantity_damaged, ' .
        'a.reorder_point, ' .
        '(SELECT r.asset_condition FROM asset_returns r ' .
        '   JOIN asset_return_assets ra ON ra.return_id = r.id ' .
        '  WHERE ra.asset_id = a.id ORDER BY r.id DESC LIMIT 1) AS last_condition ' .
        'FROM assets a JOIN categories c ON c.id = a.category_id ' .
        'ORDER BY a.id DESC'
    );
    $rows = [];
    while ($row = $result->fetch_assoc()) {
        $row['id'] = (int) $row['id'];
        $row['category_id'] = (int) $row['category_id'];
        $row['tracking'] = $row['tracking'] ?: 'individual';
        $row['quantity_total'] = $row['quantity_total'] === null ? null : (int) $row['quantity_total'];
        $row['quantity_out'] = (int) $row['quantity_out'];
        $row['quantity_damaged'] = (int) $row['quantity_damaged'];
        $row['reorder_point'] = $row['reorder_point'] === null ? null : (int) $row['reorder_point'];
        $rows[] = $row;
    }
    echo json_encode($rows);
    exit;
}

if ($method === 'POST') {
    $body = read_json_body();
    $tagId = trim($body['tag_id'] ?? '');
    $name = trim($body['name'] ?? '');
    $categoryId = $body['category_id'] ?? null;
    $description = (string) ($body['description'] ?? '');
    $status = trim($body['status'] ?? 'available');
    $purchaseDate = trim($body['purchase_date'] ?? '');
    $imageBase64 = $body['image_base64'] ?? null;

    // Bulk-item fields. For an individual asset these stay at their defaults.
    $tracking = trim($body['tracking'] ?? 'individual');
    if (!in_array($tracking, ['individual', 'bulk'], true)) $tracking = 'individual';
    $isBulk = $tracking === 'bulk';
    $quantityTotal = $isBulk ? max(0, (int) ($body['quantity_total'] ?? 0)) : null;
    $reorderPoint = isset($body['reorder_point']) && is_numeric($body['reorder_point'])
        ? max(0, (int) $body['reorder_point'])
        : null;
    // A bulk pool is never "in stock" / "in use" as a whole — it carries a
    // level instead. Keep its status column at 'available' as a placeholder.
    if ($isBulk) $status = 'available';

    if ($tagId === '' || $name === '' || $categoryId === null || $purchaseDate === '') {
        fail(400, 'tag_id, name, category_id, and purchase_date are required.');
    }
    $categoryId = (int) $categoryId;

    $stmt = $mysqli->prepare(
        'INSERT INTO assets (tag_id, name, category_id, description, status, purchase_date, image_base64, ' .
        'tracking, quantity_total, quantity_out, reorder_point) ' .
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)'
    );
    $stmt->bind_param(
        'ssisssssii',
        $tagId,
        $name,
        $categoryId,
        $description,
        $status,
        $purchaseDate,
        $imageBase64,
        $tracking,
        $quantityTotal,
        $reorderPoint
    );

    if (!$stmt->execute()) {
        $stmt->close();
        fail(500, 'Failed to add asset: ' . $mysqli->error);
    }
    $newId = $stmt->insert_id;
    $stmt->close();

    if ($isBulk) {
        log_asset_event($mysqli, (int) $newId, 'added', 'Added as a bulk item');
        if ($quantityTotal > 0) {
            log_stock_movement(
                $mysqli,
                (int) $newId,
                'adjusted',
                $quantityTotal,
                $quantityTotal,
                'Opening stock'
            );
        }
    } else {
        log_asset_event(
            $mysqli,
            (int) $newId,
            'added',
            $status === 'in_stock' ? 'Added as a stock item' : 'Added to active inventory'
        );
    }

    http_response_code(201);
    echo json_encode(['id' => $newId, 'tag_id' => $tagId]);
    exit;
}

if ($method === 'PUT') {
    $body = read_json_body();
    $tagId = trim($body['tag_id'] ?? '');
    $status = trim($body['status'] ?? '');
    // Optional context for the timeline — e.g. why an asset was moved to
    // stock ("Worn out", "Obsolete", ...).
    $reason = trim($body['reason'] ?? '');
    if ($tagId === '' || $status === '') fail(400, 'tag_id and status are required.');

    // Read the current row first so a "change" to the status it already has
    // is a no-op — no needless write, and nothing added to the timeline.
    $cur = $mysqli->prepare('SELECT id, status, tracking FROM assets WHERE tag_id = ?');
    $cur->bind_param('s', $tagId);
    $cur->execute();
    $assetRow = $cur->get_result()->fetch_assoc();
    $cur->close();
    if (!$assetRow) fail(404, 'No asset with that tag_id.');

    // Bulk pools don't have a hand-set status — they carry a quantity. Stock
    // is changed through stock.php (Add stock / Dispose / Correct count).
    if (($assetRow['tracking'] ?? 'individual') === 'bulk') {
        fail(409, 'Bulk items are quantity-tracked and have no status. Use the stock actions instead.');
    }

    if ($assetRow['status'] === $status) {
        echo json_encode(['message' => 'Asset unchanged.']);
        exit;
    }

    $stmt = $mysqli->prepare('UPDATE assets SET status = ? WHERE tag_id = ?');
    $stmt->bind_param('ss', $status, $tagId);
    if (!$stmt->execute()) {
        $stmt->close();
        fail(500, 'Failed to update asset: ' . $mysqli->error);
    }
    $stmt->close();

    // Timeline entry for the change. This endpoint handles the flow-driven
    // status moves that aren't borrowing: 'in_stock' / 'maintenance' (from
    // "Move to stock") and 'available' (from "Move to active"). 'in_use' is
    // driven through requests.php instead. The reason, when given, becomes
    // the timeline line's detail.
    log_asset_event($mysqli, (int) $assetRow['id'], $status, $reason !== '' ? $reason : null);

    echo json_encode(['message' => 'Asset updated.']);
    exit;
}

if ($method === 'DELETE') {
    $tagId = trim($_GET['tag_id'] ?? '');
    $reason = trim($_GET['reason'] ?? '');
    if ($tagId === '') fail(400, 'tag_id query parameter is required.');
    if ($reason === '') fail(400, 'A reason for removal is required.');

    // An individual asset can only be permanently deleted once it's been
    // moved off the active inventory (status 'in_stock' or 'maintenance').
    // A bulk pool can be deleted only once it's been run down to zero
    // (nothing owned, nothing out). The reason is written to asset_removals
    // (no FK to assets, so it outlives this row) before the delete.
    $stmt = $mysqli->prepare(
        'SELECT a.id, a.tag_id, a.name, a.status, a.tracking, a.quantity_total, a.quantity_out, ' .
        'a.quantity_damaged, c.value AS category ' .
        'FROM assets a JOIN categories c ON c.id = a.category_id WHERE a.tag_id = ?'
    );
    $stmt->bind_param('s', $tagId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$row) fail(404, 'No asset with that tag_id.');
    if (($row['tracking'] ?? 'individual') === 'bulk') {
        if ((int) $row['quantity_total'] > 0
            || (int) $row['quantity_out'] > 0
            || (int) $row['quantity_damaged'] > 0) {
            fail(409, 'Dispose of all remaining stock before removing this bulk item.');
        }
    } elseif (!in_array($row['status'], ['in_stock', 'maintenance'], true)) {
        fail(409, 'Only stock items can be permanently deleted. Move the asset to stock first.');
    }

    $mysqli->begin_transaction();
    try {
        $log = $mysqli->prepare(
            'INSERT INTO asset_removals (tag_id, name, category, reason) VALUES (?, ?, ?, ?)'
        );
        $log->bind_param('ssss', $row['tag_id'], $row['name'], $row['category'], $reason);
        $log->execute();
        $log->close();

        $del = $mysqli->prepare('DELETE FROM assets WHERE id = ?');
        $del->bind_param('i', $row['id']);
        $del->execute();
        $del->close();

        $mysqli->commit();
    } catch (Exception $e) {
        $mysqli->rollback();
        fail(500, 'Failed to delete asset: ' . $e->getMessage());
    }

    echo json_encode(['message' => 'Asset deleted.']);
    exit;
}

fail(405, 'Method not allowed');
