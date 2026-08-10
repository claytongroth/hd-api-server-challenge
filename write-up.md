# Introduction:

In what follows, I will detail my approach to the problem as I first encountered it, what plans I made, how I executed or changed those plans, what went well and what could have gone better, and finally what I would change if this codebase were to move forward.

When first glancing at the problem, before sitting down to begin coding, I noticed several things that stuck out to me as potentially the most difficult aspects. The first was that the dataset(s) would likely be very large. Hard drive data, just thinking naively, can scale rapidly. This made me see the problem as having two steep hills: first, porting the data efficiently from CSV to DB, and second, the `GROUP BY` specifically required by the problem.

The first challenge I had tackled in the past several times, learning the hard way trying to migrate massive amounts of data (I was fiddling with some huge EPA and IPCC files). However, I knew that, doing the challenge live, I needed to overcome the migration rather quickly or the rest of the pieces would not fall in place.

The second challenge I had some experience with from analytics visualizations in the past (`VIEWS`). I was aware though that if the API-server was to be CRUD (emphasis on "create"), I would at least need to address how to roll-up the data periodically.

# My Approach to the Problem:

## Interpreting the Data Set
My approach to the problem took the form of quickly trying to triage what the biggest bottlenecks to a smooth completion would be. As my initial reading suggested, I judged these to be the data-migration and the presumably large `GROUP BY`. 

I instantly knew that I would want a small `docker-compose.yml` with a server and a DB, for tidiness, reusability, and the ability to store the data on a volume-mount so that I did not have to mess with my local Postgres and could start with a clean slate. 

The shape of the data needed to be ascertained quickly, because that could drastically change what paths I might have to take to complete the challenge. I read through the Backblaze webpage hosting the files to get a good feel for what the data was about, what a "failure rate" might mean, and what info was available there. My understanding of the data was that it was quarterly records of "Drive Days" (DD going forward), where a DD was a `serial_number` (specific drive of a given model) and `date` pair. This value would be unique and likely my primary key. So, multiple rows could exist for any given `model, serial_number`, etc., but not for a given `serial_number + date`. 

The challenge stated:

> Create a REST API to query average failure rates grouped by model across all datasets

I took "all datasets" to mean "all downloaded data sets". I noticed from Backblaze's site that the schema download indicated that the schema had not changed since Q2 2024 ("Last Updated Q2 2024"). Opting to download the two most recent sets, I would likely avoid having to fight schema-mismatch issues.

I took several interpretations of "failure rate" just to be safe. My initial read was that we probably wanted Backblaze's Annualized Failure Rate (AFR), but I kept a naive one as well. I calculated these as:

```
Naive Failure Rate = total failures by model X / total DD for model X

AFR = (failures / drive-years) × 100%

(where drive-years for model X = total DD for model X / 365)
```
My arithmetic there can be better simplified to:
```
 ( total failures by model X * 365 / total DD for model X ) * 100%
```
but, I was thinking in Drive-Years after reading the documentation. 


# How I Solved the Problem:

## Downloading and Peeking at the Data:

I wanted to get a feel for what the data looked like before really diving in and committing to any one direction. I copied the file URLs and started a preliminary shell script so that the full ingress-process could be automated in the future.

Downloading and peeking at the data, I got a much better feel for what was actually in the CSVs, how big they were, and what the columns meant. I reaffirmed that DD was the right way to look at the data and began looking for inconsistencies.

I wanted to know two things right away.

1. Were the headers to all these files the same? (Even after reading the schema 2024 thing, I wanted to check.)
2. Were there huge data type or column discrepancies across files, or inter-file across rows?

I mostly spot-checked here via the terminal. I think a valid criticism of my approach is that I could have spent a little more time validating here. However, I knew that ingesting the data was going to be one of the biggest hurdles here, and wanted to triage the tasks ahead of me, prioritizing those with the highest risk of going wrong.

For 1, I verified that the headers were the same by manually spot-checking several (shell check later as well). For 2, I did several `head -n x` and `tail -n x` checks to make sure. 

Again, here I could have written some small Python scripts to be absolutely certain, but I wanted to move forward, should things take long or need repair moving forward.


## Schema and Porting the Data (port took only several minutes):
After being relatively satisfied with the shape/consistency of the data, I knew I needed two things before porting the data:

1. A table to port the data into
2. A shell script to efficiently do the port

Some background knowledge/experience helped here. Having done similar huge CSV --> DB ports before, I knew several gotchas and good ideas. The first was to use an `UNLOGGED` table at first (we can set it to `LOGGED` later) and the second was to make sure that the copy happens matching the following criteria:

