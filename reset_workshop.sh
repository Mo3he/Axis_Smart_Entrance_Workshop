#!/bin/sh
# Deletes all participant flows and restarts Node-RED with the clean starter flow.
cd "$(dirname "$0")" || exit 1
docker compose down -v
docker compose up -d --build
echo "Node-RED reset. Open http://localhost:1880"
