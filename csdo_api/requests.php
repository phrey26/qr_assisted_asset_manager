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
    foreach ($rows as &$row) {
        $row['logistics'] = $itemsByRequest[$row['id']]['logistics'];
        $row['equipment'] = $itemsByRequest[$row['id']]['equipment'];
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
    $stmt = $mysqli->prepare('UPDATE requests SET status = ? WHERE id = ?');
    $stmt->bind_param('si', $status, $id);
    if (!$stmt->execute()) {
        $stmt->close();
        fail(500, 'Failed to update request: ' . $mysqli->error);
    }
    $stmt->close();
    echo json_encode(['message' => 'Request updated.']);
    exit;
}

if ($method === 'DELETE') {
    $id = $_GET['id'] ?? null;
    if ($id === null) fail(400, 'id query parameter is required.');
    $id = (int) $id;

    $stmt = $mysqli->prepare('DELETE FROM requests WHERE id = ?');
    $stmt->bind_param('i', $id);
    if (!$stmt->execute()) {
        $stmt->close();
        fail(500, 'Failed to delete request: ' . $mysqli->error);
    }
    $stmt->close();
    echo json_encode(['message' => 'Request deleted.']);
    exit;
}

fail(405, 'Method not allowed');
