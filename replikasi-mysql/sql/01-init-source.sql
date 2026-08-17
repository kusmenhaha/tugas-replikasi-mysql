CREATE DATABASE IF NOT EXISTS toko_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE toko_db;

CREATE TABLE IF NOT EXISTS produk (
  id_produk BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  nama_produk VARCHAR(100) NOT NULL,
  harga DECIMAL(12,2) NOT NULL,
  stok INT UNSIGNED NOT NULL DEFAULT 0,
  dibuat_pada TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_produk)
) ENGINE=InnoDB;

INSERT INTO produk (nama_produk, harga, stok) VALUES
  ('Keyboard Mekanik', 750000.00, 12),
  ('Mouse Nirkabel', 250000.00, 25),
  ('Monitor 24 Inci', 1850000.00, 8);
