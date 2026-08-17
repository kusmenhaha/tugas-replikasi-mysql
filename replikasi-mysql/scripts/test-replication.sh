#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-RootPass123!}"

if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
else
  echo "Docker Compose tidak ditemukan." >&2
  exit 1
fi

mysql_service() {
  local service="$1"
  shift
  "${COMPOSE[@]}" exec -T -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" "$service" \
    mysql -h 127.0.0.1 -uroot --protocol=tcp "$@"
}

TOKEN="uji-$(date +%s)"
echo "Menambahkan data unik pada source: $TOKEN"
mysql_service mysql-source toko_db -e \
  "INSERT INTO produk (nama_produk, harga, stok) VALUES ('$TOKEN', 99000.00, 7);"

ID_PRODUK="$(mysql_service mysql-source -N -s toko_db -e \
  "SELECT id_produk FROM produk WHERE nama_produk='$TOKEN' ORDER BY id_produk DESC LIMIT 1;")"

echo "Menunggu baris id=$ID_PRODUK muncul pada replica..."
for attempt in $(seq 1 30); do
  JUMLAH="$(mysql_service mysql-replica -N -s toko_db -e \
    "SELECT COUNT(*) FROM produk WHERE id_produk=$ID_PRODUK AND nama_produk='$TOKEN';" 2>/dev/null || echo 0)"
  if [[ "$JUMLAH" == "1" ]]; then
    break
  fi
  sleep 1
done

if [[ "${JUMLAH:-0}" != "1" ]]; then
  echo "GAGAL: data tidak ditemukan pada replica." >&2
  exit 1
fi

echo "Data pada source:"
mysql_service mysql-source toko_db -e \
  "SELECT id_produk, nama_produk, harga, stok FROM produk WHERE id_produk=$ID_PRODUK;"

echo "Data pada replica:"
mysql_service mysql-replica toko_db -e \
  "SELECT id_produk, nama_produk, harga, stok FROM produk WHERE id_produk=$ID_PRODUK;"

echo "Status replikasi:"
mysql_service mysql-replica -e "SHOW REPLICA STATUS\G" | \
  grep -E "Replica_IO_Running:|Replica_SQL_Running:|Seconds_Behind_Source:|Last_IO_Error:|Last_SQL_Error:"

echo "Menguji bahwa replica menolak penulisan langsung..."
if mysql_service mysql-replica toko_db -e \
  "INSERT INTO produk (nama_produk, harga, stok) VALUES ('seharusnya-ditolak', 1, 1);" \
  >/dev/null 2>&1; then
  echo "GAGAL: replica menerima penulisan langsung." >&2
  exit 1
fi

echo "BERHASIL: data tersalin dan replica bersifat read-only."
