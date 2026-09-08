-- ============================================================================
--  Bulk items — paste this whole file into phpMyAdmin (SQL tab) once.
--  MariaDB (XAMPP) syntax; every statement is IF NOT EXISTS / re-runnable.
--  After running it, copy the changed csdo_api/*.php files into htdocs.
-- ============================================================================

-- A category can suggest, but not force, how its assets are tracked:
--   'individual' — each asset is a serialised, QR-tagged unit (default,
--                  unchanged behaviour).
--   'bulk'       — assets are quantity-tracked pools (cables, markers, ...).
-- It's only a default for the Add Asset form; the real flag lives per asset
-- (assets.tracking below), so a category can hold a mix.
ALTER TABLE categories
  ADD COLUMN IF NOT EXISTS default_tracking VARCHAR(12) NOT NULL DEFAULT 'individual';

-- Per-asset tracking mode + the bulk quantity fields (all NULL / 0 for a
-- normal individual asset, so existing rows keep working untouched).
ALTER TABLE assets
  ADD COLUMN IF NOT EXISTS tracking        VARCHAR(12) NOT NULL DEFAULT 'individual',
  ADD COLUMN IF NOT EXISTS quantity_total  INT NULL,          -- units owned (bulk only)
  ADD COLUMN IF NOT EXISTS quantity_out    INT NOT NULL DEFAULT 0, -- units on loan now
  ADD COLUMN IF NOT EXISTS quantity_damaged INT NOT NULL DEFAULT 0, -- units held aside, back from loan damaged, awaiting a decision (repair -> available, or dispose)
  ADD COLUMN IF NOT EXISTS reorder_point   INT NULL,          -- low-stock threshold
  ADD COLUMN IF NOT EXISTS unit_label      VARCHAR(24) NULL;   -- "pcs", "box", ...

-- How many units of a bulk pool a request line took. 1 for an individual
-- asset pick (one row = one physical unit), so the default keeps old rows valid.
ALTER TABLE request_assets
  ADD COLUMN IF NOT EXISTS quantity INT NOT NULL DEFAULT 1;

-- Running ledger for a bulk asset — one row per movement. This is the
-- "Timeline" for bulk items the way asset_events is for individual ones.
-- No FK to assets: like asset_events it's an audit trail.
--   kind: 'purchase' | 'lent' | 'returned' | 'damaged' | 'restored' | 'disposed' | 'adjusted'
--     'damaged'  = units came back from a loan damaged and were set aside
--                  (moved into quantity_damaged; total unchanged).
--     'restored' = damaged units repaired and returned to available stock.
--     'disposed' = units written off for good (also logged in bulk_disposals);
--                  total drops. Damaged units are only disposed when the
--                  admin chooses to — never automatically on return.
--   quantity_delta: signed. + adds to on-hand total (purchase/adjust up) or
--       is the size of a loan movement; - for disposals / downward adjust.
--   balance_after: quantity_total right after this row, when the row changed
--       the total (purchase / disposed / adjusted / damaged); NULL for plain
--       lent / returned movements that only shift units in and out on loan.
CREATE TABLE IF NOT EXISTS stock_movements (
  id INT AUTO_INCREMENT PRIMARY KEY,
  asset_id INT NOT NULL,
  kind VARCHAR(16) NOT NULL,
  quantity_delta INT NOT NULL,
  balance_after INT NULL,
  note VARCHAR(500) NULL,
  request_id INT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_stock_movements_asset (asset_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Procurement detail for each "Add stock" (buying) on a bulk asset. The
-- running total is kept on assets.quantity_total and mirrored into
-- stock_movements; this table just holds the cost / supplier paperwork.
CREATE TABLE IF NOT EXISTS stock_purchases (
  id INT AUTO_INCREMENT PRIMARY KEY,
  asset_id INT NOT NULL,
  quantity INT NOT NULL,
  unit_cost DECIMAL(12,2) NULL,
  total_cost DECIMAL(14,2) NULL,
  supplier VARCHAR(150) NULL,
  note VARCHAR(500) NULL,
  purchased_at DATE NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_stock_purchases_asset (asset_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Permanent audit log of bulk stock disposed of (broken / used up / lost /
-- obsolete), mirroring asset_removals for individual assets. Deliberately
-- has NO foreign key to `assets` so the record outlives the item.
CREATE TABLE IF NOT EXISTS bulk_disposals (
  id INT AUTO_INCREMENT PRIMARY KEY,
  tag_id VARCHAR(50) NOT NULL,
  name VARCHAR(150) NOT NULL,
  category VARCHAR(100) NULL,
  quantity INT NOT NULL,
  reason VARCHAR(500) NOT NULL,
  disposed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
