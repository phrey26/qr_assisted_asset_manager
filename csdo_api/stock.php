<?php
require __DIR__ . '/db.php';

// Stock management for BULK assets.
//
//   GET  /stock.php?tag_id=CSDO-...   -> { summary, movements[], purchases[] }
//   POST /stock.php   body { tag_id, action, ... }
//     action = 'purchase' : { quantity, unit_cost?, total_cost?, supplier?, note?, purchased_at? }
//                           -> adds to quantity_total, records the purchase.
//     action = 'dispose'  : { quantity, reason }
//                           -> removes from quantity_total (available only),
//                              logs to bulk_disposals (permanent).
//     action = 'adjust'   : { new_total, reason }
//                           -> sets quantity_total to a corrected count.

$method = $_SERVER['REQUEST_METHOD'];

/** Loads the bulk asset row by tag_id, or fails 404 / 409 if not usable. */
function load_bulk_asset(mysqli $mysqli, string $tagId): array {
    $stmt = $mysqli->prepare(
        'SELECT a.id, a.tag_id, a.name, a.tracking, a.quantity_total, a.quantity_out, ' .
        'a.quantity_damaged, a.reorder_point, a.unit_label, c.value AS category ' .
        'FROM assets a JOIN categories c ON c.id = a.category_id WHERE a.tag_id = ?'
    );
    $stmt->bind_param('s', $tagId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$row) fail(404, 'No asset with that tag_id.');
    if (($row['tracking'] ?? 'individual') !== 'bulk') {
        fail(409, 'This asset is not a bulk item.');
    }
    $row['id'] = (int) $row['id'];
    $row['quantity_total'] = (int) $row['quantity_total'];
    $row['quantity_out'] = (int) $row['quantity_out'];
    $row['quantity_damaged'] = (int) $row['quantity_damaged'];
    $row['reorder_point'] = $row['reorder_point'] === null ? null : (int) $row['reorder_point'];
    return $row;
}

/**
 * Builds the stock summary. `available` is what can be lent right now:
 * owned, minus what's on loan, minus what's set aside damaged.
 */
function stock_summary(array $asset): array {
    $damaged = $asset['quantity_damaged'] ?? 0;
    $available = $asset['quantity_total'] - $asset['quantity_out'] - $damaged;
    $reorder = $asset['reorder_point'];
    return [
        'total' => $asset['quantity_total'],
        'out' => $asset['quantity_out'],
        'damaged' => $damaged,
        'available' => $available,
        'reorder_point' => $reorder,
        'unit_label' => $asset['unit_label'],
        'low_stock' => $reorder !== null && $available <= $reorder,
    ];
}

if ($method === 'GET') {
    $tagId = trim($_GET['tag_id'] ?? '');
    if ($tagId === '') fail(400, 'tag_id query parameter is required.');
    $asset = load_bulk_asset($mysqli, $tagId);

    $movements = [];
    $stmt = $mysqli->prepare(
        'SELECT id, kind, quantity_delta, balance_after, note, request_id, created_at ' .
        'FROM stock_movements WHERE asset_id = ? ORDER BY id DESC'
    );
    $stmt->bind_param('i', $asset['id']);
    $stmt->execute();
    $res = $stmt->get_result();
    while ($r = $res->fetch_assoc()) {
        $movements[] = [
            'id' => (int) $r['id'],
            'kind' => $r['kind'],
            'quantity_delta' => (int) $r['quantity_delta'],
            'balance_after' => $r['balance_after'] === null ? null : (int) $r['balance_after'],
            'note' => $r['note'],
            'request_id' => $r['request_id'] === null ? null : (int) $r['request_id'],
            'created_at' => $r['created_at'],
        ];
    }
    $stmt->close();

    $purchases = [];
    $stmt = $mysqli->prepare(
        'SELECT id, quantity, unit_cost, total_cost, supplier, note, purchased_at, created_at ' .
        'FROM stock_purchases WHERE asset_id = ? ORDER BY id DESC'
    );
    $stmt->bind_param('i', $asset['id']);
    $stmt->execute();
    $res = $stmt->get_result();
    while ($r = $res->fetch_assoc()) {
        $purchases[] = [
            'id' => (int) $r['id'],
            'quantity' => (int) $r['quantity'],
            'unit_cost' => $r['unit_cost'] === null ? null : (float) $r['unit_cost'],
            'total_cost' => $r['total_cost'] === null ? null : (float) $r['total_cost'],
            'supplier' => $r['supplier'],
            'note' => $r['note'],
            'purchased_at' => $r['purchased_at'],
            'created_at' => $r['created_at'],
        ];
    }
    $stmt->close();

    echo json_encode([
        'summary' => stock_summary($asset),
        'movements' => $movements,
        'purchases' => $purchases,
    ]);
    exit;
}

