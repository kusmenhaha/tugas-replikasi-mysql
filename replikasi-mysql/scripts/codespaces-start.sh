#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

if [[ ! -f .env && -f .env.example ]]; then
  cp .env.example .env
fi

echo "Menunggu Docker Engine di Codespace siap..."
for attempt in $(seq 1 60); do
  if docker info >/dev/null 2>&1; then
    break
  fi
  if [[ "$attempt" -eq 60 ]]; then
    echo "Docker Engine Codespace belum siap setelah 120 detik." >&2
    exit 1
  fi
  sleep 2
done

bash scripts/setup-replication.sh
bash scripts/test-replication.sh
