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

# Quick Start

Requires Docker, `curl`, `unzip`, and `jq` (for `test.sh`).

```bash
cd data/setup && ./0_fullSetupFromScratch.sh
```

- Downloads two quarters of Backblaze data, 
= Loads all 182 CSVs, adds the PK,
- Indexes and the `drive_rollup` materialized view, and starts the API on :8080.
- Wipes `data/csv_data/` and the `drive_stats` table first, so it is safe to
re-run. 
- Slowest steps are the `COPY`s, the `SET LOGGED` rewrite (~6 min) and the
first rollup build (~4 min).

If the CSVs are already in `data/csv_data/`, skip the download:

```bash
docker compose up -d --wait db
cd data/setup && ./3_portData.sh   # -t loads a 5-file subset
docker compose up -d --build api
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

