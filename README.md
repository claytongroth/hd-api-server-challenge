# Video Results:

All parts were recorded consecutively with no edits and uploaded to YouTube.

- [Part 1 Link](https://youtu.be/t9PMPT3f2zk)
- [Part 2 Link](https://youtu.be/bjVaHv50xmI)
- [Part 3 Link](https://youtu.be/uYUbJxIZOR0)
- [Part 4 Link](https://youtu.be/8UTIvDSz71w)


Additionally, I have physically recorded the entire process on an iPhone for backup. While this may be over the top, I was worried about potential data loss and wanted to make sure the whole process was seamlessly recorded somewhere.

- [Entire Seamless Recording IPhone for Backup](https://youtu.be/Dkd1VAxA784)

# Challenge Results:

- [X] All data ported in timely fashion
- [X] Minimal Working CRUD
- [X] Fast Response times for all queries, including group by model for failure rate
 
### Simple Test Results `test.sh`
```
-----------------------------------------------
passed: 21   failed: 0
RESULT: PASS
```
These are super basic tests for now.

# Quick Start (Needs to be Scriptified):

Requires Docker, `curl`, `unzip`, and `jq` (for `test.sh`). The full load is ~2.3 GB of
zips and 182 CSVs, and takes ~5 minutes on the `COPY` step alone.

```bash
# 1. Download and unzip the two quarters (~2.3 GB).
#    Both zips and the extracted CSVs are gitignored.
cd data/setup && ./1_getData.sh && cd ../..

# 2. Put every CSV flat in data/csv_data/ (one file per day, e.g. 2025-10-01.csv).
#    This step is still manual -- see the write-up. The db container mounts this
#    directory read-only at /csv_data so the server can COPY from it directly.

# 3. Bring up Postgres.
docker compose up -d db

# 4. Create the (UNLOGGED) drive_stats table.
docker compose exec -T db psql -U postgres -d postgres < data/setup/2_setupDB.sql

# 5. Load the CSVs -- server-side COPY, 4 files at a time.
#    Add -t for a 5-file subset test.
./data/setup/3_portData.sh

# 6. Set the table LOGGED, add the PK + indexes, ANALYZE, build the rollup
#    materialized view. This is the slow one (the ALTER TABLE alone is ~6 min).
docker compose exec -T db psql -U postgres -d postgres < data/setup/4_postPortDB.sql

# 7. Start the API on :8080.
docker compose up -d
```

### Endpoints

```
GET    /helloworld
GET    /rollup_stats                              # avg failure rates grouped by model
GET    /drive_stats/{serial_number}/{date}        # one drive-day (primary key lookup)
POST   /drive_stats                               # body: JSON, date as RFC 3339
PUT    /drive_stats                               # body: JSON, date as RFC 3339
DELETE /drive_stats/{serial_number}/{date}
```

`curl` examples for each live next to the route in `hd-api-server/cmd/routes.go`.

### Smoke test

```bash
# REAL_SERIAL/REAL_DATE point the real-data probe at a row you actually loaded:
#   select serial_number, date from drive_stats limit 1;
REAL_SERIAL=<a loaded serial> REAL_DATE=2025-10-06 ./test.sh
```

`data/setup/5_benchmarkQueries.sql` holds the before/after query timings discussed in
the write-up.

