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
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_assets_category FOREIGN KEY (category_id) REFERENCES categories(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS requests (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(200) NOT NULL,
  requester VARCHAR(150) NOT NULL,
  department VARCHAR(150) NOT NULL,
  venue VARCHAR(150) NULL,
  borrow_date VARCHAR(50) NOT NULL,
  return_date VARCHAR(50) NOT NULL,
  -- One of: 'pending', 'approved', 'rejected', 'returned'. 'returned' is a
  -- terminal state for an approved request whose assets have been brought
  -- back (they're freed to 'available', but the request_assets link rows
  -- are kept as a record of what was lent). Plain VARCHAR, no ENUM/CHECK.
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  requester_signature VARCHAR(150),
  adviser_signature VARCHAR(150),
  principal_signature VARCHAR(150),
  dean_signature VARCHAR(150),
  request_form_image LONGTEXT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS request_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  request_id INT NOT NULL,
  item_type VARCHAR(20) NOT NULL,
  name VARCHAR(150) NOT NULL,
  quantity INT NOT NULL DEFAULT 1,
  CONSTRAINT fk_request_items_request FOREIGN KEY (request_id) REFERENCES requests(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_request_assets_request FOREIGN KEY (request_id) REFERENCES requests(id) ON DELETE CASCADE,
  CONSTRAINT fk_request_assets_asset FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE,
  UNIQUE KEY uq_request_asset (request_id, asset_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Per-asset timeline / audit log. One row per notable thing that happened
-- to an asset: 'added', a flow-driven status move ('available' from "Move
-- to active", 'maintenance' / 'in_stock' from "Move to stock"), or a
-- request-driven change ('borrowed', 'returned', 'released' when a loan is
-- cancelled). `detail` carries context such as the
-- request title; `request_id` is informational only (no FK, so the line
-- survives the request being deleted). Written by log_asset_event() in
-- db.php. Safe to re-run.
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
-- 5-year lifespan warning. Safe to re-run.
CREATE TABLE IF NOT EXISTS asset_returns (
  id INT AUTO_INCREMENT PRIMARY KEY,
  request_id INT NULL,
  request_title VARCHAR(200) NULL,
  borrow_date VARCHAR(50) NULL,
  return_date VARCHAR(50) NULL,
  days_used INT NULL,
  asset_condition VARCHAR(20) NOT NULL DEFAULT 'good',  -- good | fair | poor | damaged
  notes VARCHAR(500) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_asset_returns_request (request_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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

-- No seed rows here on purpose: the app itself seeds the four built-in
-- categories (IT equipment, Furniture, Vehicles, Tools) into this table
-- the first time it runs against an empty `categories` table — see
-- AppShell._loadInitialData in lib/main.dart. That way their icon/color
-- values always match Flutter's IconData/Color encoding exactly instead
-- of a hand-typed guess here.
