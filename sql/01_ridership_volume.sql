/* =============================================================================
   01_ridership_volume.sql — How much is the system used, and when?
   -----------------------------------------------------------------------------
   Business question: is Bixi growing, and how does demand move across the
   season? Feeds the "Monthly Trips" and "% of Trips per Month" Tableau views.
   ============================================================================= */

USE bixi;

-- -----------------------------------------------------------------------------
-- Q1. Annual trip volume, both years side by side
-- -----------------------------------------------------------------------------
-- Half-open range (>= Jan 1, < Jan 1 next year) rather than YEAR(start_date).
-- Wrapping the column in a function makes the predicate non-sargable, so MySQL
-- cannot use idx_trips_start_date and falls back to a full scan.
SELECT
    YEAR(start_date) AS trip_year,
    COUNT(*)         AS total_trips
FROM trips
WHERE start_date >= '2016-01-01'
  AND start_date <  '2018-01-01'
GROUP BY YEAR(start_date)
ORDER BY trip_year;

-- -----------------------------------------------------------------------------
-- Q2. Monthly volume, with year-over-year change
-- -----------------------------------------------------------------------------
-- The original version of this query returned a bare COUNT with no year or
-- month column, so the output rows were unlabelled. Here the grouping keys are
-- projected, and a window function carries last year's value onto each row.
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

-- -----------------------------------------------------------------------------
-- Q3. Each month's share of its own year's total
-- -----------------------------------------------------------------------------
-- Normalising within year is what makes 2016 and 2017 seasonally comparable
-- despite the volume difference. This is the "% of Trips per Month" chart.
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

-- -----------------------------------------------------------------------------
-- Q4. Average trips per day, by year-month
-- -----------------------------------------------------------------------------
-- Denominator is distinct operating days rather than calendar days: Bixi runs
-- roughly April-November, and partial months at either end of the season would
-- otherwise be understated.
SELECT
    YEAR(start_date)  AS trip_year,
    MONTH(start_date) AS trip_month,
    COUNT(*)                              AS total_trips,
    COUNT(DISTINCT DATE(start_date))      AS operating_days,
    ROUND(COUNT(*) / COUNT(DISTINCT DATE(start_date)), 2) AS avg_trips_per_day
FROM trips
GROUP BY YEAR(start_date), MONTH(start_date)
ORDER BY trip_year, trip_month;

-- -----------------------------------------------------------------------------
-- Q5. Persist Q4 as a working table
-- -----------------------------------------------------------------------------
-- CREATE TABLE ... AS SELECT, so the table is derived from the data rather than
-- from hand-typed literals. The original approach ran the aggregate, then
-- pasted the sixteen results into an INSERT ... VALUES; that silently goes
-- stale the moment the source data changes and cannot be re-run.
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
