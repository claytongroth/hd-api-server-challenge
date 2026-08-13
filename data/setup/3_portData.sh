#!/usr/bin/env bash
#
# 3_portData.sh -- load every Backblaze CSV into drive_stats.
#
# The CSVs are read by the POSTGRES SERVER off the ./data/csv_data bind mount
# (mounted at /csv_data in the db container). Nothing is copied into the
# container and nothing is streamed over the client connection -- each file is
# a plain server-side `COPY ... FROM '/csv_data/<file>'`.
#
# Run 2_setupDB.sql first, 4_postPortDB.sql after.
#
# HOW TO RUN
#
#   Testing OFF (full load, all CSVs):
#       ./3_portData.sh
#
#   Testing ON (default sample of 5 files):
#       ./3_portData.sh -t
#
#   Testing ON with an explicit sample count:
#       ./3_portData.sh -t -n 20
#
#   Parallel COPYs (default 4 at a time):
#       ./3_portData.sh -j 8
#
# Exits non-zero if any file fails to copy.

set -euo pipefail

# --- IS_TESTING (default false), sample count, thread count -- all by flag ---
IS_TESTING=false
SAMPLE_COUNT=5
THREADS=4

while getopts ":tn:j:" opt; do
    case "$opt" in
        t) IS_TESTING=true ;;
        n) SAMPLE_COUNT="$OPTARG" ;;
        j) THREADS="$OPTARG" ;;
        *) echo "usage: $0 [-t] [-n SAMPLE_COUNT] [-j THREADS]" >&2; exit 2 ;;
    esac
done

# --- Postgres connection info ----------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DB_SERVICE="db"          # service name in docker-compose.yml
PG_USER="postgres"
PG_DB="postgres"
TABLE="drive_stats"

CSV_DIR_HOST="$REPO_ROOT/data/csv_data"   # where we list files from
CSV_DIR_MOUNT="/csv_data"                 # where the server reads them from


# Run the initial SQL table setup in 2_setupDB.sql


log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

# psql inside the db container. -T = no TTY, ON_ERROR_STOP = fail loudly.
psql_c() {
    docker compose -f "$REPO_ROOT/docker-compose.yml" exec -T "$DB_SERVICE" \
        psql -U "$PG_USER" -d "$PG_DB" -v ON_ERROR_STOP=1 --no-psqlrc -tA -c "$1"
}

# Run a SQL file in the db container. Fed in on stdin because the setup/ dir
# isn't mounted, so `-f` would look for it container-side.
run_sql_file() {
    docker compose -f "$REPO_ROOT/docker-compose.yml" exec -T "$DB_SERVICE" \
        psql -U "$PG_USER" -d "$PG_DB" -v ON_ERROR_STOP=1 --no-psqlrc \
        < "$SCRIPT_DIR/$1"
}


# --- Make sure the server can actually read the bind mount ------------------
# Checked before 2_setupDB.sql so a bad mount doesn't drop the table first.
log "Checking the bind mount at $CSV_DIR_MOUNT inside the '$DB_SERVICE' container..."

MOUNTED_COUNT="$(docker compose -f "$REPO_ROOT/docker-compose.yml" exec -T "$DB_SERVICE" \
    sh -c "ls -1 $CSV_DIR_MOUNT/*.csv 2>/dev/null | wc -l" | tr -d '[:space:]')"

if [ "$MOUNTED_COUNT" = "0" ]; then
    log "ERROR: no CSVs visible at $CSV_DIR_MOUNT in the container."
    log "       Is ./data/csv_data populated and the container up?"
    exit 1
fi
log "OK: $MOUNTED_COUNT CSV files visible to the server."


log "Running the initial SQL table setup in 2_setupDB.sql..."
run_sql_file 2_setupDB.sql

# --- Build the file list ----------------------------------------------------
cd "$CSV_DIR_HOST"

if [ "$IS_TESTING" = true ]; then
    FILES=$(ls -1 *.csv | head -n "$SAMPLE_COUNT")
    log "TESTING MODE ON -- loading only the first $SAMPLE_COUNT file(s)."
else
    FILES=$(ls -1 *.csv)
    log "TESTING MODE OFF -- loading all files."
fi

TOTAL=$(printf '%s\n' "$FILES" | wc -l | tr -d '[:space:]')

# --- One server-side COPY FROM per file, run THREADS at a time --------------
# xargs runs each call in its own process, so the worker and everything it
# touches has to be exported.
copy_one() {
    INDEX="$1"
    FILE="$2"
    FILE_START=$(date +%s)

    log "[$INDEX/$TOTAL] COPY $FILE -- starting"

    if ! RESULT=$(psql_c "COPY $TABLE FROM '$CSV_DIR_MOUNT/$FILE' WITH (FORMAT csv, HEADER true);"); then
        log "[$INDEX/$TOTAL] ERROR: COPY failed for $FILE -- aborting."
        # 255 is the one exit code that makes xargs stop dispatching new work.
        exit 255
    fi

    ROWS=$(printf '%s' "$RESULT" | tr -dc '0-9')
    FILE_ELAPSED=$(($(date +%s) - FILE_START))

    log "[$INDEX/$TOTAL] OK: $FILE -- ${ROWS:-0} rows in ${FILE_ELAPSED}s"
}

export -f copy_one log psql_c
export REPO_ROOT DB_SERVICE PG_USER PG_DB TABLE CSV_DIR_MOUNT TOTAL

log "Starting load of $TOTAL file(s) into $TABLE, $THREADS at a time."
RUN_START=$(date +%s)

# nl pairs each file with its index so the logs stay readable when interleaved.
if ! printf '%s\n' "$FILES" \
    | nl -ba -w1 -s' ' \
    | xargs -P "$THREADS" -L1 bash -c 'copy_one "$0" "$1"'; then
    log "ERROR: at least one COPY failed -- the table is now partially loaded."
    log "       Re-run 2_setupDB.sql to start clean."
    exit 1
fi

RUN_ELAPSED=$(($(date +%s) - RUN_START))


# --- Run the post-port SQL file ----------------------------------------------
log "Running the post-port SQL file in 4_postPortDB.sql..."
run_sql_file 4_postPortDB.sql