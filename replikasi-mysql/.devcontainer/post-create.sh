#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

if [[ ! -f .env ]]; then
  cp .env.example .env
fi

chmod +x scripts/*.sh

echo "Codespace siap. Jalankan: bash scripts/codespaces-start.sh"
