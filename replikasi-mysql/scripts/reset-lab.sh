#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
else
  echo "Docker Compose tidak ditemukan." >&2
  exit 1
fi

if [[ "${1:-}" != "--yes" ]]; then
  read -r -p "Hapus container dan seluruh volume data praktikum? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || exit 0
fi

"${COMPOSE[@]}" down -v
echo "Lingkungan praktikum telah dihapus. Jalankan: bash scripts/codespaces-start.sh"
