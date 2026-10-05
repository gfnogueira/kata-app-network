#!/usr/bin/env bash
# Reset every scenario.
cd "$(dirname "$0")/.."
scripts/fix-network.sh
scripts/fix-firewall.sh
scripts/fix-latency.sh
docker compose up -d >/dev/null 2>&1
echo ">> all clean"
