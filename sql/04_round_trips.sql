/* =============================================================================
   04_round_trips.sql — Round trips as a leisure-use signal
   -----------------------------------------------------------------------------
   Business question: a trip returning to its origin station usually means the
   rider went somewhere and came back rather than commuting A-to-B. Stations
   with a high round-trip rate are leisure destinations, which is a different
   marketing and rebalancing problem from commuter stations.
   ============================================================================= */

USE bixi;

-- -----------------------------------------------------------------------------
-- Q1. Round-trip counts and rates per station
-- -----------------------------------------------------------------------------
-- The original ran this as three separate queries (raw counts, then fractions,
-- then the filtered list). One query with a reusable CTE covers all three.
--
-- SUM(a = b) exploits MySQL's boolean-to-integer coercion — equivalent to the
-- longer CASE WHEN form, and easier to read once you know the idiom. The CASE
-- version is kept in comments for portability to stricter dialects.
WITH station_trips AS (
    SELECT
        s.code,
        s.name,
        COUNT(*)                                       AS total_starting_trips,
        SUM(t.start_station_code = t.end_station_code) AS round_trips
        -- portable form:
        -- SUM(CASE WHEN t.start_station_code = t.end_station_code THEN 1 ELSE 0 END)
    FROM stations s
    JOIN trips t ON t.start_station_code = s.code
    GROUP BY s.code, s.name
)
SELECT
    name AS station_name,
    total_starting_trips,
    round_trips,
    ROUND(100.0 * round_trips / total_starting_trips, 2) AS pct_round_trips
FROM station_trips
ORDER BY round_trips DESC;

-- -----------------------------------------------------------------------------
-- Q2. Leisure-skewed stations: volume floor plus rate threshold
-- -----------------------------------------------------------------------------
-- Both conditions matter. Rate alone promotes tiny stations where three of
-- twelve trips happened to be round trips — noise, not signal. The 500-trip
-- floor is what makes the percentage trustworthy.
--
-- Filtering in an outer query rather than HAVING on a select-list alias: MySQL
-- permits alias references in HAVING, but that is a MySQL extension and breaks
-- on Postgres and SQL Server. Portable SQL is worth the extra nesting here.
WITH station_trips AS (
    SELECT
        s.code,
        s.name,
        COUNT(*)                                       AS total_starting_trips,
        SUM(t.start_station_code = t.end_station_code) AS round_trips
    FROM stations s
    JOIN trips t ON t.start_station_code = s.code
    GROUP BY s.code, s.name
),
station_rates AS (
    SELECT
        name AS station_name,
        total_starting_trips,
        round_trips,
        ROUND(100.0 * round_trips / total_starting_trips, 2) AS pct_round_trips
    FROM station_trips
    WHERE total_starting_trips >= 500
)
SELECT *
FROM station_rates
WHERE pct_round_trips >= 10
ORDER BY pct_round_trips DESC;

-- -----------------------------------------------------------------------------
-- Q3. Do round trips actually look like leisure trips?
-- -----------------------------------------------------------------------------
-- Testing the report's own interpretation rather than assuming it. If the
-- leisure reading holds, round trips should be longer, more weekend-weighted,
-- and more casual-user-driven than point-to-point trips.
SELECT
    CASE WHEN start_station_code = end_station_code
         THEN 'Round trip' ELSE 'Point to point' END AS trip_type,
    COUNT(*)                           AS trips,
    ROUND(AVG(duration_sec) / 60.0, 2) AS mean_minutes,
    ROUND(100.0 * AVG(is_member), 2)   AS pct_member,
    ROUND(100.0 * AVG(DAYOFWEEK(start_date) IN (1, 7)), 2) AS pct_weekend
FROM trips
WHERE duration_sec BETWEEN 60 AND 86400
GROUP BY trip_type;
