-- Bootstrap for blocky's query log hypertable.
--
-- Runs before blocky first connects. Pre-creating the table is the only way to
-- control chunk_time_interval from day one: blocky's GORM AutoMigrate then finds
-- the table already correct, and its create_hypertable(if_not_exists => TRUE)
-- no-ops.
--
-- Must be idempotent - it re-runs whenever this file changes.

-- Also declared on the Database CR; repeated here so the job is self-sufficient
-- and does not race the CR's reconcile. timescaledb.control is trusted, so the
-- database owner can do this without superuser.
CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE EXTENSION IF NOT EXISTS timescaledb_toolkit;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Column set and types must match blocky's querylog.logEntry struct exactly, or
-- AutoMigrate will try to alter the table on startup. Note the column is
-- effective_tldp, NOT effective_tldp1. With type: timescale blocky adds no id
-- column (the bigserial PK is postgresql-only), so there is no primary key.
CREATE TABLE IF NOT EXISTS log_entries (
    request_ts     timestamptz NOT NULL,
    client_ip      text,
    client_name    text,
    duration_ms    bigint,
    reason         text,
    response_type  text,
    question_type  text,
    question_name  text,
    effective_tldp text,
    answer         text,
    response_code  text,
    hostname       text
);

-- 1-day chunks: at household volume this keeps the actively-ingested chunk's
-- indexes well inside shared_buffers, and 90-day retention lands at ~90 chunks.
-- migrate_data covers the case where blocky won the race and already inserted.
SELECT create_hypertable(
    'log_entries',
    by_range('request_ts', INTERVAL '1 day'),
    migrate_data  => TRUE,
    if_not_exists => TRUE
);

-- segmentby = client_name: compression packs up to 1000 rows per segment value
-- per chunk, and a household has 10-60 clients - low cardinality AND the column
-- dashboards filter on. question_name would be catastrophic here (10k+ distinct
-- values a day, so ~10 rows per segment).
ALTER TABLE log_entries SET (
    timescaledb.enable_columnstore = true,
    timescaledb.segmentby          = 'client_name',
    timescaledb.orderby            = 'request_ts DESC'
);

-- after => 2 days, not 1: keeps a whole chunk in the rowstore so blocky's
-- inserts and any "last 24h" panel never touch compressed data. Blocky only
-- ever inserts at now(), so decompression never triggers.
CALL add_columnstore_policy('log_entries', after => INTERVAL '2 days', if_not_exists => TRUE);

-- Blocky indexes only request_ts, client_name and response_type, so grouping by
-- question_name or effective_tldp is a sequential scan. AutoMigrate will not
-- drop these.
CREATE INDEX IF NOT EXISTS le_client_ts ON log_entries (client_name, request_ts DESC);
CREATE INDEX IF NOT EXISTS le_rtype_ts ON log_entries (response_type, request_ts DESC);
CREATE INDEX IF NOT EXISTS le_qname_ts ON log_entries (question_name, request_ts DESC);
CREATE INDEX IF NOT EXISTS le_etld_ts ON log_entries (effective_tldp, request_ts DESC);

-- Substring search on question_name for the dashboard's free-text filter.
CREATE INDEX IF NOT EXISTS le_qname_trgm ON log_entries USING gin (question_name gin_trgm_ops);

-- Retention is left to blocky, which issues add_retention_policy() itself from
-- logRetentionDays. Only one policy per hypertable is allowed, and blocky's
-- if_not_exists => TRUE would silently no-op over one created here without
-- correcting it - so there is exactly one owner of that setting.

-- A continuous aggregate's bucket width cannot be ALTERed, and
-- CREATE ... IF NOT EXISTS would silently skip an existing view - so the
-- 1-hour aggregates this replaces have to be dropped outright. Inert once
-- they are gone. CASCADE also removes their refresh and columnstore policies.
DROP MATERIALIZED VIEW IF EXISTS dns_hourly_by_client CASCADE;
DROP MATERIALIZED VIEW IF EXISTS dns_hourly_by_domain CASCADE;
DROP MATERIALIZED VIEW IF EXISTS dns_hourly_client_domain CASCADE;

