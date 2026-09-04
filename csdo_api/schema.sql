-- Schema for the QR-Assisted Asset Manager backend.
-- Import this in phpMyAdmin (on the database you point db.php at) so the
-- column names line up exactly with what csdo_api/*.php reads and writes.
-- Safe to re-run: every statement is IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS user (
  id INT AUTO_INCREMENT PRIMARY KEY,
  employee_id VARCHAR(50) NOT NULL UNIQUE,
  full_name VARCHAR(150) NOT NULL,
  email VARCHAR(150) NOT NULL,
  department VARCHAR(150) NOT NULL,
  password VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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

-- No seed rows here on purpose: the app itself seeds the four built-in
-- categories (IT equipment, Furniture, Vehicles, Tools) into this table
-- the first time it runs against an empty `categories` table — see
-- AppShell._loadInitialData in lib/main.dart. That way their icon/color
-- values always match Flutter's IconData/Color encoding exactly instead
-- of a hand-typed guess here.
