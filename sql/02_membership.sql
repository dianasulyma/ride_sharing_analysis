/* 
Members vs. casual users
 */

USE bixi;


-- Q1. 2017 volume split by membership

SELECT
    CASE is_member WHEN 1 THEN 'Member' ELSE 'Casual' END AS segment,
    COUNT(*)                                              AS total_trips,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)    AS pct_of_trips
FROM trips
WHERE start_date >= '2017-01-01'
  AND start_date <  '2018-01-01'
GROUP BY is_member;


-- Q2. Member share of trips by month, 2017

SELECT
    MONTH(start_date)                    AS trip_month,
    COUNT(*)                             AS total_trips,
    SUM(is_member)                       AS member_trips,
    ROUND(100.0 * AVG(is_member), 2)     AS pct_member_trips
FROM trips
WHERE start_date >= '2017-01-01'
  AND start_date <  '2018-01-01'
GROUP BY MONTH(start_date)
ORDER BY trip_month;


-- Q3. Average trip duration by segment and month

SELECT
    YEAR(start_date)  AS trip_year,
    MONTH(start_date) AS trip_month,
    CASE is_member WHEN 1 THEN 'Member' ELSE 'Casual' END AS segment,
    COUNT(*)                           AS trips,
    ROUND(AVG(duration_sec) / 60.0, 2) AS mean_minutes,
    ROUND(MIN(duration_sec) / 60.0, 2) AS min_minutes,
    ROUND(MAX(duration_sec) / 60.0, 2) AS max_minutes
FROM trips
WHERE duration_sec BETWEEN 60 AND 86400
GROUP BY YEAR(start_date), MONTH(start_date), is_member
ORDER BY trip_year, trip_month, segment;


-- Q3b. Median duration by segment

WITH ranked AS (
    SELECT
        is_member,
        duration_sec,
        ROW_NUMBER() OVER (PARTITION BY is_member ORDER BY duration_sec) AS rn,
        COUNT(*)     OVER (PARTITION BY is_member)                       AS n
    FROM trips
    WHERE duration_sec BETWEEN 60 AND 86400
      AND start_date >= '2017-01-01'
      AND start_date <  '2018-01-01'
)
SELECT
    CASE is_member WHEN 1 THEN 'Member' ELSE 'Casual' END AS segment,
    ROUND(AVG(duration_sec) / 60.0, 2) AS median_minutes
FROM ranked
WHERE rn IN (FLOOR((n + 1) / 2), CEILING((n + 1) / 2))
GROUP BY is_member;


-- Q4. Weekday vs. weekend behaviour by segment

SELECT
    CASE is_member WHEN 1 THEN 'Member' ELSE 'Casual' END AS segment,
    CASE WHEN DAYOFWEEK(start_date) IN (1, 7) THEN 'Weekend' ELSE 'Weekday' END AS day_type,
    COUNT(*)                           AS trips,
    ROUND(AVG(duration_sec) / 60.0, 2) AS mean_minutes,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY is_member), 2
    ) AS pct_within_segment
FROM trips
WHERE start_date >= '2017-01-01'
  AND start_date <  '2018-01-01'
GROUP BY is_member, day_type
ORDER BY segment, day_type;
