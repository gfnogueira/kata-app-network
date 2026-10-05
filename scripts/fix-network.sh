#!/usr/bin/env bash
set -e; cd "$(dirname "$0")/.."
echo ">> docker network connect kata_backend kata-api"
docker network connect kata_backend kata-api 2>/dev/null || echo "   (already connected)"
