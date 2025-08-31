CREATE DATABASE inventory_db;
USE inventory_db;

CREATE TABLE suppliers (
  supplier_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  contact_name VARCHAR(120),
  phone VARCHAR(30),
  email VARCHAR(120),
  address VARCHAR(255),
  city VARCHAR(80),
  state VARCHAR(80),
  country VARCHAR(80),
  postal_code VARCHAR(20),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE products (
  product_id INT AUTO_INCREMENT PRIMARY KEY,
  sku VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(150) NOT NULL,
  description TEXT,
  unit VARCHAR(20) NOT NULL DEFAULT 'pcs',
  supplier_id INT,
  default_reorder_level INT NOT NULL DEFAULT 10,
  is_active TINYINT NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
);


CREATE TABLE warehouses (
  warehouse_id INT AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(20) NOT NULL UNIQUE,
  name VARCHAR(150) NOT NULL,
  location VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE stock (
  warehouse_id INT NOT NULL,
  product_id INT NOT NULL,
  qty_on_hand INT NOT NULL DEFAULT 0,
  reorder_point INT NULL,
  safety_stock INT NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (warehouse_id, product_id),
  FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id),
  FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE stock_movements (
  movement_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  product_id INT NOT NULL,
  warehouse_id INT NOT NULL,
  qty INT NOT NULL,
  movement_type ENUM('IN','OUT','TRANSFER_IN','TRANSFER_OUT','ADJUSTMENT') NOT NULL,
  ref TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (product_id) REFERENCES products(product_id),
  FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id)
);


CREATE TABLE low_stock_alerts (
  alert_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_id INT NOT NULL,
  warehouse_id INT NOT NULL,
  qty_on_hand INT NOT NULL,
  threshold INT NOT NULL,
  is_open TINYINT NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  resolved_at TIMESTAMP NULL,
  FOREIGN KEY (product_id) REFERENCES products(product_id),
  FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id),
  UNIQUE KEY uni_open (product_id, warehouse_id, is_open)
);


