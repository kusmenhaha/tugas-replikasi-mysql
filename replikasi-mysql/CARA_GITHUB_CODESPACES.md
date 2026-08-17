# Menjalankan Tugas di GitHub Codespaces

Panduan ini tidak memerlukan Docker Desktop, instalasi MySQL, atau hak administrator pada laptop. Laptop hanya digunakan untuk membuka browser; lingkungan Linux dan Docker Engine berjalan pada server GitHub Codespaces.

## 1. Siapkan repositori

1. Masuk ke https://github.com.
2. Buat repositori baru, misalnya `tugas-replikasi-mysql`.
3. Unggah **seluruh isi** folder `replikasi-mysql` ke root repositori.
4. Pastikan berkas `.devcontainer/devcontainer.json` ikut terunggah.

Struktur root repositori harus terlihat seperti ini:

```text
.devcontainer/
compose.yaml
config/
scripts/
sql/
README.md
```

## 2. Buat Codespace

1. Buka halaman repositori.
2. Klik **Code**.
3. Pilih tab **Codespaces**.
4. Klik **Create codespace on main**.
5. Tunggu sampai editor berbasis browser terbuka dan proses penyiapan selesai.

Konfigurasi `.devcontainer/devcontainer.json` otomatis menyediakan Docker Engine dan Docker Compose di server Codespaces. Tidak ada instalasi Docker pada laptop kantor.

## 3. Jalankan praktikum

Buka menu **Terminal > New Terminal**, lalu jalankan:

```bash
bash scripts/codespaces-start.sh
```

Jika sebelumnya pernah menjalankan versi lama dan muncul `GTID_MODE = OFF`, hapus volume praktikum lama satu kali:

```bash
docker compose down -v
bash scripts/codespaces-start.sh
```

Opsi `-v` menghapus data praktikum lama. Jangan gunakan perintah tersebut untuk volume yang berisi data penting.

Jika perintah dengan awalan `./` pernah menampilkan `Permission denied`, jalankan skrip dengan `bash` seperti contoh di atas. Cara ini tidak memerlukan izin executable pada file.

Jika muncul `Host '::1' is not allowed to connect`, `Host '127.0.0.1' is not allowed to connect`, atau `Access denied for user 'root'@'localhost'` khusus pada replica, gunakan versi paket terbaru dan reset volume sekali. Paket terbaru memakai Unix socket serta baru mengaktifkan `super_read_only` setelah inisialisasi replica selesai.

Skrip tersebut akan:

1. Menunggu Docker Engine di Codespace siap.
2. Menjalankan MySQL source dan replica.
3. Mengatur replikasi menggunakan GTID.
4. Menambahkan data uji pada source.
5. Memastikan data muncul pada replica.
6. Memastikan replica menolak penulisan langsung.

## 4. Hasil yang benar

Terminal harus menampilkan indikator berikut:

```text
Replica_IO_Running: Yes
Replica_SQL_Running: Yes
Seconds_Behind_Source: 0
BERHASIL: data tersalin dan replica bersifat read-only.
```

`Seconds_Behind_Source` dapat sesaat bernilai selain 0. Yang wajib adalah kedua thread bernilai `Yes` dan tidak ada `Last_IO_Error` atau `Last_SQL_Error`.

## 5. Mengambil bukti tugas

Ambil tangkapan layar terminal yang memperlihatkan:

- Perintah `bash scripts/codespaces-start.sh`.
- Data yang sama pada source dan replica.
- `Replica_IO_Running: Yes`.
- `Replica_SQL_Running: Yes`.
- Pesan `BERHASIL`.

## 6. Menghentikan lingkungan

```bash
docker compose down
```

Untuk menghapus seluruh data praktikum:

```bash
bash scripts/reset-lab.sh
```

Setelah selesai, hentikan Codespace melalui halaman GitHub Codespaces agar kuota komputasi tidak terus terpakai.

## Catatan akses kantor

- Tidak diperlukan hak administrator lokal.
- Koneksi internet ke GitHub dan registry container tetap diperlukan.
- Kebijakan jaringan kantor dapat memblokir GitHub Codespaces atau registry image.
- Penggunaan Codespaces mengikuti kuota akun GitHub.
