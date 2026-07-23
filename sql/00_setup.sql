/* =============================================================================
   00_setup.sql — Schema definition, load, and indexing
   Dialect: MySQL 8.0
   -----------------------------------------------------------------------------
   Run this first. It creates the database, defines the two source tables,
   loads the raw CSVs, and adds the indexes the analytical queries rely on.
   ============================================================================= */

CREATE DATABASE IF NOT EXISTS bixi;
USE bixi;

-- -----------------------------------------------------------------------------
-- Stations dimension: one row per docking station
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS stations;
CREATE TABLE stations (
    code      INT           NOT NULL,
    name      VARCHAR(100)  NOT NULL,
    latitude  DECIMAL(9,6)  NOT NULL,
    longitude DECIMAL(9,6)  NOT NULL,
    PRIMARY KEY (code)
) ENGINE = InnoDB;

-- -----------------------------------------------------------------------------
-- Trips fact: one row per bike trip (~8.6M rows across 2016-2017)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS trips;
CREATE TABLE trips (
    id                 INT       NOT NULL AUTO_INCREMENT,
    start_date         DATETIME  NOT NULL,
    start_station_code INT       NOT NULL,
    end_date           DATETIME  NOT NULL,
    end_station_code   INT       NOT NULL,
    duration_sec       INT       NOT NULL,
    is_member          TINYINT   NOT NULL,   -- 1 = annual member, 0 = casual user
    PRIMARY KEY (id)
) ENGINE = InnoDB;

-- -----------------------------------------------------------------------------
-- Load (adjust paths; requires local_infile=1)
-- -----------------------------------------------------------------------------
-- LOAD DATA LOCAL INFILE 'data/stations.csv'
--     INTO TABLE stations
--     FIELDS TERMINATED BY ',' ENCLOSED BY '"'
--     LINES TERMINATED BY '\n' IGNORE 1 ROWS
--     (code, name, latitude, longitude);
--
-- LOAD DATA LOCAL INFILE 'data/trips.csv'
--     INTO TABLE trips
--     FIELDS TERMINATED BY ',' ENCLOSED BY '"'
--     LINES TERMINATED BY '\n' IGNORE 1 ROWS
--     (start_date, start_station_code, end_date, end_station_code,
--      duration_sec, is_member);

-- -----------------------------------------------------------------------------
-- Indexes
-- -----------------------------------------------------------------------------
-- Every query in this project filters or groups on start_date, and most join
-- back to stations on one of the two station codes. Without these, the monthly
-- aggregations do full table scans over ~8.6M rows.
CREATE INDEX idx_trips_start_date    ON trips (start_date);
CREATE INDEX idx_trips_start_station ON trips (start_station_code);
CREATE INDEX idx_trips_end_station   ON trips (end_station_code);

-- Covering index for the membership-by-month queries: lets MySQL answer them
-- from the index alone without touching the table rows.
CREATE INDEX idx_trips_date_member   ON trips (start_date, is_member);

-- -----------------------------------------------------------------------------
-- Sanity checks — run these before trusting any downstream numbers
-- -----------------------------------------------------------------------------
-- Row counts and date coverage
SELECT
    COUNT(*)              AS total_rows,
    MIN(start_date)       AS first_trip,
    MAX(start_date)       AS last_trip,
    COUNT(DISTINCT DATE(start_date)) AS distinct_days
FROM trips;

-- Referential integrity: are there trips pointing at stations that don't exist?
SELECT COUNT(*) AS orphan_start_codes
FROM trips t
LEFT JOIN stations s ON s.code = t.start_station_code
WHERE s.code IS NULL;

-- Duration outliers: negative or absurdly long trips distort every average
SELECT
    SUM(duration_sec <= 0)     AS non_positive_durations,
    SUM(duration_sec > 86400)  AS over_24_hours,
    ROUND(AVG(duration_sec)/60, 2) AS mean_minutes,
    ROUND(MAX(duration_sec)/60, 2) AS max_minutes
FROM trips;
