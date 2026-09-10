<?php
require __DIR__ . '/db.php';

// Free-text notes / discussion on a request.
//
//   GET  request_comments.php?request_id=12   -> { comments: [ {id, author_name, body, created_at}, ... ] }
//   POST request_comments.php
//        { "request_id": 12, "author_name": "Admin", "body": "..." }
//        -> { comment: {id, author_name, body, created_at} }

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    $requestId = (int) ($_GET['request_id'] ?? 0);
    if ($requestId <= 0) fail(400, 'request_id is required.');
    $comments = load_request_comments($mysqli, [$requestId])[$requestId] ?? [];
    echo json_encode(['comments' => $comments]);
    exit;
}

if ($method === 'POST') {
    $body = read_json_body();
    $requestId = (int) ($body['request_id'] ?? 0);
    $authorName = trim((string) ($body['author_name'] ?? ''));
    $text = trim((string) ($body['body'] ?? ''));
    if ($authorName === '') $authorName = 'CSDO';
    if ($requestId <= 0 || $text === '') {
        fail(400, 'request_id and a non-empty body are required.');
    }
    if (function_exists('mb_substr')) {
        $text = mb_substr($text, 0, 1000);
    } elseif (strlen($text) > 1000) {
        $text = substr($text, 0, 1000);
    }

    $check = $mysqli->prepare('SELECT id FROM requests WHERE id = ?');
    $check->bind_param('i', $requestId);
    $check->execute();
    $exists = $check->get_result()->fetch_assoc();
    $check->close();
    if (!$exists) fail(404, 'No request with that id.');

    $stmt = $mysqli->prepare(
        'INSERT INTO request_comments (request_id, author_name, body) VALUES (?, ?, ?)'
    );
    $stmt->bind_param('iss', $requestId, $authorName, $text);
    if (!$stmt->execute()) {
        $err = $mysqli->error;
        $stmt->close();
        fail(500, 'Failed to post the comment: ' . $err);
    }
    $newId = $stmt->insert_id;
    $stmt->close();

    $row = $mysqli->prepare(
        'SELECT id, author_name, body, created_at FROM request_comments WHERE id = ?'
    );
    $row->bind_param('i', $newId);
    $row->execute();
    $comment = $row->get_result()->fetch_assoc();
    $row->close();
    $comment['id'] = (int) $comment['id'];

    http_response_code(201);
    echo json_encode(['comment' => $comment]);
    exit;
}

fail(405, 'Method not allowed');
