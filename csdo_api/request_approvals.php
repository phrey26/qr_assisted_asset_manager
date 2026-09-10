<?php
require __DIR__ . '/db.php';

// Records one adviser -> principal -> dean routing decision on a request,
// transcribed by the CSDO admin from the photo/scan of the signed paper
// form (requests.request_form_image).
//
//   PUT request_approvals.php
//   { "request_id": 12, "role": "adviser"|"principal"|"dean",
//     "decision": "approved"|"rejected"|"pending", "note": "...",
//     "decided_by": "Admin name" }
//
// Rules (the request must still be 'pending' or 'rejected'):
//   approved  – only if every earlier step (lower seq) is already approved
//   rejected  – allowed at any point; requires a note; also moves the
//               request itself to 'rejected' with that note as the reason
//   pending   – an undo; only if no later step is approved. If the request
//               had been rejected off this step it returns to 'pending'.
//
// Returns { approvals: [...], status, rejection_reason } so the caller can
// refresh the request in place.

if ($_SERVER['REQUEST_METHOD'] !== 'PUT' && $_SERVER['REQUEST_METHOD'] !== 'POST') {
    fail(405, 'Method not allowed');
}

$body = read_json_body();
$requestId = (int) ($body['request_id'] ?? 0);
$role = trim((string) ($body['role'] ?? ''));
$decision = trim((string) ($body['decision'] ?? ''));
$note = trim((string) ($body['note'] ?? ''));
$decidedBy = trim((string) ($body['decided_by'] ?? ''));
if ($decidedBy === '') $decidedBy = null;
if ($note === '') $note = null;

if ($requestId <= 0
    || !in_array($role, ['adviser', 'principal', 'dean'], true)
    || !in_array($decision, ['approved', 'rejected', 'pending'], true)) {
    fail(400, 'request_id, a valid role and a valid decision are required.');
}
if ($decision === 'rejected' && $note === null) {
    fail(400, 'A reason (note) is required when rejecting a step.');
}

$mysqli->begin_transaction();
try {
    $rq = $mysqli->prepare('SELECT status FROM requests WHERE id = ? FOR UPDATE');
    $rq->bind_param('i', $requestId);
    $rq->execute();
    $reqRow = $rq->get_result()->fetch_assoc();
    $rq->close();
    if (!$reqRow) throw new Exception('No request with that id.');
    if (!in_array($reqRow['status'], ['pending', 'rejected'], true)) {
        throw new Exception('This request has already been processed by CSDO — its routing is locked.');
    }

    $lr = $mysqli->prepare(
        'SELECT role, seq, status FROM request_approvals WHERE request_id = ? ' .
        'ORDER BY seq ASC FOR UPDATE'
    );
    $lr->bind_param('i', $requestId);
    $lr->execute();
    $rows = $lr->get_result();
    $steps = [];
    while ($s = $rows->fetch_assoc()) $steps[$s['role']] = $s;
    $lr->close();
    if (!isset($steps[$role])) throw new Exception('This request has no routing row for that role.');
    $mySeq = (int) $steps[$role]['seq'];

    if ($decision === 'approved') {
        foreach ($steps as $s) {
            if ((int) $s['seq'] < $mySeq && $s['status'] !== 'approved') {
                throw new Exception('Earlier signatories must approve before this step.');
            }
        }
    } elseif ($decision === 'pending') {
        foreach ($steps as $s) {
            if ((int) $s['seq'] > $mySeq && $s['status'] === 'approved') {
                throw new Exception('Undo the later steps first.');
            }
        }
    }

    $decidedAtSql = $decision === 'pending' ? 'NULL' : 'NOW()';
    $upd = $mysqli->prepare(
        "UPDATE request_approvals SET status = ?, note = ?, decided_by_name = ?, " .
        "decided_at = $decidedAtSql WHERE request_id = ? AND role = ?"
    );
    $upd->bind_param('sssis', $decision, $note, $decidedBy, $requestId, $role);
    $upd->execute();
    $upd->close();

    // Sync the request itself.
    if ($decision === 'rejected') {
        $u = $mysqli->prepare(
            "UPDATE requests SET status = 'rejected', rejection_reason = ?, " .
            'decided_by_name = ?, decided_at = NOW() WHERE id = ?'
        );
        $u->bind_param('ssi', $note, $decidedBy, $requestId);
        $u->execute();
        $u->close();
    } elseif ($reqRow['status'] === 'rejected') {
        // Re-opening: any step moving off 'rejected' clears the request's
        // rejection so it can be routed again.
        $u = $mysqli->prepare(
            "UPDATE requests SET status = 'pending', rejection_reason = NULL, " .
            'decided_by_name = NULL, decided_at = NULL WHERE id = ?'
        );
        $u->bind_param('i', $requestId);
        $u->execute();
        $u->close();
    }

    $mysqli->commit();
} catch (Exception $e) {
    $mysqli->rollback();
    fail(500, 'Failed to record the approval step: ' . $e->getMessage());
}

$approvals = load_request_approvals($mysqli, [$requestId])[$requestId] ?? [];
$rs = $mysqli->prepare('SELECT status, rejection_reason FROM requests WHERE id = ?');
$rs->bind_param('i', $requestId);
$rs->execute();
$rr = $rs->get_result()->fetch_assoc() ?: [];
$rs->close();

echo json_encode([
    'approvals' => $approvals,
    'status' => $rr['status'] ?? null,
    'rejection_reason' => $rr['rejection_reason'] ?? null,
]);
