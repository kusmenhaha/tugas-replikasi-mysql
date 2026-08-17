USE toko_db;

INSERT INTO produk (nama_produk, harga, stok)
VALUES ('Webcam Full HD', 425000.00, 15);

UPDATE produk
SET stok = stok - 1
WHERE nama_produk = 'Keyboard Mekanik';

DELETE FROM produk
WHERE nama_produk = 'Mouse Nirkabel';

SELECT * FROM produk ORDER BY id_produk;
