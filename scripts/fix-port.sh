#!/usr/bin/env bash
set -e; cd "$(dirname "$0")/.."
echo ">> redeploying backend on :80"
docker compose up -d --no-deps backend >/dev/null 2>&1
