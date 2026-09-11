<?php
require __DIR__ . '/db.php';

$method = $_SERVER['REQUEST_METHOD'];

/**
 * Tag prefix for a category: "CSDO-" + the first two letters of the category
 * name (uppercased, letters only, padded with X if it has fewer than two) +
 * the category's row id + "-". The id keeps the prefix unique even when two
 * categories start with the same two letters ("Tools" / "Toys" -> TO4 / TO7).
 * e.g. "IT Equipment" (id 1) -> "CSDO-IT1-", "Furniture" (id 2) -> "CSDO-FU2-".
 * Returns null when no category has that id.
 */
function tag_prefix_for_category(mysqli $mysqli, int $categoryId): ?string {
    $stmt = $mysqli->prepare('SELECT value FROM categories WHERE id = ?');
    $stmt->bind_param('i', $categoryId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$row) return null;
    $letters = strtoupper(preg_replace('/[^A-Za-z]/', '', (string) $row['value']));
    return 'CSDO-' . substr($letters . 'XX', 0, 2) . $categoryId . '-';
}

/**
 * Next unused tag ID for $prefix: the highest running number already stored
 * under that prefix, plus one, zero-padded to at least four digits (it grows
 * past four once a prefix passes 9999). This is a best guess, not a hard
 * guarantee — two POSTs racing each other can read the same MAX — so the
 * caller inserts in a retry loop and asks again on a duplicate-key error.
 */
function next_tag_id(mysqli $mysqli, string $prefix): string {
    $pos = strlen($prefix) + 1; // SUBSTRING() is 1-indexed; $pos is derived
    $like = $prefix . '%';       // from strlen so it's safe to inline
    $stmt = $mysqli->prepare(
        'SELECT MAX(CAST(SUBSTRING(tag_id, ' . $pos . ') AS UNSIGNED)) AS max_num ' .
        'FROM assets WHERE tag_id LIKE ?'
    );
    $stmt->bind_param('s', $like);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    $next = ($row && $row['max_num'] !== null) ? ((int) $row['max_num'] + 1) : 1;
    return $prefix . str_pad((string) $next, 4, '0', STR_PAD_LEFT);
}

if ($method === 'GET') {
    // The current-holder columns are derived, not stored. Each is a single
    // correlated subquery over the request that currently has this asset
    // physically handed out ('checked_out'). A merely reserved ('approved')
    // request doesn't hold the asset yet, so it isn't a current holder.
    // ORDER BY r.id DESC LIMIT 1 keeps it safe if more than one ever matches.
    $holderCol = fn(string $col) =>
        "(SELECT r.$col FROM request_assets ra2 JOIN requests r ON r.id = ra2.request_id " .
        "  WHERE ra2.asset_id = a.id AND r.status = 'checked_out' ORDER BY r.id DESC LIMIT 1)";
    $result = $mysqli->query(
        'SELECT a.id, a.tag_id, a.name, a.category_id, c.value AS category_value, ' .
        'c.default_tracking AS category_default_tracking, ' .
        'c.lifespan_years AS category_lifespan_years, ' .
        'a.description, a.status, a.purchase_date, a.image_base64, ' .
        'a.tracking, a.quantity_total, a.quantity_out, a.quantity_damaged, ' .
        'a.reorder_point, a.home_location, a.custodian, ' .
        'a.last_location, a.last_scanned_at, ' .
        '(SELECT r.asset_condition FROM asset_returns r ' .
        '   JOIN asset_return_assets ra ON ra.return_id = r.id ' .
        '  WHERE ra.asset_id = a.id ORDER BY r.id DESC LIMIT 1) AS last_condition, ' .
        $holderCol('requester') . ' AS current_holder, ' .
        $holderCol('department') . ' AS current_holder_department, ' .
        $holderCol('return_date') . ' AS due_back, ' .
        // Days this asset's active loan is overdue (0 / null = not overdue).
        '(SELECT GREATEST(0, DATEDIFF(CURDATE(), r.return_on)) ' .
        '   FROM request_assets ra2 JOIN requests r ON r.id = ra2.request_id ' .
        "  WHERE ra2.asset_id = a.id AND r.status = 'checked_out' AND r.return_on IS NOT NULL " .
        '  ORDER BY r.id DESC LIMIT 1) AS overdue_days ' .
        'FROM assets a JOIN categories c ON c.id = a.category_id ' .
        'ORDER BY a.id DESC'
    );
    $rows = [];
    while ($row = $result->fetch_assoc()) {
        $row['id'] = (int) $row['id'];
        $row['category_id'] = (int) $row['category_id'];
        $row['category_lifespan_years'] = $row['category_lifespan_years'] === null
            ? null : (int) $row['category_lifespan_years'];
        $row['tracking'] = $row['tracking'] ?: 'individual';
        $row['quantity_total'] = $row['quantity_total'] === null ? null : (int) $row['quantity_total'];
        $row['quantity_out'] = (int) $row['quantity_out'];
        $row['quantity_damaged'] = (int) $row['quantity_damaged'];
        $row['reorder_point'] = $row['reorder_point'] === null ? null : (int) $row['reorder_point'];
        $row['overdue_days'] = $row['overdue_days'] === null ? 0 : (int) $row['overdue_days'];
        $rows[] = $row;
    }
    echo json_encode($rows);
    exit;
}

