#!/usr/bin/env bash
# Scenario 2, port: backend listens on 9000, api still dials 80 (connection refused).
set -e; cd "$(dirname "$0")/.."
echo ">> redeploying backend on :9000 (api still dials :80)"
docker compose -f docker-compose.yml -f scenarios/port.yml up -d --no-deps backend >/dev/null 2>&1
echo ">> done. make watch | make diagnose"
