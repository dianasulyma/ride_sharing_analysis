/* =============================================================================
   05_revenue.sql — Casual-user revenue model
   -----------------------------------------------------------------------------
   Business question: where does single-trip revenue actually come from? The
   Tableau report built this with calculated fields; reproducing it in SQL keeps
   the pricing logic in one auditable place and makes it re-runnable.

   Fare card (single-trip, casual users only — members ride on a subscription):
       up to 30 min   $2.99
       30 to 45 min   $4.79
       45 to 60 min   $7.79
   Trips over 60 minutes are excluded: the published fare card does not extend
   past an hour, so any figure for them would be invented.
   ============================================================================= */

USE bixi;

-- -----------------------------------------------------------------------------
-- Fare lookup as a table, not hardcoded literals
-- -----------------------------------------------------------------------------
-- Prices change. A lookup table means a price update is one UPDATE statement
-- rather than a search-and-replace through every query that touches revenue.
DROP TABLE IF EXISTS fare_bands;
CREATE TABLE fare_bands (
    band_label   VARCHAR(20)   NOT NULL,
    min_seconds  INT           NOT NULL,
    max_seconds  INT           NOT NULL,
    fare         DECIMAL(5,2)  NOT NULL,
    PRIMARY KEY (band_label)
);

INSERT INTO fare_bands (band_label, min_seconds, max_seconds, fare) VALUES
    ('Under 30 min', 0,    1800, 2.99),
    ('30-45 min',    1801, 2700, 4.79),
    ('45-60 min',    2701, 3600, 7.79);

-- -----------------------------------------------------------------------------
-- Q1. Revenue by fare band
-- -----------------------------------------------------------------------------
SELECT
    f.band_label,
    f.fare,
    COUNT(*)                        AS trips,
    ROUND(COUNT(*) * f.fare, 2)     AS revenue,
    ROUND(100.0 * COUNT(*) * f.fare
          / SUM(COUNT(*) * f.fare) OVER (), 2) AS pct_of_revenue
FROM trips t
JOIN fare_bands f
    ON t.duration_sec BETWEEN f.min_seconds AND f.max_seconds
WHERE t.is_member = 0
GROUP BY f.band_label, f.fare
ORDER BY revenue DESC;

-- -----------------------------------------------------------------------------
-- Q2. Short-trip revenue by day of week and hour
-- -----------------------------------------------------------------------------
-- This is the heatmap behind the report's staffing conclusion. Restricted to
-- the under-30-minute band, which carries the large majority of the revenue.
SELECT
    DAYNAME(t.start_date)      AS day_of_week,
    HOUR(t.start_date)         AS hour_of_day,
    COUNT(*)                   AS trips,
    ROUND(COUNT(*) * 2.99, 2)  AS revenue
FROM trips t
WHERE t.is_member = 0
  AND t.duration_sec <= 1800
GROUP BY DAYNAME(t.start_date), DAYOFWEEK(t.start_date), HOUR(t.start_date)
ORDER BY DAYOFWEEK(t.start_date), hour_of_day;

-- -----------------------------------------------------------------------------
-- Q3. Peak revenue hour per day
-- -----------------------------------------------------------------------------
-- Ranked so the single best hour per day falls out directly, instead of being
-- read off a chart by eye.
WITH hourly AS (
    SELECT
        DAYOFWEEK(start_date)     AS dow_num,
        DAYNAME(start_date)       AS day_of_week,
        HOUR(start_date)          AS hour_of_day,
        COUNT(*)                  AS trips,
        ROUND(COUNT(*) * 2.99, 2) AS revenue
    FROM trips
    WHERE is_member = 0
      AND duration_sec <= 1800
    GROUP BY DAYOFWEEK(start_date), DAYNAME(start_date), HOUR(start_date)
),
ranked AS (
    SELECT
        hourly.*,
        ROW_NUMBER() OVER (PARTITION BY dow_num ORDER BY revenue DESC) AS rn
    FROM hourly
)
SELECT day_of_week, hour_of_day, trips, revenue
FROM ranked
WHERE rn = 1
ORDER BY dow_num;

-- -----------------------------------------------------------------------------
-- Caveat worth stating in any deck built on this
-- -----------------------------------------------------------------------------
-- This models revenue as trips x single-trip fare. Real casual revenue includes
-- day passes and multi-trip products, under which a rider taking four trips is
-- counted four times here but paid once in reality. Treat these figures as an
-- upper bound on casual revenue and as a reliable guide to *relative* demand
-- across bands and hours — not as booked revenue.
