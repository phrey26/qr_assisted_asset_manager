-- Schema for the QR-Assisted Asset Manager backend.
-- Import this in phpMyAdmin (on the database you point db.php at) so the
-- column names line up exactly with what csdo_api/*.php reads and writes.
-- Safe to re-run: every statement is IF NOT EXISTS.

-- Every account in this project is an admin, hence the table name. If you
-- have an older database where this table is still called `user`, rename it
-- once (indexes move with it, nothing has a foreign key to it):
--   RENAME TABLE `user` TO `admin_user`;
CREATE TABLE IF NOT EXISTS admin_user (
  id INT AUTO_INCREMENT PRIMARY KEY,
  employee_id VARCHAR(50) NOT NULL UNIQUE,
  full_name VARCHAR(150) NOT NULL,
  email VARCHAR(150) NOT NULL,
  department VARCHAR(150) NOT NULL,
  password VARCHAR(255) NOT NULL,
  email_verified TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_user_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Upgrading a database created before email verification / email login:
-- these are MariaDB (XAMPP) syntax and are safe to re-run.
ALTER TABLE admin_user ADD COLUMN IF NOT EXISTS email_verified TINYINT(1) NOT NULL DEFAULT 0;
ALTER TABLE admin_user ADD UNIQUE INDEX IF NOT EXISTS uq_user_email (email);
-- If the ADD UNIQUE INDEX fails with "Duplicate entry", two accounts share an
-- email; fix those rows by hand, then re-run this line. To let existing
-- accounts keep signing in without re-verifying, run once:
--   UPDATE admin_user SET email_verified = 1;

-- Short-lived 6-digit codes for email verification and password reset.
CREATE TABLE IF NOT EXISTS auth_codes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(150) NOT NULL,
  code_hash VARCHAR(255) NOT NULL,
  purpose VARCHAR(20) NOT NULL,            -- 'verify' or 'reset'
  expires_at DATETIME NOT NULL,
  consumed_at DATETIME NULL,
  attempts INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_auth_codes_lookup (email, purpose, consumed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS categories (
  id INT AUTO_INCREMENT PRIMARY KEY,
  display_name VARCHAR(100) NOT NULL,
  value VARCHAR(100) NOT NULL UNIQUE,
  icon_code_point INT NOT NULL,
  color_value INT UNSIGNED NOT NULL,
  -- Suggested tracking mode for assets added under this category:
  -- 'individual' (serialised, QR-tagged units) or 'bulk' (quantity-tracked
  -- pools). Only a default for the Add Asset form — the binding flag is
  -- assets.tracking, so a category can hold a mix. See bulk_items.sql.
  default_tracking VARCHAR(12) NOT NULL DEFAULT 'individual',
  -- Expected service life, in whole years, for individual assets in this
  -- category. NULL means "don't track a lifespan" (e.g. documents): those
  -- assets are never flagged by age. A number N flags an asset once its
  -- purchase_date is more than N years ago. Read by isPastLifespan in
  -- lib/models/asset.dart via the join in assets.php (GET).
  lifespan_years INT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
ALTER TABLE categories ADD COLUMN IF NOT EXISTS default_tracking VARCHAR(12) NOT NULL DEFAULT 'individual';
ALTER TABLE categories ADD COLUMN IF NOT EXISTS lifespan_years INT NULL;
-- Upgrading a database seeded before per-category lifespans: give the
-- built-in "IT Equipment" category the 5-year value the app used to
-- hard-code, so its assets keep being flagged. Safe to re-run.
UPDATE categories SET lifespan_years = 5
  WHERE value = 'IT Equipment' AND lifespan_years IS NULL;

CREATE TABLE IF NOT EXISTS assets (
  id INT AUTO_INCREMENT PRIMARY KEY,
  tag_id VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(150) NOT NULL,
  category_id INT NOT NULL,
  description TEXT,
  -- One of: 'available', 'in_use', 'maintenance', 'in_stock'. Status is
  -- never hand-picked; it's driven by flows. 'available' <-> 'in_use' is
  -- the borrow/return cycle. 'in_stock' and 'maintenance' both mean the
  -- asset has been moved off the borrowable pool via "Move to stock"
  -- ('maintenance' when the admin flagged it as needing repair); the app
  -- lists both on a separate "Stock items" screen, and "Move to active"
  -- sends them back to 'available'. Plain VARCHAR (no ENUM/CHECK) so the
  -- app can evolve this set without a migration.
  status VARCHAR(20) NOT NULL DEFAULT 'available',
  purchase_date DATE NOT NULL,
  image_base64 LONGTEXT NULL,
  -- Bulk-item fields (see bulk_items.sql). 'individual' assets leave these
  -- at their defaults; 'bulk' assets are one row carrying a running count.
  tracking VARCHAR(12) NOT NULL DEFAULT 'individual',   -- 'individual' | 'bulk'
  quantity_total INT NULL,                              -- units owned (bulk)
  quantity_out INT NOT NULL DEFAULT 0,                  -- units on loan now (bulk)
  quantity_damaged INT NOT NULL DEFAULT 0,              -- units back from loan damaged, set aside pending repair/disposal (bulk)
  reorder_point INT NULL,                               -- low-stock threshold (bulk)
  -- Where the asset normally lives / who is responsible for it. Free text,
  -- both optional, editable from the asset's Edit form. This is the static
  -- "belongs to" — the dynamic "who has it on loan right now" is derived
  -- from the active approved request in assets.php (GET), not stored here.
  home_location VARCHAR(150) NULL,
  custodian VARCHAR(150) NULL,
  -- Set every time an admin scans the asset and records where they found
  -- it (see the 'sighting' action in assets.php PUT and the scan result
  -- screen). last_scanned_at with no location still counts as "seen here".
  last_location VARCHAR(150) NULL,
  last_scanned_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_assets_category FOREIGN KEY (category_id) REFERENCES categories(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
ALTER TABLE assets
  ADD COLUMN IF NOT EXISTS tracking         VARCHAR(12) NOT NULL DEFAULT 'individual',
  ADD COLUMN IF NOT EXISTS quantity_total   INT NULL,
  ADD COLUMN IF NOT EXISTS quantity_out     INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS quantity_damaged INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS reorder_point    INT NULL,
  ADD COLUMN IF NOT EXISTS home_location    VARCHAR(150) NULL,
  ADD COLUMN IF NOT EXISTS custodian        VARCHAR(150) NULL,
  ADD COLUMN IF NOT EXISTS last_location    VARCHAR(150) NULL,
  ADD COLUMN IF NOT EXISTS last_scanned_at  DATETIME NULL;
ALTER TABLE assets DROP COLUMN IF EXISTS unit_label;

CREATE TABLE IF NOT EXISTS requests (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(200) NOT NULL,
  requester VARCHAR(150) NOT NULL,
  department VARCHAR(150) NOT NULL,
  venue VARCHAR(150) NULL,
  -- Human-readable loan dates, exactly as the app formats them ("Sep 15,
  -- 2026"). Kept for display and backward compatibility; the machine-
  -- comparable copies live in borrow_on / return_on below.
  borrow_date VARCHAR(50) NOT NULL,
  return_date VARCHAR(50) NOT NULL,
  -- Machine-comparable loan window. Written on every create (and backfilled
  -- from the strings above for rows made before this column existed). These
  -- are what the availability / double-booking checks use — see
  -- csdo_api/availability.php and the 'approved' branch of requests.php.
  borrow_on DATE NULL,
  return_on DATE NULL,
  -- One of: 'pending', 'approved', 'checked_out', 'rejected', 'returned'.
  --   pending      – submitted, awaiting a decision
  --   approved     – assets RESERVED for the loan window; nothing physical
  --                  has moved (assets stay 'available', stock unchanged)
  --   checked_out  – the reserved assets have been physically handed over
  --                  (individual units -> 'in_use', bulk stock decremented)
  --   returned     – terminal; the borrowed assets came back and were freed,
  --                  but the request_assets rows are kept as a record
  --   rejected     – terminal; declined
  -- Plain VARCHAR, no ENUM/CHECK, so the set can grow without a migration.
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  requester_signature VARCHAR(150),
  adviser_signature VARCHAR(150),
  principal_signature VARCHAR(150),
  dean_signature VARCHAR(150),
  request_form_image LONGTEXT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
-- Upgrading a database created before the comparable loan window existed.
-- MariaDB (XAMPP) syntax; safe to re-run. The backfill parses the app's
-- own date format first ("Sep 15, 2026"), then a plain ISO date, and
-- leaves the column NULL for anything it can't read (those requests are
-- then treated as "always conflicting" by the checks — conservative).
ALTER TABLE requests ADD COLUMN IF NOT EXISTS borrow_on DATE NULL AFTER borrow_date;
ALTER TABLE requests ADD COLUMN IF NOT EXISTS return_on DATE NULL AFTER return_date;
UPDATE requests SET borrow_on = COALESCE(
  STR_TO_DATE(borrow_date, '%b %d, %Y'), STR_TO_DATE(borrow_date, '%Y-%m-%d')
) WHERE borrow_on IS NULL;
UPDATE requests SET return_on = COALESCE(
  STR_TO_DATE(return_date, '%b %d, %Y'), STR_TO_DATE(return_date, '%Y-%m-%d')
) WHERE return_on IS NULL;
-- Speeds up the overlap scan (status + date window) the checks run per approval.
ALTER TABLE requests ADD INDEX IF NOT EXISTS idx_requests_window (status, borrow_on, return_on);
-- Under the old model 'approved' meant the assets were already physically
-- out. The new model splits that into 'approved' (RESERVED — nothing has
-- moved) and 'checked_out' (handed over). Migrate an existing 'approved'
-- row to 'checked_out' only when one of its individual assets is actually
-- 'in_use' — the unambiguous "this was out under the old model" signal.
-- Safe to re-run: a genuinely-reserved request under the new model never
-- has an in_use asset, so it is left alone.
UPDATE requests r
  JOIN request_assets ra ON ra.request_id = r.id
  JOIN assets a ON a.id = ra.asset_id
  SET r.status = 'checked_out'
  WHERE r.status = 'approved' AND a.status = 'in_use';
-- The CSDO's own decision on the request: why it was declined (shown to the
-- requester and on the detail screen), and who recorded it / when. The
-- adviser → principal → dean routing that precedes it lives in
-- request_approvals. Safe to re-run.
ALTER TABLE requests
  ADD COLUMN IF NOT EXISTS rejection_reason VARCHAR(500) NULL,
  ADD COLUMN IF NOT EXISTS decided_by_name  VARCHAR(150) NULL,
  ADD COLUMN IF NOT EXISTS decided_at       DATETIME NULL;

-- The 4-step borrow-slip routing, recorded by the CSDO admin as the signed
-- paper form moves through adviser → principal/office head → dean. One row
-- per role per request (seq 1..3); the 4th step, the CSDO's own decision,
-- is the request's own status + rejection_reason above. The photo of the
-- signed form (requests.request_form_image) is the evidence each of these
-- rows is transcribed from. Safe to re-run.
CREATE TABLE IF NOT EXISTS request_approvals (
  id INT AUTO_INCREMENT PRIMARY KEY,
  request_id INT NOT NULL,
  role VARCHAR(16) NOT NULL,            -- 'adviser' | 'principal' | 'dean'
  seq TINYINT NOT NULL,                 -- routing order: 1, 2, 3
  status VARCHAR(12) NOT NULL DEFAULT 'pending',  -- pending | approved | rejected
  printed_name VARCHAR(150) NULL,       -- the name the signature is over (from the form)
  note VARCHAR(500) NULL,               -- a remark, or the reason when rejected
  decided_by_name VARCHAR(150) NULL,    -- the admin who recorded this step
  decided_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_request_role (request_id, role),
  CONSTRAINT fk_request_approvals_request FOREIGN KEY (request_id) REFERENCES requests(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Free-text notes / discussion on a request (clarifications, "waiting on
-- the dean's signature", "resubmit with the correct dates"). Newest first.
CREATE TABLE IF NOT EXISTS request_comments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  request_id INT NOT NULL,
  author_name VARCHAR(150) NOT NULL,
  body VARCHAR(1000) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_request_comments_request FOREIGN KEY (request_id) REFERENCES requests(id) ON DELETE CASCADE,
  INDEX idx_request_comments_request (request_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Seed the routing rows for every request that doesn't have them yet. New
-- requests get theirs from requests.php (POST). For requests that predate
-- step tracking: one already past CSDO approval (approved / checked_out /
-- returned) has all three marked approved, transcribed from the signed
-- form on file; a pending one starts all pending; a rejected one leaves
-- the three pending (the rejection lives on the request itself). Idempotent
-- via NOT EXISTS. Safe to re-run.
INSERT INTO request_approvals (request_id, role, seq, status, printed_name, note, decided_at)
SELECT r.id, x.role, x.seq,
       CASE WHEN r.status IN ('approved', 'checked_out', 'returned') THEN 'approved' ELSE 'pending' END,
       CASE x.role
         WHEN 'adviser'   THEN r.adviser_signature
         WHEN 'principal' THEN r.principal_signature
         WHEN 'dean'      THEN r.dean_signature
       END,
       CASE WHEN r.status IN ('approved', 'checked_out', 'returned')
            THEN 'Recorded from the signed form on file' END,
       CASE WHEN r.status IN ('approved', 'checked_out', 'returned') THEN r.created_at END
FROM requests r
JOIN (
  SELECT 'adviser' AS role, 1 AS seq
  UNION ALL SELECT 'principal', 2
  UNION ALL SELECT 'dean', 3
) x
WHERE NOT EXISTS (SELECT 1 FROM request_approvals ra WHERE ra.request_id = r.id);

CREATE TABLE IF NOT EXISTS request_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  request_id INT NOT NULL,
  item_type VARCHAR(20) NOT NULL,
  -- Optional soft link to the inventory category this line is asking for
  -- (e.g. the "Foldable chairs" line points at the "Furniture" category).
  -- Nullable and intentionally NOT a foreign key, so the requested line
  -- survives the category being renamed or removed. Lets the approval
  -- picker scope its suggestions instead of matching on the free-text name.
  category_id INT NULL,
  name VARCHAR(150) NOT NULL,
  quantity INT NOT NULL DEFAULT 1,
  CONSTRAINT fk_request_items_request FOREIGN KEY (request_id) REFERENCES requests(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
-- Upgrading a database created before request lines could reference a
-- category. Safe to re-run.
ALTER TABLE request_items ADD COLUMN IF NOT EXISTS category_id INT NULL AFTER item_type;
ALTER TABLE request_items ADD INDEX IF NOT EXISTS idx_request_items_category (category_id);

-- The actual assets handed out to fulfil an approved request. The app makes
-- the admin pick these before a request can be approved (see the asset
-- picker in lib/widgets/asset_assignment_sheet.dart). Rows are created on
-- approval and removed when the approval is cancelled, the request is
-- rejected, or the request is deleted; each linked asset is flipped to
-- 'in_use' while it's assigned and back to 'available' when it's freed.
-- Safe to re-run.
CREATE TABLE IF NOT EXISTS request_assets (
  id INT AUTO_INCREMENT PRIMARY KEY,
  request_id INT NOT NULL,
  asset_id INT NOT NULL,
  -- Units taken from the asset. 1 for an individual pick (one row = one
  -- physical unit); N for a bulk pool line. See bulk_items.sql.
  quantity INT NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_request_assets_request FOREIGN KEY (request_id) REFERENCES requests(id) ON DELETE CASCADE,
  CONSTRAINT fk_request_assets_asset FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE,
  UNIQUE KEY uq_request_asset (request_id, asset_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
ALTER TABLE request_assets ADD COLUMN IF NOT EXISTS quantity INT NOT NULL DEFAULT 1;

-- Per-asset timeline / audit log. One row per notable thing that happened
-- to an asset: 'added', a flow-driven status move ('available' from "Move
-- to active", 'maintenance' / 'in_stock' from "Move to stock"), a
-- request-driven change ('borrowed', 'returned', 'released' when a loan is
-- cancelled), an 'edited' (admin changed the asset's details), or a
-- 'scanned' (an admin scanned it and recorded where they found it —
-- `detail` is the location). `detail` carries context such as the request
-- title or the sighting location; `request_id` is informational only (no
-- FK, so the line survives the request being deleted). Written by
-- log_asset_event() in db.php. Safe to re-run.
CREATE TABLE IF NOT EXISTS asset_events (
  id INT AUTO_INCREMENT PRIMARY KEY,
  asset_id INT NOT NULL,
  event_type VARCHAR(30) NOT NULL,
  detail VARCHAR(255) NULL,
  request_id INT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_asset_events_asset FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE,
  INDEX idx_asset_events_asset (asset_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- A return inspection: recorded when an approved request is marked
-- 'returned'. Captures the assets' condition, optional notes, and how many
-- days they were out, plus (in the child tables) which assets it covers and
-- photos of them as returned. Feeds the "Condition & usage" card on the
-- asset detail screen so wear from actual use is visible, not just the
-- per-category lifespan warning. Safe to re-run.
CREATE TABLE IF NOT EXISTS asset_returns (
  id INT AUTO_INCREMENT PRIMARY KEY,
  request_id INT NULL,
  request_title VARCHAR(200) NULL,
  borrow_date VARCHAR(50) NULL,
  return_date VARCHAR(50) NULL,
  -- Machine-comparable copies of the loan window, snapshotted from the
  -- request at return time. `days_used` is the actual calendar days out
  -- (returned_at − borrow_on) and `days_late` is how many days past
  -- return_on the return happened (0 = on time). Both computed server-side
  -- from the DATE columns when available; NULL for a legacy return whose
  -- request had no comparable dates.
  borrow_on DATE NULL,
  return_on DATE NULL,
  days_used INT NULL,
  days_late INT NULL,
  asset_condition VARCHAR(20) NOT NULL DEFAULT 'good',  -- good | fair | poor | damaged
  notes VARCHAR(500) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_asset_returns_request (request_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
-- Upgrading a database created before returns tracked lateness. Safe to re-run.
ALTER TABLE asset_returns
  ADD COLUMN IF NOT EXISTS borrow_on DATE NULL AFTER return_date,
  ADD COLUMN IF NOT EXISTS return_on DATE NULL AFTER borrow_on,
  ADD COLUMN IF NOT EXISTS days_late INT NULL AFTER days_used;

CREATE TABLE IF NOT EXISTS asset_return_assets (
  return_id INT NOT NULL,
  asset_id INT NOT NULL,
  PRIMARY KEY (return_id, asset_id),
  CONSTRAINT fk_ara_return FOREIGN KEY (return_id) REFERENCES asset_returns(id) ON DELETE CASCADE,
  CONSTRAINT fk_ara_asset FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS asset_return_photos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  return_id INT NOT NULL,
  image_base64 LONGTEXT NOT NULL,
  CONSTRAINT fk_arp_return FOREIGN KEY (return_id) REFERENCES asset_returns(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Audit trail of assets permanently deleted from the system. Deliberately
-- has NO foreign key to `assets` — the whole point is that this row
-- outlives the asset it describes. An asset can only be deleted once it's a
-- stock item, and the admin must give a reason; both are captured here.
-- Safe to re-run.
CREATE TABLE IF NOT EXISTS asset_removals (
  id INT AUTO_INCREMENT PRIMARY KEY,
  tag_id VARCHAR(50) NOT NULL,
  name VARCHAR(150) NOT NULL,
  category VARCHAR(100) NULL,
  reason VARCHAR(500) NOT NULL,
  removed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Running ledger for a bulk asset — the "Timeline" equivalent for
-- quantity-tracked items. One row per movement. No FK to `assets` (audit
-- trail). See bulk_items.sql for the column meanings. Safe to re-run.
CREATE TABLE IF NOT EXISTS stock_movements (
  id INT AUTO_INCREMENT PRIMARY KEY,
  asset_id INT NOT NULL,
  kind VARCHAR(16) NOT NULL,          -- purchase|lent|returned|damaged|disposed|adjusted
  quantity_delta INT NOT NULL,
  balance_after INT NULL,
  note VARCHAR(500) NULL,
  request_id INT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_stock_movements_asset (asset_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Supplier / date detail for each "Add stock" on a bulk asset. This app
-- tracks physical assets only, not money, so no cost is recorded here.
CREATE TABLE IF NOT EXISTS stock_purchases (
  id INT AUTO_INCREMENT PRIMARY KEY,
  asset_id INT NOT NULL,
  quantity INT NOT NULL,
  supplier VARCHAR(150) NULL,
  note VARCHAR(500) NULL,
  purchased_at DATE NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_stock_purchases_asset (asset_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
-- Upgrading a database created while "Add stock" still asked for a price:
-- drop the now-unused cost columns. Safe to re-run.
ALTER TABLE stock_purchases DROP COLUMN IF EXISTS unit_cost;
ALTER TABLE stock_purchases DROP COLUMN IF EXISTS total_cost;

-- Permanent audit log of bulk stock disposed of — the bulk counterpart to
-- asset_removals. No FK to `assets` on purpose. Safe to re-run.
CREATE TABLE IF NOT EXISTS bulk_disposals (
  id INT AUTO_INCREMENT PRIMARY KEY,
  tag_id VARCHAR(50) NOT NULL,
  name VARCHAR(150) NOT NULL,
  category VARCHAR(100) NULL,
  quantity INT NOT NULL,
  reason VARCHAR(500) NOT NULL,
  disposed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- No seed rows here on purpose: the app itself seeds the four built-in
-- categories (IT equipment, Furniture, Vehicles, Tools) into this table
-- the first time it runs against an empty `categories` table — see
-- AppShell._loadInitialData in lib/main.dart. That way their icon/color
-- values always match Flutter's IconData/Color encoding exactly instead
-- of a hand-typed guess here.
