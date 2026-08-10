# Clayton's Initial Plan/Strategy

(This is the initial plan with some small clarifications and corrections. It is intentionally left as close as possible to my original thought process while doing the challenge live.)

## Notes:
- Each row is a drive-day (unique serial number and date)
- Failure rate "annualized failure rates (AFR)" = (failures / (drive-years / 365)) * 100%

- Look at the data, download
- Scriptify (maybe later) process of download/port-to-db
- Docker compose for postgres and Go API-server

## DB setup
- Made schema in 2_setupDB.sql
- Made Indexes, logged, and analyze in 4_postPortDB.sql
- Test our Materialized View in 5_benchmarkQueries.sql


## API-server
- CRUD
  - C 
  - R ("Get me limit rows where model = X and date = Y", "Get me the rollup")
  - U 
  - D 


# Biggest Challenges:
- Porting data in a timely fashion
    - File by file (COPY FROM HEADERs, on the container already)
    - Make a super-file of all the CSVs and do one copy

- Making our Queries fast





## TODOS/Problems with this Project as done in one shot:
- Actually scriptify the port-to-db process and DB setup
- Fix the date format issues in the API so that requests can be more friendly to make without errors.
- Think about giving the columns IDs that are hashes of `serial_number + date` so things are overall cleaner on the backend?
- Queries are all just raw SQL. This is bad for SQL injection, we should use some library for controlled queries. (This is wrong, see `write-up.md`)
- We can `REFRESH MATERIALIZED VIEW CONCURRENTLY drive_rollup;` in the background with a go routine to keep the rollup up to date.
    - A redesign here might conider a DB or extension that can do a *TIMED* `REFRESH MATERIALIZED VIEW CONCURRENTLY drive_rollup;`
    - TimescaleDB is capable of this
- We could have more/better endpoints to query the rollup. For example, for one model, or over a specific date range. We could have different rollups potentially as well.
- We could have actual Golang tests for the API, not jsut a curl shell script.
- We didnt really scrutinize the speed of the C,U,D queries, but we could have done that. These arent the big issues here as of now.

# Original Challenge:

### Objectives

Download at least two BackBlaze hard drive dataset CSVs and load them into a SQL database of your choosing.

[Backblaze Hard Drive Test Data](https://www.backblaze.com/cloud-storage/resources/hard-drive-test-data)

Create a standard CRUD REST API to query the data.

Create a REST API to query average failure rates grouped by model across all datasets

Specifically look at performance tuning API response and database query times to achieve the fastest response time possible.

Write it in Go or a language of your choice.

### Deliverables

- An unedited screen-recording of your coding session (include all windows used)
- A write-up explaining your architecture, decisions, considerations, etc.
- Codebase and dataset you wrote to perform the extraction.
- Documentation of any AI tool usage, including prompts.

