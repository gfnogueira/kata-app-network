#!/usr/bin/env bash
# Scenario 5, segmentation: api leaves the backend network.
# Docker DNS only resolves names across a shared network, so this shows as NXDOMAIN.
set -e; cd "$(dirname "$0")/.."
echo ">> docker network disconnect kata_backend kata-api"
docker network disconnect kata_backend kata-api
echo ">> done. make watch | make diagnose"