if ($method === 'POST') {
    $body = read_json_body();
    // tag_id is NOT read from the request — it's allocated below, server-side,
    // so the running number can't collide across devices and the prefix
    // always reflects the real category. Any client-sent tag_id is ignored.
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
    // The acting admin's name, for the timeline / stock ledger — see
    // log_asset_event()'s doc comment in db.php. Null when the client
    // didn't send one.
    $performedBy = trim((string) ($body['performed_by'] ?? '')) ?: null;
    $quantityTotal = $isBulk ? max(0, (int) ($body['quantity_total'] ?? 0)) : null;
    $reorderPoint = isset($body['reorder_point']) && is_numeric($body['reorder_point'])
        ? max(0, (int) $body['reorder_point'])
        : null;
    // A bulk pool is never "in stock" / "in use" as a whole — it carries a
    // level instead. Keep its status column at 'available' as a placeholder.
    if ($isBulk) $status = 'available';

    if ($name === '' || $categoryId === null || $purchaseDate === '') {
        fail(400, 'name, category_id, and purchase_date are required.');
    }
    $categoryId = (int) $categoryId;

    $prefix = tag_prefix_for_category($mysqli, $categoryId);
    if ($prefix === null) fail(400, 'Unknown category_id.');

    $stmt = $mysqli->prepare(
        'INSERT INTO assets (tag_id, name, category_id, description, status, purchase_date, image_base64, ' .
        'tracking, quantity_total, quantity_out, reorder_point) ' .
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)'
    );

    // Allocate the tag ID and insert in one loop: if another POST grabbed the
    // same number first, the UNIQUE index on tag_id rejects us with errno
    // 1062 and we ask next_tag_id() again (it now sees the winning row).
    $tagId = null;
    $inserted = false;
    for ($attempt = 0; $attempt < 6; $attempt++) {
        $tagId = next_tag_id($mysqli, $prefix);
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
        if ($stmt->execute()) {
            $inserted = true;
            break;
        }
        if ($stmt->errno !== 1062) break; // a real failure, not a tag-id race
    }
    if (!$inserted) {
        $err = $stmt->error;
        $stmt->close();
        fail(500, 'Failed to add asset: ' . $err);
    }
    $newId = $stmt->insert_id;
    $stmt->close();

    if ($isBulk) {
        log_asset_event($mysqli, (int) $newId, 'added', 'Added as a bulk item', null, $performedBy);
        if ($quantityTotal > 0) {
            log_stock_movement(
                $mysqli,
                (int) $newId,
                'adjusted',
                $quantityTotal,
                $quantityTotal,
                'Opening stock',
                null,
                $performedBy
            );
        }
    } else {
        log_asset_event(
            $mysqli,
            (int) $newId,
            'added',
            $status === 'backup' ? 'Added as a backup item' : 'Added to active inventory',
            null,
            $performedBy
        );
    }

    http_response_code(201);
    echo json_encode(['id' => $newId, 'tag_id' => $tagId]);
    exit;
}

