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
REPLICATION_PASSWORD="${REPLICATION_PASSWORD:-ReplicaPass123!}"

if [[ "$MYSQL_ROOT_PASSWORD" == *"'"* || "$REPLICATION_PASSWORD" == *"'"* ]]; then
  echo "Password praktikum tidak boleh memuat tanda petik tunggal (')." >&2
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
else
  echo "Docker Compose tidak ditemukan di Codespace. Rebuild Codespace dari konfigurasi .devcontainer." >&2
  exit 1
fi

mysql_source() {
  "${COMPOSE[@]}" exec -T -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql-source \
    mysql -h 127.0.0.1 -uroot --protocol=tcp "$@"
}

mysql_replica() {
  "${COMPOSE[@]}" exec -T -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql-replica \
    mysql -h 127.0.0.1 -uroot --protocol=tcp "$@"
}

wait_for_mysql() {
  local service="$1"
  local attempt
  for attempt in $(seq 1 60); do
    if "${COMPOSE[@]}" exec -T "$service" \
      mysqladmin ping -h 127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD" --silent \
      >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "MySQL pada layanan $service belum siap setelah 120 detik." >&2
  return 1
}

echo "Menjalankan container source dan replica..."
"${COMPOSE[@]}" up -d

echo "Menunggu kedua server MySQL siap..."
wait_for_mysql mysql-source
wait_for_mysql mysql-replica

read -r SOURCE_GTID SOURCE_SERVER_ID SOURCE_LOG_BIN <<<"$(
  mysql_source -N -s -e "SELECT @@GLOBAL.gtid_mode, @@GLOBAL.server_id, @@GLOBAL.log_bin;"
)"
read -r REPLICA_GTID REPLICA_SERVER_ID <<<"$(
  mysql_replica -N -s -e "SELECT @@GLOBAL.gtid_mode, @@GLOBAL.server_id;"
)"

if [[ "$SOURCE_GTID" != "ON" || "$REPLICA_GTID" != "ON" || \
      "$SOURCE_SERVER_ID" != "1" || "$REPLICA_SERVER_ID" != "2" || \
      "$SOURCE_LOG_BIN" != "1" ]]; then
  cat >&2 <<EOF
Konfigurasi GTID belum aktif dengan benar.
Source : GTID=$SOURCE_GTID, server-id=$SOURCE_SERVER_ID, log-bin=$SOURCE_LOG_BIN
Replica: GTID=$REPLICA_GTID, server-id=$REPLICA_SERVER_ID

Jika lingkungan berasal dari versi lama, reset volume sekali lalu jalankan ulang:
  docker compose down -v
  bash scripts/codespaces-start.sh
EOF
  exit 1
fi

echo "GTID aktif: source=$SOURCE_GTID (server-id=$SOURCE_SERVER_ID), replica=$REPLICA_GTID (server-id=$REPLICA_SERVER_ID)."

echo "Membuat akun replikasi pada source..."
mysql_source <<SQL
CREATE USER IF NOT EXISTS 'replicator'@'%' IDENTIFIED BY '$REPLICATION_PASSWORD';
ALTER USER 'replicator'@'%' IDENTIFIED BY '$REPLICATION_PASSWORD';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';
FLUSH PRIVILEGES;
SQL

echo "Menghubungkan replica ke source menggunakan GTID auto-positioning..."
mysql_replica -e "STOP REPLICA;" >/dev/null 2>&1 || true
mysql_replica <<SQL
RESET REPLICA ALL;
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST='mysql-source',
  SOURCE_PORT=3306,
  SOURCE_USER='replicator',
  SOURCE_PASSWORD='$REPLICATION_PASSWORD',
  SOURCE_AUTO_POSITION=1,
  GET_SOURCE_PUBLIC_KEY=1;
START REPLICA;
SQL

echo "Menunggu thread I/O dan SQL aktif..."
for attempt in $(seq 1 30); do
  STATUS="$(mysql_replica -e 'SHOW REPLICA STATUS\G' 2>/dev/null || true)"
  if grep -q "Replica_IO_Running: Yes" <<<"$STATUS" && \
     grep -q "Replica_SQL_Running: Yes" <<<"$STATUS"; then
    echo "Replikasi aktif."
    mysql_replica -e "SHOW REPLICA STATUS\G" | \
      grep -E "Source_Host:|Replica_IO_Running:|Replica_SQL_Running:|Seconds_Behind_Source:|Last_IO_Error:|Last_SQL_Error:"
    exit 0
  fi
  sleep 2
done

echo "Replikasi belum sehat. Status terakhir:" >&2
mysql_replica -e "SHOW REPLICA STATUS\G" >&2 || true
exit 1
