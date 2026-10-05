#!/usr/bin/env bash
# Scenario 1, DNS: api dials a hostname that does not exist.
set -e; cd "$(dirname "$0")/.."
echo ">> redeploying api with BACKEND_HOST=backned (typo)"
docker compose -f docker-compose.yml -f scenarios/dns.yml up -d --no-deps api >/dev/null 2>&1
echo ">> done. make watch | make diagnose"
