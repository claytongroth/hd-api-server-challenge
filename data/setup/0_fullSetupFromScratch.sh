#!/usr/bin/env bash

# bail out on the first failure
set -euo pipefail

# start time for logging duration
START=$(date +%s)

# --- Full Setup from Scratch -------------------------------------------------

# Get all the data from Backblaze
./1_getData.sh

# Start the DB only. The API stays down until the data is loaded
cd ../../
docker compose up -d --wait db
cd -

# Port all the data to the DB (runs 2_setupDB.sql, the COPYs, 4_postPortDB.sql)
./3_portData.sh

# Data is loaded and drive_rollup exists, so the API can come up now
cd ../../
docker compose up -d --build api

# --- Summary -----------------------------------------------------------------
ELAPSED=$(( $(date +%s) - START ))

echo "-----------------------------------------------"
printf 'Setup complete in %dh %02dm %02ds\n' \
    $(( ELAPSED / 3600 )) $(( ELAPSED % 3600 / 60 )) $(( ELAPSED % 60 ))
echo "-----------------------------------------------"