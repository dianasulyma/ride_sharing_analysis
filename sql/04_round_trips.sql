/* 
   04_round_trips.sql — Round trips as a leisure-use signal
*/

USE bixi;


-- Q1. Round-trip counts and rates per station

WITH station_trips AS (
    SELECT
        s.code,
        s.name,
        COUNT(*)                                       AS total_starting_trips,
        SUM(t.start_station_code = t.end_station_code) AS round_trips

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


-- Q2. Leisure-skewed stations: volume floor plus rate threshold

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

-- Q3. Do round trips actually look like leisure trips?

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
