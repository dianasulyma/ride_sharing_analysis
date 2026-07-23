/* 
   How much is the system used, and when?

   Business question: is Bixi growing, and how does demand move across the
   season? Feeds the "Monthly Trips" and "% of Trips per Month" Tableau views.
 */

USE bixi;


-- Q1. Annual trip volume, both years side by side

SELECT
    YEAR(start_date) AS trip_year,
    COUNT(*)         AS total_trips
FROM trips
WHERE start_date >= '2016-01-01'
  AND start_date <  '2018-01-01'
GROUP BY YEAR(start_date)
ORDER BY trip_year;

-- Q2. Monthly volume, with year-over-year change

WITH monthly AS (
    SELECT
        YEAR(start_date)  AS trip_year,
        MONTH(start_date) AS trip_month,
        COUNT(*)          AS total_trips
    FROM trips
    WHERE start_date >= '2016-01-01'
      AND start_date <  '2018-01-01'
    GROUP BY YEAR(start_date), MONTH(start_date)
)
SELECT
    trip_year,
    trip_month,
    MONTHNAME(MAKEDATE(trip_year, 1) + INTERVAL (trip_month - 1) MONTH) AS month_name,
    total_trips,
    LAG(total_trips) OVER (PARTITION BY trip_month ORDER BY trip_year) AS prior_year_trips,
    ROUND(
        100.0 * (total_trips - LAG(total_trips) OVER (PARTITION BY trip_month ORDER BY trip_year))
              / NULLIF(LAG(total_trips) OVER (PARTITION BY trip_month ORDER BY trip_year), 0),
        1
    ) AS yoy_pct_change
FROM monthly
ORDER BY trip_year, trip_month;

-- Q3. Each month's share of its own year's total

SELECT
    YEAR(start_date)  AS trip_year,
    MONTH(start_date) AS trip_month,
    COUNT(*)          AS total_trips,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY YEAR(start_date)),
        2
    ) AS pct_of_year
FROM trips
WHERE start_date >= '2016-01-01'
  AND start_date <  '2018-01-01'
GROUP BY YEAR(start_date), MONTH(start_date)
ORDER BY trip_year, trip_month;

-- Q4. Average trips per day, by year-month

SELECT
    YEAR(start_date)  AS trip_year,
    MONTH(start_date) AS trip_month,
    COUNT(*)                              AS total_trips,
    COUNT(DISTINCT DATE(start_date))      AS operating_days,
    ROUND(COUNT(*) / COUNT(DISTINCT DATE(start_date)), 2) AS avg_trips_per_day
FROM trips
GROUP BY YEAR(start_date), MONTH(start_date)
ORDER BY trip_year, trip_month;

-- Q5. Persist Q4 as a working table

DROP TABLE IF EXISTS working_table1;

CREATE TABLE working_table1 AS
SELECT
    DATE_FORMAT(start_date, '%b, %Y') AS monthyear,
    YEAR(start_date)                  AS trip_year,
    MONTH(start_date)                 AS trip_month,
    ROUND(COUNT(*) / COUNT(DISTINCT DATE(start_date)), 2) AS avg_trips_per_day
FROM trips
GROUP BY
    DATE_FORMAT(start_date, '%b, %Y'),
    YEAR(start_date),
    MONTH(start_date)
ORDER BY trip_year, trip_month;

SELECT * FROM working_table1;
