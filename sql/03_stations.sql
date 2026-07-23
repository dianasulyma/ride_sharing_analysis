/* =============================================================================
   03_stations.sql — Station-level demand and flow
   -----------------------------------------------------------------------------
   Business question: which stations carry the load, and where does the system
   run out of balance? Feeds the Tableau station maps.
   ============================================================================= */

USE bixi;

-- -----------------------------------------------------------------------------
-- Q1. Top 5 origin stations
-- -----------------------------------------------------------------------------
-- INNER JOIN, not RIGHT JOIN. The original used RIGHT JOIN with stations on the
-- left, which reads as "keep all trips" — but grouping by stations.name then
-- collapses any unmatched trips into a single NULL-named row. If the intent is
-- to surface orphaned station codes, that belongs in the setup sanity checks,
-- not silently inside a top-N ranking.
SELECT
    s.name          AS station_name,
    COUNT(*)        AS trips_started
FROM trips t
JOIN stations s ON s.code = t.start_station_code
GROUP BY s.code, s.name
ORDER BY trips_started DESC
LIMIT 5;

-- -----------------------------------------------------------------------------
-- Q2. Full station ranking with cumulative share
-- -----------------------------------------------------------------------------
-- Shows how concentrated demand is: if the top 10% of stations carry half the
-- trips, rebalancing effort should be targeted rather than uniform.
WITH station_volume AS (
    SELECT
        s.code,
        s.name,
        COUNT(*) AS trips_started
    FROM trips t
    JOIN stations s ON s.code = t.start_station_code
    GROUP BY s.code, s.name
)
SELECT
    name AS station_name,
    trips_started,
    RANK() OVER (ORDER BY trips_started DESC) AS volume_rank,
    ROUND(100.0 * trips_started / SUM(trips_started) OVER (), 3) AS pct_of_all_trips,
    ROUND(
        100.0 * SUM(trips_started) OVER (ORDER BY trips_started DESC)
              / SUM(trips_started) OVER (),
        2
    ) AS cumulative_pct
FROM station_volume
ORDER BY trips_started DESC;

-- -----------------------------------------------------------------------------
-- Q3. Time-of-day flow profile for a station
-- -----------------------------------------------------------------------------
-- The original ran six near-identical queries (morning/afternoon/evening
-- x starts/ends) and recorded each result in a comment. One conditional
-- aggregation returns the same information as a single readable result set,
-- and adds the net flow column that actually answers the question.
--
-- Net flow is the operational signal: persistently negative means the station
-- empties out and needs bikes trucked in.
SELECT
    s.name AS station_name,
    SUM(CASE WHEN HOUR(t.start_date) BETWEEN  7 AND 11 THEN 1 ELSE 0 END) AS morning_starts,
    SUM(CASE WHEN HOUR(t.start_date) BETWEEN 12 AND 16 THEN 1 ELSE 0 END) AS afternoon_starts,
    SUM(CASE WHEN HOUR(t.start_date) BETWEEN 17 AND 21 THEN 1 ELSE 0 END) AS evening_starts
FROM trips t
JOIN stations s ON s.code = t.start_station_code
WHERE s.name LIKE 'Namur%'
GROUP BY s.code, s.name;

-- Departures and arrivals in one pass, via a union of the two directions.
-- Note the fix to the original: arrival buckets there were keyed on
-- HOUR(start_date), the departure timestamp, so an evening arrival from an
-- afternoon departure landed in the wrong bucket. Here arrivals use end_date.
WITH flows AS (
    SELECT start_station_code AS station_code, HOUR(start_date) AS hr,  1 AS departure, 0 AS arrival
    FROM trips
    UNION ALL
    SELECT end_station_code   AS station_code, HOUR(end_date)   AS hr,  0 AS departure, 1 AS arrival
    FROM trips
)
SELECT
    s.name AS station_name,
    CASE
        WHEN f.hr BETWEEN  7 AND 11 THEN 'Morning (07-11)'
        WHEN f.hr BETWEEN 12 AND 16 THEN 'Afternoon (12-16)'
        WHEN f.hr BETWEEN 17 AND 21 THEN 'Evening (17-21)'
        ELSE 'Off-peak'
    END AS time_block,
    SUM(f.departure)                  AS departures,
    SUM(f.arrival)                    AS arrivals,
    SUM(f.arrival) - SUM(f.departure) AS net_flow
FROM flows f
JOIN stations s ON s.code = f.station_code
WHERE s.name LIKE 'Namur%'
GROUP BY s.name, time_block
ORDER BY s.name, FIELD(time_block, 'Morning (07-11)', 'Afternoon (12-16)', 'Evening (17-21)', 'Off-peak');

-- -----------------------------------------------------------------------------
-- Q4. Station-level metrics for the Tableau map extract
-- -----------------------------------------------------------------------------
-- One row per station with coordinates and every measure the maps need, so
-- Tableau connects to a single clean result rather than blending three sheets.
SELECT
    s.code,
    s.name AS station_name,
    s.latitude,
    s.longitude,
    COUNT(t.id)                                        AS trips_started,
    ROUND(AVG(t.duration_sec) / 60.0, 3)               AS avg_duration_min,
    ROUND(100.0 * AVG(t.is_member), 2)                 AS pct_member_trips,
    SUM(t.start_station_code = t.end_station_code)     AS round_trips
FROM stations s
LEFT JOIN trips t ON t.start_station_code = s.code
GROUP BY s.code, s.name, s.latitude, s.longitude
ORDER BY trips_started DESC;
