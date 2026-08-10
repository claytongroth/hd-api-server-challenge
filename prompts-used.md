# Prompts Used

## Docker Compose

Make me a docker compose file for a minimal Go API-server in ./hd-api-server (slim Dockerfile) and a postgres DB as well.

The postgres part of the docker-compose should be simple but designed so that ./data/csv_data is bind mounted and the container can access it. We will need to port a lot of data from CSVs into the DB and dont want to cross the network to do so.

(dont run anything just give the dockerfile and docker-compose.yml)

#### Follow-up:
Can we simplify the command a bit to only the most impactful stuff and stay mopstly on defaults. Also please use default postgres username and password for now.

Please update the DATABASE_URL accordingly


## Help with Shell script to port data

The shell script should be very simple and follow the commented instructions, with lots of logs and timestamps for each file. It should fail if any file fails the copy.

It should include a commented header for how to run it with testing on/off.

HARD REQUIREMENT: 
- We are not copying data to the container, we are reading from the bind mount
- We are not doign COPY FROM STDIN or anything other than straigt-forward COPY FROM

(please do not run, just get the script ready)

Lets make one change here to make this COPY FROM run in parallel so we do a few files at a time with `xargs -P`

with 4 default thredas and make threads configurable




## Help with Bash command for total lines in all files in pwd
bash command for total lines in all files in pwd



## Help sanity check materialized view
CREATE MATERIALIZED VIEW drive_rollup AS
SELECT
    model,
    COUNT(*) AS drive_days,
    COUNT(DISTINCT serial_number) AS drives,
    SUM(failure) AS drive_failures,
    SUM(failure) / COUNT(*) AS naive_failure_rate,
    ROUND(SUM(failure)/(COUNT(*)/365), 3) AS annualized_failure_rate
FROM drive_stats
GROUP BY model;

Can you ensure that no data types are not going to cooperate here with my failure rate metrics?




## DB to structs:
Help fill in these structs matching our data's shape:

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
    ... (skip the smart columns)
)

and for the Rollup struct:
CREATE MATERIALIZED VIEW drive_rollup AS
SELECT
    model,
    COUNT(*)                       AS drive_days,
    COUNT(DISTINCT serial_number)  AS drives,
    COALESCE(SUM(failure), 0)      AS drive_failures,
    ROUND(COALESCE(SUM(failure), 0)::numeric / COUNT(*), 9)
        AS naive_failure_rate,
    ROUND(COALESCE(SUM(failure), 0)::numeric * 365 / COUNT(*), 6)
        AS annualized_failure_rate,
    ROUND(COALESCE(SUM(failure), 0)::numeric * 36500 / COUNT(*), 3)
        AS annualized_failure_rate_pct
FROM drive_stats
GROUP BY model;



## Format my Curl
Can you please fix this curl request to break ontl multiple lines and have proper JSON format:

	// CREATE
	/*
		curl -X POST -H "Content-Type: application/json" -d '{"date":"2025-10-01","serial_number":"1231123123123","model":"FAKEMODEL","capacity_bytes":-1,"failure":0,"datacenter":"DC1","cluster_id":"CL1","vault_id":"VA1","pod_id":"POD1","pod_slot_num":"SLOT1","is_legacy_format":false}' http://localhost:8080/drive_stats
	*/
	mux.Post("/drive_stats", app.CreateDriveStatsHandler)

➜  csv_data git:(main) ✗                curl -X POST -H "Content-Type: application/json" -d '{"date":"2025-10-01","serial_number":"1231123123123","model":"FAKEMODEL","capacity_bytes":-1,"failure":0,"datacenter":"DC1","cluster_id":"CL1","vault_id":"VA1","pod_id":"POD1","pod_slot_num":"SLOT1","is_legacy_format":false}' http://localhost:8080/drive_stats

invalid JSON body



## Debugging create endpoint
➜  csv_data git:(main) ✗                curl -X POST http://localhost:8080/drive_stats \
                -H "Content-Type: application/json" \
                -d '{
                                "date": "2025-10-01T00:00:00Z",
                                "serial_number": "1111231123123123",
                                "model": "FAKEMODEL",
                                "capacity_bytes": -1,
                                "failure": 0,
                                "datacenter": "DC1",
                                "cluster_id": "CL1",
                                "vault_id": "VA1",
                                "pod_id": "POD1",
                                "pod_slot_num": "SLOT1",
                                "is_legacy_format": false
                        }'
Internal Server Error


Can you please fix this curl request to break ontl multiple lines and have proper JSON format:

	// CREATE
	/*
		curl -X POST -H "Content-Type: application/json" -d '{"date":"2025-10-01","serial_number":"1231123123123","model":"FAKEMODEL","capacity_bytes":-1,"failure":0,"datacenter":"DC1","cluster_id":"CL1","vault_id":"VA1","pod_id":"POD1","pod_slot_num":"SLOT1","is_legacy_format":false}' http://localhost:8080/drive_stats
	*/
	mux.Post("/drive_stats", app.CreateDriveStatsHandler)

➜  csv_data git:(main) ✗                curl -X POST -H "Content-Type: application/json" -d '{"date":"2025-10-01","serial_number":"1231123123123","model":"FAKEMODEL","capacity_bytes":-1,"failure":0,"datacenter":"DC1","cluster_id":"CL1","vault_id":"VA1","pod_id":"POD1","pod_slot_num":"SLOT1","is_legacy_format":false}' http://localhost:8080/drive_stats

invalid JSON body




## Help assembling a chain of Curls that tests all APIs
Please assemble a chain of Curls that tests all APIs with a logical sequence that does all the gets, creates, updates, and deletes, cleaning up the crap records it creates.

Please save this to `hd-api-server-challenge/test.sh`  

