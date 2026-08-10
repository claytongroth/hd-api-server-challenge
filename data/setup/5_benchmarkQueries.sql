\timing on

EXPLAIN ANALYZE



-- For Our GET /drive_stats/{model}/{date} endpoint
-- Time before (time before index):  Time: 37034.929 ms (00:37.035)
-- Time After (time after index): Time: 54.350 ms
SELECT 
    date,
    serial_number,
    model,
    capacity_bytes,
    failure,
    datacenter,
    cluster_id,
    vault_id,
    pod_id,
    pod_slot_num,
    is_legacy_format
FROM drive_stats
WHERE model = 'CT250MX500SSD1'
AND date = '2025-10-01';


-- For Our Group BY ONCE 
-- Time before (creating the MATVIEW): Time: 242504.207 ms 
-- Time to CREATE the MATVIEW: (04:02.504) Time: 262963.146 ms (04:22.963)
-- Time After (querying the MAT VIEW itself): Time: 3.001 ms
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



-- Time before: 
-- Time After:



-- Time before: 
-- Time After: