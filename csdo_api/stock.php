<?php
require __DIR__ . '/db.php';

// Stock management for BULK assets.
//
//   GET  /stock.php?tag_id=CSDO-...   -> { summary, movements[], purchases[] }
//   POST /stock.php   body { tag_id, action, ... }
//     action = 'purchase'   : { quantity, supplier?, note?, purchased_at? }
//                             -> adds to quantity_total, records the purchase.
//                             Only reached from the Add Asset screen's
//                             "restock an existing bulk item" path now — the
//                             asset detail screen no longer offers this
//                             directly (creating an asset there already lets
//                             the admin pick an existing pool to top up).
//     action = 'backup'     : { quantity, reason }
//                             -> moves units from available into
//                                quantity_backup. Doesn't touch
//                                quantity_total. The only bulk-stock action
//                                still on the asset detail screen.
//     action = 'reactivate' : { quantity, reason }
//                             -> moves units from quantity_backup back into
//                                available. Only reachable from the Backup
//                                Items screen.
//     action = 'dispose'    : { quantity, reason }
//                             -> permanently removes units from
//                                quantity_total AND quantity_backup, logs to
//                                bulk_disposals. Can only draw from
//                                quantity_backup — units must be moved to
//                                backup first. Only reachable from the
//                                Backup Items screen.
//     action = 'restore'    : { quantity, note? }
//                             -> moves units from quantity_damaged (loan
//                                returned damaged) back into available.
//                                Unrelated to the backup bucket above.
//     action = 'adjust'     : { new_total, reason }
//                             -> sets quantity_total to a corrected count.

$method = $_SERVER['REQUEST_METHOD'];

/** Loads the bulk asset row by tag_id, or fails 404 / 409 if not usable. */
function load_bulk_asset(mysqli $mysqli, string $tagId): array {
    $stmt = $mysqli->prepare(
        'SELECT a.id, a.tag_id, a.name, a.tracking, a.quantity_total, a.quantity_out, ' .
        'a.quantity_damaged, a.quantity_backup, a.reorder_point, c.value AS category ' .
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
    $row['quantity_backup'] = (int) $row['quantity_backup'];
    $row['reorder_point'] = $row['reorder_point'] === null ? null : (int) $row['reorder_point'];
    return $row;
}

/**
 * Builds the stock summary. `available` is what can be lent right now:
 * owned, minus what's on loan, minus what's set aside damaged, minus what's
 * set aside as backup.
 */
function stock_summary(array $asset): array {
    $damaged = $asset['quantity_damaged'] ?? 0;
    $backup = $asset['quantity_backup'] ?? 0;
    $available = $asset['quantity_total'] - $asset['quantity_out'] - $damaged - $backup;
    $reorder = $asset['reorder_point'];
    return [
        'total' => $asset['quantity_total'],
        'out' => $asset['quantity_out'],
        'damaged' => $damaged,
        'backup' => $backup,
        'available' => $available,
        'reorder_point' => $reorder,
        'low_stock' => $reorder !== null && $available <= $reorder,
    ];
}

if ($method === 'GET') {
    $tagId = trim($_GET['tag_id'] ?? '');
    if ($tagId === '') fail(400, 'tag_id query parameter is required.');
    $asset = load_bulk_asset($mysqli, $tagId);

    $movements = [];
    $stmt = $mysqli->prepare(
        'SELECT id, kind, quantity_delta, balance_after, note, request_id, performed_by, created_at ' .
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
            'performed_by' => $r['performed_by'],
            'created_at' => $r['created_at'],
        ];
    }
    $stmt->close();

    $purchases = [];
    $stmt = $mysqli->prepare(
        'SELECT id, quantity, supplier, note, purchased_at, performed_by, created_at ' .
        'FROM stock_purchases WHERE asset_id = ? ORDER BY id DESC'
    );
    $stmt->bind_param('i', $asset['id']);
    $stmt->execute();
    $res = $stmt->get_result();
    while ($r = $res->fetch_assoc()) {
        $purchases[] = [
            'id' => (int) $r['id'],
            'quantity' => (int) $r['quantity'],
            'supplier' => $r['supplier'],
            'note' => $r['note'],
            'purchased_at' => $r['purchased_at'],
            'performed_by' => $r['performed_by'],
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
    if (!in_array($action, ['purchase', 'backup', 'reactivate', 'dispose', 'restore', 'adjust'], true)) {
        fail(400, "action must be 'purchase', 'backup', 'reactivate', 'dispose', 'restore' or 'adjust'.");
    }

    $asset = load_bulk_asset($mysqli, $tagId);
    // The acting admin's name, for the stock ledger / purchase and
    // disposal logs — see log_stock_movement()'s doc comment in db.php.
    // Null when the client didn't send one.
    $performedBy = trim((string) ($body['performed_by'] ?? '')) ?: null;

    $mysqli->begin_transaction();
    try {
        if ($action === 'purchase') {
            $quantity = (int) ($body['quantity'] ?? 0);
            if ($quantity <= 0) throw new Exception('Enter how many units were bought.');
            $supplier = trim((string) ($body['supplier'] ?? '')) ?: null;
            $note = trim((string) ($body['note'] ?? '')) ?: null;
            $purchasedAt = trim((string) ($body['purchased_at'] ?? '')) ?: null;

            $newTotal = $asset['quantity_total'] + $quantity;
            $upd = $mysqli->prepare('UPDATE assets SET quantity_total = ? WHERE id = ?');
            $upd->bind_param('ii', $newTotal, $asset['id']);
            $upd->execute();
            $upd->close();

            $ins = $mysqli->prepare(
                'INSERT INTO stock_purchases ' .
                '(asset_id, quantity, supplier, note, purchased_at, performed_by) ' .
                'VALUES (?, ?, ?, ?, ?, ?)'
            );
            $ins->bind_param(
                'iissss', $asset['id'], $quantity, $supplier, $note, $purchasedAt, $performedBy
            );
            $ins->execute();
            $ins->close();

            $movementNote = $supplier !== null ? "From $supplier" : $note;
            log_stock_movement(
                $mysqli, $asset['id'], 'purchase', $quantity, $newTotal, $movementNote, null, $performedBy
            );

            $mysqli->commit();
            echo json_encode(['message' => 'Stock added.', 'summary' => stock_summary(
                array_merge($asset, ['quantity_total' => $newTotal])
            )]);
            exit;
        }

        if ($action === 'backup') {
            // "Move to backup" — the bulk counterpart to an individual
            // asset's "Move to backup" flow. Draws only from what's
            // currently available (not damaged, not already backed up).
            // Doesn't touch quantity_total: this is a reclassification, not
            // a disposal.
            $quantity = (int) ($body['quantity'] ?? 0);
            $reason = trim((string) ($body['reason'] ?? ''));
            if ($quantity <= 0) throw new Exception('Enter how many units to move to backup.');
            if ($reason === '') throw new Exception('A reason is required.');
            $available = $asset['quantity_total'] - $asset['quantity_out']
                - $asset['quantity_damaged'] - $asset['quantity_backup'];
            if ($quantity > $available) {
                throw new Exception("Only $available unit(s) are available to move to backup.");
            }
            $newBackup = $asset['quantity_backup'] + $quantity;

            $upd = $mysqli->prepare('UPDATE assets SET quantity_backup = ? WHERE id = ?');
            $upd->bind_param('ii', $newBackup, $asset['id']);
            $upd->execute();
            $upd->close();

            log_stock_movement(
                $mysqli, $asset['id'], 'backup', $quantity, null, $reason, null, $performedBy
            );

            $mysqli->commit();
            echo json_encode(['message' => 'Moved to backup.', 'summary' => stock_summary(
                array_merge($asset, ['quantity_backup' => $newBackup])
            )]);
            exit;
        }

        if ($action === 'reactivate') {
            // "Move to active" for backed-up units — only reachable from the
            // Backup Items screen. The individual-asset equivalent
            // (promptAssetActivation) also requires a reason, so this does
            // too, for the same "why is it going back into service" record.
            $quantity = (int) ($body['quantity'] ?? 0);
            $reason = trim((string) ($body['reason'] ?? ''));
            if ($quantity <= 0) throw new Exception('Enter how many units to move back to active.');
            if ($reason === '') throw new Exception('A reason is required.');
            if ($quantity > $asset['quantity_backup']) {
                throw new Exception("Only {$asset['quantity_backup']} unit(s) are set aside as backup.");
            }
            $newBackup = $asset['quantity_backup'] - $quantity;

            $upd = $mysqli->prepare('UPDATE assets SET quantity_backup = ? WHERE id = ?');
            $upd->bind_param('ii', $newBackup, $asset['id']);
            $upd->execute();
            $upd->close();

            log_stock_movement(
                $mysqli, $asset['id'], 'reactivated', $quantity, null, $reason, null, $performedBy
            );

            $mysqli->commit();
            echo json_encode(['message' => 'Moved back to active.', 'summary' => stock_summary(
                array_merge($asset, ['quantity_backup' => $newBackup])
            )]);
            exit;
        }

        if ($action === 'dispose') {
            // Permanent — only reachable from the Backup Items screen, and
            // only ever draws from quantity_backup. Units must be moved to
            // backup first (action 'backup') before they can be disposed;
            // this no longer touches available or damaged stock directly.
            $quantity = (int) ($body['quantity'] ?? 0);
            $reason = trim((string) ($body['reason'] ?? ''));
            if ($quantity <= 0) throw new Exception('Enter how many units to dispose of.');
            if ($reason === '') throw new Exception('A reason for the disposal is required.');
            $disposable = $asset['quantity_backup'];
            if ($quantity > $disposable) {
                throw new Exception("Only $disposable unit(s) in backup can be disposed of.");
            }
            $newBackup = $asset['quantity_backup'] - $quantity;
            $newTotal = $asset['quantity_total'] - $quantity;

            $upd = $mysqli->prepare(
                'UPDATE assets SET quantity_total = ?, quantity_backup = ? WHERE id = ?'
            );
            $upd->bind_param('iii', $newTotal, $newBackup, $asset['id']);
            $upd->execute();
            $upd->close();

            $ins = $mysqli->prepare(
                'INSERT INTO bulk_disposals (tag_id, name, category, quantity, reason, disposed_by_name) ' .
                'VALUES (?, ?, ?, ?, ?, ?)'
            );
            $ins->bind_param(
                'sssiss', $asset['tag_id'], $asset['name'], $asset['category'], $quantity, $reason, $performedBy
            );
            $ins->execute();
            $ins->close();

            log_stock_movement(
                $mysqli, $asset['id'], 'disposed', -$quantity, $newTotal, $reason, null, $performedBy
            );

            $mysqli->commit();
            echo json_encode(['message' => 'Stock disposed.', 'summary' => stock_summary(
                array_merge($asset, ['quantity_total' => $newTotal, 'quantity_backup' => $newBackup])
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

            log_stock_movement($mysqli, $asset['id'], 'restored', $quantity, null, $note, null, $performedBy);

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
        $committed = $asset['quantity_out'] + $asset['quantity_damaged'] + $asset['quantity_backup'];
        if ($newTotal < $committed) {
            throw new Exception(
                "Can't set the total below the $committed unit(s) currently on loan, set aside "
                . 'damaged, or set aside as backup.'
            );
        }
        $delta = $newTotal - $asset['quantity_total'];
        $upd = $mysqli->prepare('UPDATE assets SET quantity_total = ? WHERE id = ?');
        $upd->bind_param('ii', $newTotal, $asset['id']);
        $upd->execute();
        $upd->close();

        log_stock_movement($mysqli, $asset['id'], 'adjusted', $delta, $newTotal, $reason, null, $performedBy);

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
