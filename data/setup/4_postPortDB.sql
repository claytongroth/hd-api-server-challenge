-- SEt back to Logged
ALTER TABLE drive_stats SET LOGGED;
-- Time: 364322.058 ms (06:04.322)


-- Put Primary Key
ALTER TABLE drive_stats ADD PRIMARY KEY (serial_number, date);


-- Create Indexes 

--- For reads keyed on model + date ("get me the rows where model = X and date = Y").
--- The single drive-day read (serial_number + date) is already covered by the primary key.
CREATE INDEX drive_stats_model_date_idx ON drive_stats (model, date);


--- For the GB, we need to think about model and failure
CREATE INDEX drive_stats_model_failure_idx ON drive_stats (model, failure);



--- Analyze
ANALYZE drive_stats;
-- Time: 4562.433 ms (00:04.562)


--- Track when drive_stats last changed, so the API can skip pointless refreshes
-- Created here, AFTER the bulk load.
DROP TABLE IF EXISTS drive_stats_change;
CREATE TABLE drive_stats_change (
    source_table text PRIMARY KEY,
    changed_at   timestamptz NOT NULL DEFAULT now()
);
INSERT INTO drive_stats_change (source_table) VALUES ('drive_stats');

CREATE OR REPLACE FUNCTION note_drive_stats_change() RETURNS trigger AS $$
BEGIN
    UPDATE drive_stats_change
       SET changed_at = now()
     WHERE source_table = 'drive_stats';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- FOR EACH STATEMENT, not FOR EACH ROW: one cheap update per write statement
-- no matter how many rows it touched.
CREATE TRIGGER drive_stats_changed
AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON drive_stats
FOR EACH STATEMENT EXECUTE FUNCTION note_drive_stats_change();


--- Create our Materialized View
-- COALESCE here is cheap insurance against NULL failure values
-- Not strictly necessary, especially if we had better not NULL constraints
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
        AS annualized_failure_rate_pct,
    -- the source watermark this view was built from. Read in the same snapshot
    -- as the aggregate, so the two can never disagree.
    (SELECT changed_at FROM drive_stats_change
      WHERE source_table = 'drive_stats') AS source_changed_at
FROM drive_stats
GROUP BY model;


-- We need a unique index so we can run a refresh concurrently
CREATE UNIQUE INDEX drive_rollup_model_idx ON drive_rollup (model);


-- Deliberately not refreshing here: CREATE MATERIALIZED VIEW above already
-- populated the view (WITH DATA is the default), so this would just redo the
-- whole ~4 min aggregate for nothing. The unique index is what the API's
-- periodic CONCURRENTLY refreshes need.
-- REFRESH MATERIALIZED VIEW CONCURRENTLY drive_rollup;