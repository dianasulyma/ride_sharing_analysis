/* 
Station-level demand and flow
*/

USE bixi;


-- Q1. Top 5 origin stations

SELECT
    s.name          AS station_name,
    COUNT(*)        AS trips_started
FROM trips t
JOIN stations s ON s.code = t.start_station_code
GROUP BY s.code, s.name
ORDER BY trips_started DESC
LIMIT 5;


-- Q2. Full station ranking with cumulative share

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


-- Q3. Time-of-day flow profile for a station

SELECT
    s.name AS station_name,
    SUM(CASE WHEN HOUR(t.start_date) BETWEEN  7 AND 11 THEN 1 ELSE 0 END) AS morning_starts,
    SUM(CASE WHEN HOUR(t.start_date) BETWEEN 12 AND 16 THEN 1 ELSE 0 END) AS afternoon_starts,
    SUM(CASE WHEN HOUR(t.start_date) BETWEEN 17 AND 21 THEN 1 ELSE 0 END) AS evening_starts
FROM trips t
JOIN stations s ON s.code = t.start_station_code
WHERE s.name LIKE 'Namur%'
GROUP BY s.code, s.name;


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


-- Q4. Station-level metrics for the Tableau map extract

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
