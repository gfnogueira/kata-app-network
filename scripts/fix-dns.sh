#!/usr/bin/env bash
set -e; cd "$(dirname "$0")/.."
echo ">> redeploying api with BACKEND_HOST=backend"
docker compose up -d --no-deps api >/dev/null 2>&1
