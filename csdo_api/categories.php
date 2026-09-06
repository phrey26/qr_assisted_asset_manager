<?php
require __DIR__ . '/db.php';

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    $result = $mysqli->query(
        'SELECT id, display_name, value, icon_code_point, color_value FROM categories ORDER BY id ASC'
    );
    $rows = [];
    while ($row = $result->fetch_assoc()) {
        $row['id'] = (int) $row['id'];
        $row['icon_code_point'] = (int) $row['icon_code_point'];
        $row['color_value'] = (int) $row['color_value'];
        $rows[] = $row;
    }
    echo json_encode($rows);
    exit;
}

if ($method === 'POST') {
    $body = read_json_body();
    $displayName = trim($body['display_name'] ?? '');
    $value = trim($body['value'] ?? '');
    $iconCodePoint = $body['icon_code_point'] ?? null;
    $colorValue = $body['color_value'] ?? null;

    if ($displayName === '' || $value === '' || $iconCodePoint === null || $colorValue === null) {
        fail(400, 'display_name, value, icon_code_point, and color_value are required.');
    }

    $stmt = $mysqli->prepare('SELECT id FROM categories WHERE value = ? LIMIT 1');
    $stmt->bind_param('s', $value);
    $stmt->execute();
    if ($stmt->get_result()->fetch_assoc()) {
        $stmt->close();
        fail(409, 'A category with this value already exists.');
    }
    $stmt->close();

    $stmt = $mysqli->prepare(
        'INSERT INTO categories (display_name, value, icon_code_point, color_value) VALUES (?, ?, ?, ?)'
    );
    $iconCodePoint = (int) $iconCodePoint;
    $colorValue = (int) $colorValue;
    $stmt->bind_param('ssii', $displayName, $value, $iconCodePoint, $colorValue);

    if (!$stmt->execute()) {
        $stmt->close();
        fail(500, 'Failed to add category: ' . $mysqli->error);
    }
    $newId = $stmt->insert_id;
    $stmt->close();

    http_response_code(201);
    echo json_encode([
        'id' => $newId,
        'display_name' => $displayName,
        'value' => $value,
        'icon_code_point' => $iconCodePoint,
        'color_value' => $colorValue,
    ]);
    exit;
}

if ($method === 'DELETE') {
    $value = trim($_GET['value'] ?? '');
    if ($value === '') fail(400, 'value query parameter is required.');

    $stmt = $mysqli->prepare('DELETE FROM categories WHERE value = ?');
    $stmt->bind_param('s', $value);
    if (!$stmt->execute()) {
        $stmt->close();
        fail(500, 'Failed to delete category: ' . $mysqli->error);
    }
    $stmt->close();
    echo json_encode(['message' => 'Category deleted.']);
    exit;
}

fail(405, 'Method not allowed');