if ($method === 'POST') {
    $body = read_json_body();
    $tagId = trim($body['tag_id'] ?? '');
    $action = trim($body['action'] ?? '');
    if ($tagId === '') fail(400, 'tag_id is required.');
    if (!in_array($action, ['purchase', 'dispose', 'restore', 'adjust'], true)) {
        fail(400, "action must be 'purchase', 'dispose', 'restore' or 'adjust'.");
    }

    $asset = load_bulk_asset($mysqli, $tagId);

    $mysqli->begin_transaction();
    try {
        if ($action === 'purchase') {
            $quantity = (int) ($body['quantity'] ?? 0);
            if ($quantity <= 0) throw new Exception('Enter how many units were bought.');
            $unitCost = is_numeric($body['unit_cost'] ?? null) ? (float) $body['unit_cost'] : null;
            $totalCost = is_numeric($body['total_cost'] ?? null) ? (float) $body['total_cost'] : null;
            if ($totalCost === null && $unitCost !== null) $totalCost = $unitCost * $quantity;
            $supplier = trim((string) ($body['supplier'] ?? '')) ?: null;
            $note = trim((string) ($body['note'] ?? '')) ?: null;
            $purchasedAt = trim((string) ($body['purchased_at'] ?? '')) ?: null;

            $newTotal = $asset['quantity_total'] + $quantity;
            $upd = $mysqli->prepare('UPDATE assets SET quantity_total = ? WHERE id = ?');
            $upd->bind_param('ii', $newTotal, $asset['id']);
            $upd->execute();
            $upd->close();

            $ins = $mysqli->prepare(
                'INSERT INTO stock_purchases (asset_id, quantity, unit_cost, total_cost, supplier, note, purchased_at) ' .
                'VALUES (?, ?, ?, ?, ?, ?, ?)'
            );
            $ins->bind_param('iiddsss', $asset['id'], $quantity, $unitCost, $totalCost, $supplier, $note, $purchasedAt);
            $ins->execute();
            $ins->close();

            $movementNote = $supplier !== null ? "From $supplier" : $note;
            log_stock_movement($mysqli, $asset['id'], 'purchase', $quantity, $newTotal, $movementNote);

            $mysqli->commit();
            echo json_encode(['message' => 'Stock added.', 'summary' => stock_summary(
                array_merge($asset, ['quantity_total' => $newTotal])
            )]);
            exit;
        }

        if ($action === 'dispose') {
            $quantity = (int) ($body['quantity'] ?? 0);
            $reason = trim((string) ($body['reason'] ?? ''));
            if ($quantity <= 0) throw new Exception('Enter how many units to dispose of.');
            if ($reason === '') throw new Exception('A reason for the disposal is required.');
            // Units on loan can't be disposed; everything else that's owned
            // (available + set-aside damaged) can. Damaged units go first.
            $disposable = $asset['quantity_total'] - $asset['quantity_out'];
            if ($quantity > $disposable) {
                throw new Exception("Only $disposable can be disposed of ({$asset['quantity_out']} are out on loan).");
            }
            $fromDamaged = min($quantity, $asset['quantity_damaged']);
            $newDamaged = $asset['quantity_damaged'] - $fromDamaged;
            $newTotal = $asset['quantity_total'] - $quantity;

            $upd = $mysqli->prepare(
                'UPDATE assets SET quantity_total = ?, quantity_damaged = ? WHERE id = ?'
            );
            $upd->bind_param('iii', $newTotal, $newDamaged, $asset['id']);
            $upd->execute();
            $upd->close();

            $ins = $mysqli->prepare(
                'INSERT INTO bulk_disposals (tag_id, name, category, quantity, reason) VALUES (?, ?, ?, ?, ?)'
            );
            $ins->bind_param('sssis', $asset['tag_id'], $asset['name'], $asset['category'], $quantity, $reason);
            $ins->execute();
            $ins->close();

            log_stock_movement($mysqli, $asset['id'], 'disposed', -$quantity, $newTotal, $reason);

            $mysqli->commit();
            echo json_encode(['message' => 'Stock disposed.', 'summary' => stock_summary(
                array_merge($asset, ['quantity_total' => $newTotal, 'quantity_damaged' => $newDamaged])
            )]);
            exit;
        }

        if ($action === 'restore') {
            // Damaged units repaired and put back into available stock.
            $quantity = (int) ($body['quantity'] ?? 0);
            $note = trim((string) ($body['note'] ?? '')) ?: 'Repaired — back in service';
            if ($quantity <= 0) throw new Exception('Enter how many units were repaired.');
            if ($quantity > $asset['quantity_damaged']) {
                throw new Exception("Only {$asset['quantity_damaged']} unit(s) are set aside damaged.");
            }
            $newDamaged = $asset['quantity_damaged'] - $quantity;
            $upd = $mysqli->prepare('UPDATE assets SET quantity_damaged = ? WHERE id = ?');
            $upd->bind_param('ii', $newDamaged, $asset['id']);
            $upd->execute();
            $upd->close();

            log_stock_movement($mysqli, $asset['id'], 'restored', $quantity, null, $note);

            $mysqli->commit();
            echo json_encode(['message' => 'Stock restored.', 'summary' => stock_summary(
                array_merge($asset, ['quantity_damaged' => $newDamaged])
            )]);
            exit;
        }

        // action === 'adjust'
        $newTotal = (int) ($body['new_total'] ?? -1);
        $reason = trim((string) ($body['reason'] ?? ''));
        if ($newTotal < 0) throw new Exception('Enter the corrected total (0 or more).');
        if ($reason === '') throw new Exception('A reason for the correction is required.');
        $committed = $asset['quantity_out'] + $asset['quantity_damaged'];
        if ($newTotal < $committed) {
            throw new Exception("Can't set the total below the $committed unit(s) currently on loan or set aside damaged.");
        }
        $delta = $newTotal - $asset['quantity_total'];
        $upd = $mysqli->prepare('UPDATE assets SET quantity_total = ? WHERE id = ?');
        $upd->bind_param('ii', $newTotal, $asset['id']);
        $upd->execute();
        $upd->close();

        log_stock_movement($mysqli, $asset['id'], 'adjusted', $delta, $newTotal, $reason);

        $mysqli->commit();
        echo json_encode(['message' => 'Count corrected.', 'summary' => stock_summary(
            array_merge($asset, ['quantity_total' => $newTotal])
        )]);
        exit;
    } catch (Exception $e) {
        $mysqli->rollback();
        fail(422, $e->getMessage());
    }
}

fail(405, 'Method not allowed');