- `COPY FROM` is the fastest move here. Line by line would be astronomically slow, of course.
- We do NOT want to read/transfer/copy ANY data we don't absolutely have to. I saw hints of this right away when thinking of how we wanted the `docker-compose.yml`.
- We can parallelize the writes to save lots of time cheaply via shell with `xargs -P` 
- The script should be verbose, but simple (timing logged for everything)
- The script should have a testing flag that would let me run only a small subset

### Making the Table:
First I will address my `CREATE TABLE` data type choices. I decided to be a little fast and loose here, admittedly, given the scope of the assignment. In the real world I would not make such a move. I settled on the types in `data/setup/2_setupDB.sql`. In retrospect, the best move would have been to use Backblaze's Apache Iceberg dataset and nab the types from there (likely knowing that those were fully representative of the data).

These choices are acknowledged as not optimal and could all be more exact, either doing some analysis or looking at Backblaze's Apache Iceberg.
```sql
CREATE UNLOGGED TABLE drive_stats (
    date date,
    serial_number varchar(255),
    model varchar(255),
    capacity_bytes bigint,
    failure smallint,
    datacenter varchar(100),
    cluster_id varchar(100),
    vault_id varchar(100),
    pod_id varchar(100),
    pod_slot_num varchar(100),
    is_legacy_format boolean,
    ...
)
```
I decided to forgo `NOT NULL` for the time being, again because I wanted to get the migration through. It is worth noting too that the `smart_*` columns I set all to `TEXT`, which is no doubt wasteful, but those seemed drive-relative and I didn't want to lose data or slow down too much.

I also opted to leave my primary key out at this point, to ease the write operations.

After putting this statement together, I booted up my container running Postgres, connected, ran the query, and did `\d` to verify things looked as expected.


### Shell Script for Porting Data:

Not wanting to hand-write the shell script with potentially the biggest hurdle ahead of me, I gave Claude LOTS of comments/context for how this script should work, what its strict requirements were, and what it should NOT do. I read through the output, made some corrections, and was satisfied with the approach.

(Barring the concern about getting past the biggest hurdle, I could have slowed down here a bit and handwritten a simpler script. I do not love how verbose and arcane AI shell scripts can be.)

I made sure the script only did a small subset of the data first, so I could get a feel for the speed. I feel that it is generally a good move to do things like this in small chunks, inspect that small part, and only then proceed to the whole thing. I also verified that my instructions on HOW to port the data were attended to, so we weren't paying a bunch of network or file-I/O overhead we didn't need to.

I ran my testing subset first, did some from-the-hip math, and thought my total migration time was going to be reasonable. I also checked the resulting rows in my newly created `drive_stats` table to make sure things looked OK. Being OK with the result of the subset and the extrapolated time it would take, I went ahead with the full port. 

The full port from CSVs to DB took ~5 min. This could likely have been faster yet along a few axes:

- Being pickier about how many threads the shell script used (I just picked 6, rather from-the-hip)
- Making the CSVs into one super file to copy from, so there is less overhead cost from running the commands for each file (I would have to drill down on this one a bit more though, honestly)
- Being pickier about the exact shell logic for `docker exec` and looping. Likely some optimizations to be had there.

After the full port, I verified that `select count(*) from drive_stats;` turned up the EXACT same row count as my CSV files did (minus the headers of course). It checked out. I also spot-checked a few records for accuracy and data-loss (`cat, head | grep` vs `SELECT`). I then ran my post-port script at `data/setup/4_postPortDB.sql`, where I set the table to `LOGGED`, ran `ANALYZE` so that the query planner had data to go off of, created my `P_KEY`, and started thinking about indexing.

## How I Made the Queries Fast:

At this stage, I had my Postgres instance running (container), and my data ported over and put into a satisfactory table. I was now focused on what I saw as the second big bottleneck: the `R` in CRUD:

- The big `GROUP BY` and
```sql
SELECT 
    ...
FROM drive_stats
WHERE model = 'X'
AND date = 'Y';
```

I thought that I wanted a `MATERIALIZED VIEW` here. I think the ideal version of this solution would involve a way to *update* the rollup, considering that there are CREATE endpoints, but I decided this was the best hybrid of expedient and performant solutions I had up my sleeve. 

