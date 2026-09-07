<?php
require __DIR__ . '/db.php';

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    $result = $mysqli->query(
        'SELECT a.id, a.tag_id, a.name, a.category_id, c.value AS category_value, ' .
        'a.description, a.status, a.purchase_date, a.image_base64, ' .
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

    if ($tagId === '' || $name === '' || $categoryId === null || $purchaseDate === '') {
        fail(400, 'tag_id, name, category_id, and purchase_date are required.');
    }
    $categoryId = (int) $categoryId;

    $stmt = $mysqli->prepare(
        'INSERT INTO assets (tag_id, name, category_id, description, status, purchase_date, image_base64) ' .
        'VALUES (?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->bind_param(
        'ssissss',
        $tagId,
        $name,
        $categoryId,
        $description,
        $status,
        $purchaseDate,
        $imageBase64
    );

    if (!$stmt->execute()) {
        $stmt->close();
        fail(500, 'Failed to add asset: ' . $mysqli->error);
    }
    $newId = $stmt->insert_id;
    $stmt->close();

    log_asset_event(
        $mysqli,
        (int) $newId,
        'added',
        $status === 'in_stock' ? 'Added as a stock item' : 'Added to active inventory'
    );

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
    $cur = $mysqli->prepare('SELECT id, status FROM assets WHERE tag_id = ?');
    $cur->bind_param('s', $tagId);
    $cur->execute();
    $assetRow = $cur->get_result()->fetch_assoc();
    $cur->close();
    if (!$assetRow) fail(404, 'No asset with that tag_id.');

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

    // Timeline entry for the manual status change (this endpoint only ever
    // handles the hand-set statuses — 'available', 'maintenance',
    // 'in_stock'; 'in_use' is driven through requests.php instead). The
    // reason, when given, becomes the timeline line's detail.
    log_asset_event($mysqli, (int) $assetRow['id'], $status, $reason !== '' ? $reason : null);

    echo json_encode(['message' => 'Asset updated.']);
    exit;
}

if ($method === 'DELETE') {
    $tagId = trim($_GET['tag_id'] ?? '');
    $reason = trim($_GET['reason'] ?? '');
    if ($tagId === '') fail(400, 'tag_id query parameter is required.');
    if ($reason === '') fail(400, 'A reason for removal is required.');

    // An asset can only be permanently deleted once it's a stock item, and
    // the reason is written to asset_removals (which has no FK to assets,
    // so it outlives this row) before the delete.
    $stmt = $mysqli->prepare(
        'SELECT a.id, a.tag_id, a.name, a.status, c.value AS category ' .
        'FROM assets a JOIN categories c ON c.id = a.category_id WHERE a.tag_id = ?'
    );
    $stmt->bind_param('s', $tagId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$row) fail(404, 'No asset with that tag_id.');
    if ($row['status'] !== 'in_stock') {
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