if ($method === 'PUT') {
    $body = read_json_body();
    $tagId = trim($body['tag_id'] ?? '');
    if ($tagId === '') fail(400, 'tag_id is required.');
    // action decides what this PUT does:
    //   'edit'     -> change the asset's details (name, category, ...)
    //   'sighting' -> record that an admin just scanned it and where
    //   '' (default, or 'status') -> the original flow-driven status move
    $action = trim($body['action'] ?? '');

    // ---- Edit the asset's details -----------------------------------------
    if ($action === 'edit') {
        $cur = $mysqli->prepare(
            'SELECT id, name, category_id, description, purchase_date, tracking, ' .
            'reorder_point, home_location, custodian FROM assets WHERE tag_id = ?'
        );
        $cur->bind_param('s', $tagId);
        $cur->execute();
        $assetRow = $cur->get_result()->fetch_assoc();
        $cur->close();
        if (!$assetRow) fail(404, 'No asset with that tag_id.');

        $name = trim($body['name'] ?? '');
        $categoryId = (int) ($body['category_id'] ?? 0);
        $description = (string) ($body['description'] ?? '');
        $purchaseDate = trim($body['purchase_date'] ?? '');
        $homeLocation = trim((string) ($body['home_location'] ?? '')) ?: null;
        $custodian = trim((string) ($body['custodian'] ?? '')) ?: null;
        // image_base64: only touched when the key is present, so an edit that
        // doesn't re-send the photo keeps the existing one.
        $touchImage = array_key_exists('image_base64', $body);
        $imageBase64 = $body['image_base64'] ?? null;
        $isBulk = ($assetRow['tracking'] ?? 'individual') === 'bulk';
        $reorderPoint = null;
        $touchReorder = $isBulk && array_key_exists('reorder_point', $body);
        if ($touchReorder) {
            $reorderPoint = is_numeric($body['reorder_point'])
                ? max(0, (int) $body['reorder_point']) : null;
        }

        if ($name === '' || $categoryId === 0 || $purchaseDate === '') {
            fail(400, 'name, category_id and purchase_date are required.');
        }
        if (tag_prefix_for_category($mysqli, $categoryId) === null) {
            fail(400, 'Unknown category_id.');
        }

        $sets = ['name = ?', 'category_id = ?', 'description = ?', 'purchase_date = ?',
                 'home_location = ?', 'custodian = ?'];
        $types = 'sisss' . 's';
        $vals = [$name, $categoryId, $description, $purchaseDate, $homeLocation, $custodian];
        if ($touchImage) { $sets[] = 'image_base64 = ?'; $types .= 's'; $vals[] = $imageBase64; }
        if ($touchReorder) { $sets[] = 'reorder_point = ?'; $types .= 'i'; $vals[] = $reorderPoint; }
        $types .= 's';
        $vals[] = $tagId;

        $stmt = $mysqli->prepare('UPDATE assets SET ' . implode(', ', $sets) . ' WHERE tag_id = ?');
        $stmt->bind_param($types, ...$vals);
        if (!$stmt->execute()) {
            $stmt->close();
            fail(500, 'Failed to update asset: ' . $mysqli->error);
        }
        $stmt->close();

        // Timeline note listing what changed, so an edit is auditable.
        $changed = [];
        if ($name !== $assetRow['name']) $changed[] = 'name';
        if ($categoryId !== (int) $assetRow['category_id']) $changed[] = 'category';
        if ($description !== (string) $assetRow['description']) $changed[] = 'description';
        if ($purchaseDate !== (string) $assetRow['purchase_date']) $changed[] = 'purchase date';
        if ($homeLocation !== ($assetRow['home_location'] ?? null)) $changed[] = 'home location';
        if ($custodian !== ($assetRow['custodian'] ?? null)) $changed[] = 'person responsible';
        if ($touchImage) $changed[] = 'photo';
        if ($touchReorder && $reorderPoint !== ($assetRow['reorder_point'] === null ? null : (int) $assetRow['reorder_point'])) {
            $changed[] = 'reorder point';
        }
        $detail = $changed ? ('Changed ' . implode(', ', $changed)) : 'Edited (no changes)';
        $performedBy = trim((string) ($body['performed_by'] ?? '')) ?: null;
        log_asset_event($mysqli, (int) $assetRow['id'], 'edited', $detail, null, $performedBy);

        echo json_encode(['message' => 'Asset updated.']);
        exit;
    }

    // ---- Record a sighting (an admin scanned it) -------------------------
    if ($action === 'sighting') {
        $cur = $mysqli->prepare('SELECT id FROM assets WHERE tag_id = ?');
        $cur->bind_param('s', $tagId);
        $cur->execute();
        $assetRow = $cur->get_result()->fetch_assoc();
        $cur->close();
        if (!$assetRow) fail(404, 'No asset with that tag_id.');

        $location = trim((string) ($body['location'] ?? ''));
        $now = date('Y-m-d H:i:s');
        // A blank location still records "seen just now" — keep whatever
        // location was last known rather than wiping it.
        if ($location !== '') {
            $stmt = $mysqli->prepare(
                'UPDATE assets SET last_location = ?, last_scanned_at = ? WHERE tag_id = ?'
            );
            $stmt->bind_param('sss', $location, $now, $tagId);
        } else {
            $stmt = $mysqli->prepare(
                'UPDATE assets SET last_scanned_at = ? WHERE tag_id = ?'
            );
            $stmt->bind_param('ss', $now, $tagId);
        }
        if (!$stmt->execute()) {
            $stmt->close();
            fail(500, 'Failed to record the sighting: ' . $mysqli->error);
        }
        $stmt->close();

        $performedBy = trim((string) ($body['performed_by'] ?? '')) ?: null;
        log_asset_event(
            $mysqli,
            (int) $assetRow['id'],
            'scanned',
            $location !== '' ? ('Seen at ' . $location) : 'Scanned — location not recorded',
            null,
            $performedBy
        );

        echo json_encode([
            'message' => 'Sighting recorded.',
            'last_scanned_at' => $now,
            'last_location' => $location !== '' ? $location : null,
        ]);
        exit;
    }

    // ---- Flow-driven status move (the original behaviour) ---------------
    $status = trim($body['status'] ?? '');
    // Optional context for the timeline — e.g. why an asset was moved to
    // stock ("Worn out", "Obsolete", ...).
    $reason = trim($body['reason'] ?? '');
    if ($status === '') fail(400, 'status is required.');

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
    // status moves that aren't borrowing: 'backup' / 'maintenance' (from
    // "Move to backup") and 'available' (from "Move to active"). 'in_use' is
    // driven through requests.php instead. The reason, when given, becomes
    // the timeline line's detail.
    $performedBy = trim((string) ($body['performed_by'] ?? '')) ?: null;
    log_asset_event(
        $mysqli, (int) $assetRow['id'], $status, $reason !== '' ? $reason : null, null, $performedBy
    );

    echo json_encode(['message' => 'Asset updated.']);
    exit;
}

if ($method === 'DELETE') {
    $tagId = trim($_GET['tag_id'] ?? '');
    $reason = trim($_GET['reason'] ?? '');
    // The acting admin's name for the asset_removals audit log — sent as a
    // query param like tag_id/reason, since DELETE carries no JSON body
    // here. Null when the client didn't send one.
    $removedBy = trim((string) ($_GET['removed_by'] ?? '')) ?: null;
    if ($tagId === '') fail(400, 'tag_id query parameter is required.');
    if ($reason === '') fail(400, 'A reason for removal is required.');

    // An individual asset can only be permanently deleted once it's been
    // moved off the active inventory (status 'backup' or 'maintenance').
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
    } elseif (!in_array($row['status'], ['backup', 'maintenance'], true)) {
        fail(409, 'Only backup items can be permanently deleted. Move the asset to backup first.');
    }

    $mysqli->begin_transaction();
    try {
        $log = $mysqli->prepare(
            'INSERT INTO asset_removals (tag_id, name, category, reason, removed_by_name) ' .
            'VALUES (?, ?, ?, ?, ?)'
        );
        $log->bind_param(
            'sssss', $row['tag_id'], $row['name'], $row['category'], $reason, $removedBy
        );
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
