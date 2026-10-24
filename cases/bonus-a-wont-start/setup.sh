#!/usr/bin/env bash
# Prepares the customer's environment. Don't read this file.
set -euo pipefail
cd "$(dirname "$0")"
docker compose up -d
echo "ready (or rather, not): http://localhost:5710 . Try: docker compose ps -a"