(I talk about seeing [TimescaleDB for this kind of thing](https://www.tigerdata.com/blog/materialized-views-the-timescale-way), but I didn't want to overcomplicate things given the scope of the assignment.)

I knew these would be very slow, especially the first. I decided to think through the `GROUP BY` and write it out. I wrote it out and ran into a small mistake with dividing `failures`, but otherwise the math worked out there, slightly altered from my initial "Drive years" formula. 

(Technically, the `COALESCE`s in `CREATE MATERIALIZED VIEW drive_rollup` are not really needed, but since I had nullable columns, I think that is OK. It comes out the same for my purposes here to just grab the first not null value.)


I put `\timing on` and started to benchmark some queries. I decided on indexes by thinking about what data those queries were going to be asking about, deciding on:
```sql
--- Read for "Query by model", endpoint is probably going to say "Get me limit rows where model = X and date = Y"
CREATE INDEX drive_stats_model_date_idx ON drive_stats (model, date);


--- For the GB, we need to think about model and failure
CREATE INDEX drive_stats_model_failure_idx ON drive_stats (model, failure);
```

I recorded times before/after these indexes and used `EXPLAIN ANALYZE` to prove they were being used.

My times before and after and the associated queries can be found in `data/setup/5_benchmarkQueries.sql` but I will repeat the results here:

```sql
-- For Our Group BY ONCE 
-- Time before (creating the MATVIEW): Time: 242504.207 ms 
-- Time to CREATE the MATVIEW: (04:02.504) Time: 262963.146 ms (04:22.963)
-- Time After (querying the MAT VIEW itself): Time: 3.001 ms
CREATE MATERIALIZED VIEW drive_rollup AS
..
FROM drive_stats
GROUP BY model;
```


```sql
-- For the "query by model + date" read path, served by drive_stats_model_date_idx
-- (this is what I benchmarked; the endpoint itself now keys on serial_number + date,
--  which the primary key already covers)
-- Time before (time before index):  Time: 37034.929 ms (00:37.035)
-- Time After (time after index): Time: 54.350 ms
SELECT 
    ...
FROM drive_stats
WHERE model = 'X'
AND date = 'Y';
```

- Rollup / materialized view
242504.207 ms → 3.001 ms = ~80,800× faster (4 minutes → 3 ms)

- `model + date` read path index (`drive_stats_model_date_idx`)
37034.929 ms → 54.350 ms = ~681× faster (37 s → 54 ms, 36.98 s saved per query)

(This was not actually the right query to be testing. It should have been `serial_number + date` already indexed with the private key, but this could reasonably have been an endpoint with `limit/offset` later.)

Of course, more rigorous testing could have been done here, but I was satisfied for now with the API-server's work ahead of me. Additionally, it is worth noting that the `MATERIALIZED VIEW` solution could be accused of throwing the slowness out the front door only to have it crawl back in through the window. We still need to `REFRESH` that view and have a `UNIQUE INDEX` that allows that to happen `CONCURRENTLY`. 

(That is where I thought of either a goroutine solution that runs that on a `Ticker` or something like a timed-trigger with TimescaleDB.)


## How I Built the API-server:

I began by scaffolding the project. I had some boilerplate API-server code sitting around from some recent brushing up on Golang. Given the choice between having an LLM generate code and refactoring off of a boilerplate, I would rather go with the boilerplate because I wrote it and know how it works. Generating it from scratch either requires lots of supervision or runs the risk of having the code quickly become unwieldy. 

I knew this would be a standard CRUD API-server with only the potential addition of a background job that did `REFRESH MATERIALIZED VIEW`, though I judged that to be out of scope for the time-window or for the very end.

### Scaffolding and Structs/Schema:

I set up 
```
cmd/
    config.go
    handlers.go
    main.go
    routes.go
data/
    models.go
    queries.go
```
and made sure a `"Hello, World!"` endpoint worked and that the server could connect to my DB.

From here, I could start making structs (one for the connection and one for the data structure/JSON) that reflect the DB. I could probably have used a smoother tech here instead of hand-rolling these and having Claude help. For example, [sqlx](https://github.com/jmoiron/sqlx) can make your structs straight off the DB. That would have been better, but this worked for now.

### Building out the Endpoints:

As I built out my CRUD endpoints I made sure to test each manually one-by-one, leaving a `curl` alongside them in `routes.go`. I acknowledge that this is absolutely not a scalable workflow. Something like Postman or actual Go tests would be much better, but I opted for `curl` here as it was quick and cheap.

```go
mux.Post("/drive_stats", app.CreateDriveStatsHandler)
mux.Get("/rollup_stats", app.ReadRollupStatsHandler)
mux.Get("/drive_stats/{serial_number}/{date}", app.ReadDriveStatsBySerialAndDateHandler)
mux.Put("/drive_stats", app.UpdateDriveStatsHandler)
mux.Delete("/drive_stats/{serial_number}/{date}", app.DeleteDriveStatsHandler)
```

There were some slight hiccups with `date/string` formats which made some of these endpoints created on the fly a little annoying to work with, as they require specific picky formats. This is an acknowledged flaw but not difficult to clean up later.

It should be noted that Create, Update, and Delete likely don't make a ton of sense in this context, but I was rolling with it for the sake of the exercise.

### Testing all the Endpoints:

I focused mostly on the efficiency of the queries for these,
```go
mux.Get("/rollup_stats", app.ReadRollupStatsHandler)
mux.Get("/drive_stats/{serial_number}/{date}", app.ReadDriveStatsBySerialAndDateHandler)
```
knowing that the rest were not likely as demanding. They have acceptable response times but could probably use more love.

I created `test.sh` with Claude near the end to ensure that all my `curl`s worked in a reasonable order/workflow, though these tests are likely less than perfect. Just an OK sanity check, as I had only been running them one-by-one.


# Reflections on the Problem:

Overall, I feel that I did well balancing the scope of the problem with doing it in one sit-down. In the moment, I felt pressure to overcome some big potential show-stoppers, and that was certainly shown out in my approach. 

Easy to say in retrospect, but there were places I could have probably slowed down and made things better/faster and still had a good completion-time.

## What Went Well:

I was happy with completing everything end-to-end in a reasonable time without too extensive a usage of AI tools. It was also good that nothing really snagged me or held me down, problem-solving wise, but I did make notable sacrifices to move quickly while covering the bases.


## Where There Was Room for Improvement:
I will list, in no particular order, things about the *execution* here that I think could be improved upon, saving the actual code/DB changes that require improvement for the next section.

- Better scrutiny of the data post-download (full Python script(s) for data consistency)
- Better schema/data-type selection and creation. These were not optimal and they could have been better.
- Doing a bit more digging on `smart_*` columns. 
- I could have simplified my math out of the gate for AFR 
- Some of the queries could have been drilled down on deeper even after a few of the optimizations.
- I could have just started with something like TimescaleDB out of the gate?
- I could have made one large file of CSVs most likely
- I could probably have just handwritten 90% of the bash script for porting, though it would have been slower
- There were some hiccups with date strings and URL-params vs request-bodies in my initial implementation of some endpoints. These could have been done more cleanly.
- I accidentally made an endpoint that didn't make sense and returned and arbitrary row (now fixed). It was `GET /drive_stats/{model}/{date}` and I changed it to `GET /drive_stats/{serial_number}/{date}`. This was a mistake, confusing my primary key from `serial_number + date` to `model + date`.


# What I Would Do Going Forward:
This codebase and DB have issues, no doubt. Being created in one sitting, that is expected. Here I will acknowledge some of the things I would fix, were I to turn more attention to it:
(Some of these are already recorded in the doc I was using as I went along, `challenge-and-in-moment-thought-process.md`.)

- Actually scriptify the port-to-db process and DB setup. Right now it is not a seamless "push-button" deploy, as I envisioned it might be. This would involve changing/rewriting a few of the scripts.
- Fix the date format issues in the API so that requests are friendlier to make without errors. This can be handled by some packages or simple error handling that standardizes the date strings coming in.
- I could think about giving the rows IDs that are hashes of `serial_number + date` so things are overall cleaner on the backend. Having a composite primary key is fine, but I don't *love* that design. This is debatable.
- We should use some library for controlled queries. Though the incoming user data is typed, this could be stronger. Queries are parameterized though so its not a huge deal.
- The overall error-handling stance here is weak, just inherited from boilerplate code.
- We can `REFRESH MATERIALIZED VIEW CONCURRENTLY drive_rollup;` in the background with a goroutine to keep the rollup up to date.
    - A redesign here, as stated above, might consider a DB or extension that can do a *TIMED* `REFRESH MATERIALIZED VIEW CONCURRENTLY drive_rollup;`
    - TimescaleDB is capable of this, it seems.
- There are no middlewares here except a simple recover.
- I could have more/better endpoints to query the rollup. For example, for one model, or over a specific date range. We could have different rollups potentially as well. Maybe for quarters, years, and so on.
- This repo could have actual Golang tests for the API, not just a curl shell script.
- I didn't really scrutinize the speed of the C, U, and D queries, but we could have done that. These aren't the big issues here as of now.