#!/usr/bin/env bash
# Scenario 3, firewall: DROP inbound tcp/80 on the backend (timeout).
set -e; cd "$(dirname "$0")/.."
echo ">> iptables -I INPUT -p tcp --dport 80 -j DROP  (inside kata-backend)"
docker run --rm --network container:kata-backend --cap-add NET_ADMIN nicolaka/netshoot:v0.13 \
  iptables -I INPUT -p tcp --dport 80 -j DROP
echo ">> done. make watch | make diagnose"
