<?php
require __DIR__ . '/db.php';

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    $result = $mysqli->query(
        'SELECT a.id, a.tag_id, a.name, a.category_id, c.value AS category_value, ' .
        'a.description, a.status, a.purchase_date, a.image_base64 ' .
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

    http_response_code(201);
    echo json_encode(['id' => $newId, 'tag_id' => $tagId]);
    exit;
}

if ($method === 'PUT') {
    $body = read_json_body();
    $tagId = trim($body['tag_id'] ?? '');
    $status = trim($body['status'] ?? '');
    if ($tagId === '' || $status === '') fail(400, 'tag_id and status are required.');

    $stmt = $mysqli->prepare('UPDATE assets SET status = ? WHERE tag_id = ?');
    $stmt->bind_param('ss', $status, $tagId);
    if (!$stmt->execute()) {
        $stmt->close();
        fail(500, 'Failed to update asset: ' . $mysqli->error);
    }
    $stmt->close();
    echo json_encode(['message' => 'Asset updated.']);
    exit;
}

if ($method === 'DELETE') {
    $tagId = trim($_GET['tag_id'] ?? '');
    if ($tagId === '') fail(400, 'tag_id query parameter is required.');

    $stmt = $mysqli->prepare('DELETE FROM assets WHERE tag_id = ?');
    $stmt->bind_param('s', $tagId);
    if (!$stmt->execute()) {
        $stmt->close();
        fail(500, 'Failed to delete asset: ' . $mysqli->error);
    }
    $stmt->close();
    echo json_encode(['message' => 'Asset deleted.']);
    exit;
}

fail(405, 'Method not allowed');
