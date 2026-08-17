# Praktikum Replikasi Database MySQL 8.4

Proyek ini membuat replikasi asinkron satu arah dengan topologi **source -> replica**. Source menerima operasi tulis, lalu perubahan dikirim melalui binary log dan diterapkan pada replica menggunakan GTID auto-positioning.

## Isi proyek

- `compose.yaml`: dua server MySQL 8.4, jaringan internal, serta parameter binary log, GTID, server-id, dan read-only yang dijalankan langsung agar kompatibel dengan izin file GitHub Codespaces.
- `config/source.cnf` dan `config/replica.cnf`: salinan referensi konfigurasi untuk dipelajari; container tidak me-mount file ini.
- `sql/01-init-source.sql`: basis data contoh `toko_db`.
- `sql/02-uji-replikasi.sql`: contoh operasi INSERT, UPDATE, dan DELETE.
- `scripts/setup-replication.sh`: konfigurasi otomatis source-replica.
- `scripts/test-replication.sh`: uji replikasi end-to-end.
- `scripts/reset-lab.sh`: menghapus container dan volume praktikum.

## Cara yang direkomendasikan: GitHub Codespaces

Metode ini tidak memerlukan Docker Desktop, instalasi MySQL, atau hak administrator pada laptop. Laptop hanya membuka browser; Docker Engine dan kedua server MySQL berjalan pada server GitHub Codespaces.

Prasyarat:

1. Akun GitHub yang dapat menggunakan Codespaces.
2. Browser dan akses internet ke GitHub.
3. Seluruh isi folder ini diunggah sebagai root repositori, termasuk `.devcontainer`.

Langkah singkat:

1. Pada repositori GitHub, klik **Code > Codespaces > Create codespace on main**.
2. Tunggu editor browser dan proses penyiapan selesai.
3. Buka terminal Codespace.
4. Jalankan satu perintah:

```bash
bash scripts/codespaces-start.sh
```

Panduan bergambar langkah demi langkah tersedia pada `CARA_GITHUB_CODESPACES.md`.

Koneksi administrasi di dalam container menggunakan Unix socket. Mode `super_read_only` pada replica baru diaktifkan setelah inisialisasi dan konfigurasi replikasi selesai, lalu disimpan agar tetap aktif setelah restart. Alamat IPv4 pada contoh koneksi manual tetap digunakan untuk mengakses port container dari terminal Codespaces.

## Cara manual di terminal Codespaces

```bash
cp .env.example .env
bash scripts/setup-replication.sh
bash scripts/test-replication.sh
```

Jika berhasil, skrip uji menampilkan data yang sama pada source dan replica, status `Replica_IO_Running: Yes`, `Replica_SQL_Running: Yes`, dan pesan bahwa replica menolak penulisan langsung.

## Koneksi manual dari terminal Codespaces

```bash
# Source
mysql -h 127.0.0.1 -P 3307 -uroot -p

# Replica
mysql -h 127.0.0.1 -P 3308 -uroot -p
```

Password demonstrasi terdapat pada `.env.example`. Jangan gunakan kredensial contoh untuk produksi.

## Uji SQL tambahan

Jalankan berkas uji pada source:

```bash
docker compose exec -T mysql-source \
  mysql -uroot -pRootPass123! < sql/02-uji-replikasi.sql
```

Lalu bandingkan:

```bash
docker compose exec mysql-source \
  mysql -uroot -pRootPass123! -e "SELECT * FROM toko_db.produk;"

docker compose exec mysql-replica \
  mysql -uroot -pRootPass123! -e "SELECT * FROM toko_db.produk;"
```

## Pemeriksaan status

```sql
SHOW REPLICA STATUS\G
```

Indikator utama:

- `Replica_IO_Running = Yes`: replica terhubung dan membaca log dari source.
- `Replica_SQL_Running = Yes`: perubahan berhasil diterapkan.
- `Seconds_Behind_Source`: perkiraan keterlambatan replica.
- `Last_IO_Error` dan `Last_SQL_Error`: harus kosong.

## Reset lingkungan

```bash
bash scripts/reset-lab.sh
```

Perintah ini meminta konfirmasi karena volume data akan dihapus.

## Catatan konsep dari materi

Distributed Database adalah kumpulan data yang disimpan di beberapa lokasi tetapi tampak sebagai satu basis data. Distributed DBMS adalah perangkat lunak yang mengatur penyimpanan, query, transaksi, sinkronisasi, keamanan, dan transparansi distribusi tersebut. Replikasi adalah salah satu teknik pada basis data tersebar: salinan data ditempatkan di lebih dari satu lokasi untuk meningkatkan ketersediaan dan mempercepat pembacaan, dengan konsekuensi kebutuhan sinkronisasi dan pengendalian konsistensi.

## Referensi teknis

- MySQL 8.4 Reference Manual, GTID Auto-Positioning: https://dev.mysql.com/doc/refman/8.4/en/replication-gtids-auto-positioning.html
- MySQL 8.4 Reference Manual, Replication Source Configuration: https://dev.mysql.com/doc/refman/8.4/en/replication-howto-masterbaseconfig.html
- MySQL Official Docker Image: https://hub.docker.com/_/mysql
- GitHub Codespaces, Introduction to Dev Containers: https://docs.github.com/codespaces/setting-up-your-project-for-codespaces/introduction-to-dev-containers
- Docker-in-Docker Dev Container Feature: https://github.com/devcontainers/features/tree/main/src/docker-in-docker