-- materialized_only = false is set explicitly at every level: it defaults to
-- TRUE since Timescale 2.13, and a TRUE level is a barrier that costs
-- everything above it the real-time tail.
--
-- Carry sum_ms and n_ms rather than avg(): an average cannot be rolled up into
-- a daily aggregate.
CREATE MATERIALIZED VIEW IF NOT EXISTS dns_10m_by_client
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT time_bucket(INTERVAL '10 minutes', request_ts) AS bucket,
       client_name,
       count(*)                                                          AS queries,
       count(*) FILTER (WHERE response_type = 'BLOCKED')                 AS blocked,
       count(*) FILTER (WHERE response_type = 'CACHED')                  AS cached,
       count(*) FILTER (WHERE response_type NOT IN ('BLOCKED', 'CACHED')) AS resolved,
       count(*) FILTER (WHERE response_code = 'NXDOMAIN')                AS nxdomain,
       sum(duration_ms)                                                  AS sum_ms,
       count(duration_ms)                                                AS n_ms,
       max(duration_ms)                                                  AS max_ms
FROM log_entries
GROUP BY bucket, client_name
WITH NO DATA;

-- start_offset must stay well inside the raw retention window: if a refresh
-- covers chunks already dropped, the refresh recomputes them as empty and
-- DELETES the aggregate rows. 3 days against 90 is safe.
-- end_offset is two buckets rather than one, so a refresh only ever
-- materialises complete buckets. Freshness does not depend on it -
-- materialized_only = false computes the unmaterialised tail on read.
SELECT add_continuous_aggregate_policy('dns_10m_by_client',
    start_offset      => INTERVAL '3 days',
    end_offset        => INTERVAL '20 minutes',
    schedule_interval => INTERVAL '10 minutes',
    if_not_exists     => TRUE);

-- eTLD+1 rollup. This is the column no log store can compute - it is the
-- public-suffix-correct registrable domain, and the reason the query log lives
-- in SQL rather than in VictoriaLogs.
CREATE MATERIALIZED VIEW IF NOT EXISTS dns_10m_by_domain
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT time_bucket(INTERVAL '10 minutes', request_ts) AS bucket,
       effective_tldp,
       response_type,
       count(*) AS queries
FROM log_entries
GROUP BY bucket, effective_tldp, response_type
WITH NO DATA;

SELECT add_continuous_aggregate_policy('dns_10m_by_domain',
    start_offset      => INTERVAL '3 days',
    end_offset        => INTERVAL '20 minutes',
    schedule_interval => INTERVAL '10 minutes',
    if_not_exists     => TRUE);

-- Per-client, per-domain pairing for the "which client talks to which company"
-- view, plus HLL sketches so distinct-domain counts roll up over arbitrary
-- windows without rescanning raw data.
CREATE MATERIALIZED VIEW IF NOT EXISTS dns_10m_client_domain
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT time_bucket(INTERVAL '10 minutes', request_ts) AS bucket,
       client_name,
       effective_tldp,
       count(*)                              AS queries,
       count(*) FILTER (WHERE response_type = 'BLOCKED') AS blocked
FROM log_entries
GROUP BY bucket, client_name, effective_tldp
WITH NO DATA;

SELECT add_continuous_aggregate_policy('dns_10m_client_domain',
    start_offset      => INTERVAL '3 days',
    end_offset        => INTERVAL '20 minutes',
    schedule_interval => INTERVAL '10 minutes',
    if_not_exists     => TRUE);

-- The hourly aggregates are hypertables themselves, so compress them too.
-- Needs an existing refresh policy first, hence the ordering above.
ALTER MATERIALIZED VIEW dns_10m_by_client SET (
    timescaledb.enable_columnstore = true,
    timescaledb.segmentby          = 'client_name',
    timescaledb.orderby            = 'bucket DESC'
);
CALL add_columnstore_policy('dns_10m_by_client', after => INTERVAL '30 days', if_not_exists => TRUE);

ALTER MATERIALIZED VIEW dns_10m_client_domain SET (
    timescaledb.enable_columnstore = true,
    timescaledb.segmentby          = 'client_name',
    timescaledb.orderby            = 'bucket DESC'
);
CALL add_columnstore_policy('dns_10m_client_domain', after => INTERVAL '30 days', if_not_exists => TRUE);

-- Read-only grants for the Grafana datasource and blocky-ui. The role itself is
-- declared on the Cluster (spec.managed.roles) so CNPG owns its password; only
-- the privileges live here, because the Job connects as the database owner.
--
-- If this errors with "role blocky_ro does not exist" the Job simply retries -
-- managed.roles reconciles moments after the Cluster reports Ready.
GRANT CONNECT ON DATABASE blocky TO blocky_ro;
GRANT USAGE ON SCHEMA public TO blocky_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO blocky_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO blocky_ro;
