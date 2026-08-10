-- SEt back to Logged
ALTER TABLE drive_stats SET LOGGED;
-- Time: 364322.058 ms (06:04.322)


-- Put Primary Key
ALTER TABLE drive_stats ADD PRIMARY KEY (serial_number, date);


-- Create Indexes 

--- Read for "Qyery by model", endpoint is probably going to say "Get me limit rows where model = X and date = Y"
CREATE INDEX drive_stats_model_date_idx ON drive_stats (model, date);


--- For the GB, we need to think about model and failure
CREATE INDEX drive_stats_model_failure_idx ON drive_stats (model, failure);



--- Analyze
ANALYZE drive_stats;
-- Time: 4562.433 ms (00:04.562)


--- Create our Materialized View
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


-- We need a unique index so we can run a refresh concurrently
CREATE UNIQUE INDEX drive_rollup_model_idx ON drive_rollup (model);


-- Now we can run a refresh concurrently
REFRESH MATERIALIZED VIEW CONCURRENTLY drive_rollup;