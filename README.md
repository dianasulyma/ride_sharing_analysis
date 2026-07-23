# Montreal BIXI Bike Share — SQL Analysis & Tableau Reporting

Analysis of ~8.6M bike-share trips from Bixi Montréal (2016–2017), examining ridership
growth, membership segmentation, demand per station, and casual-user revenue.

**Tools:** MySQL 8.0 · Tableau Desktop

---

## Headline findings

| Question | Finding |
|---|---|
| Is ridership growing? | Yes — every month grew year over year except November. July 2017 peaked at 859,856 trips vs. 696,905 in July 2016 (**+23%**). |
| Who rides? | Members take **~80%** of all 2017 trips, but their share is seasonal: 76% in July, 92% in November. |
| Do the segments differ? | Members average ~12 min per trip; casual users ~20 min, consistent with commuting vs. leisure use. |
| Where is demand concentrated? | Métro Jean-Drapeau leads round trips (**8,658**) and the longest average duration (**31.7 min**) — an island park destination, not a commuter node. |
| Where does casual revenue come from? | Sub-30-minute trips generate **$4.13M** of modelled casual revenue, ~80% of the total. Peak is Sunday 3 PM ($80,273). |

---

## Ridership growth, 2016 → 2017

<img src="tableau/screenshots/01_monthly_trips_2016_2017.png" width="700" alt="Monthly trips 2016 vs 2017">

## Membership

<img src="tableau/screenshots/03_member_share_2017.png" width="700" alt="Member share of trips, 2017">

<img src="tableau/screenshots/05_trip_duration_member_vs_nonmember.png" width="700" alt="Trip duration, member vs non-member">

## Station demand

<img src="tableau/screenshots/04_top10_round_trip_stations.png" width="700" alt="Top 10 round-trip stations">

<img src="tableau/screenshots/06_map_all_stations_duration.png" width="700" alt="Average trip duration by station">

<img src="tableau/screenshots/07_map_top5_longest_duration.png" width="700" alt="Top 5 stations by duration">

## Casual-user revenue

<img src="tableau/screenshots/08_revenue_by_trip_length.png" width="700" alt="Revenue by trip length">

---

## SQL techniques

- **Window functions** — `LAG` for year-over-year comparison, `SUM() OVER (PARTITION BY)`
  for within-year percentage shares, `ROW_NUMBER` for per-group top-N, running
  totals for cumulative demand concentration
- **CTEs** for multi-step aggregation without repeating subqueries
- **Conditional aggregation** to pivot time-of-day buckets into columns
- **`CREATE TABLE AS SELECT`** so derived tables stay reproducible
- **Index design** driven by the actual query predicates, with a covering index
  for the month/membership aggregations
- **Data-quality gates** — orphaned foreign keys, negative and outlier durations
  checked before any figure is reported

## Repository structure

```
├── sql/
│   ├── 00a_schema_and_load.sql     Schema + CSV load (destructive — clean installs only)
│   ├── 00b_indexes_and_checks.sql  Indexes + data-quality gates (safe, re-runnable)
│   ├── 01_ridership_volume.sql     Trip counts, YoY change, seasonality
│   ├── 02_membership.sql           Member vs. casual segmentation
│   ├── 03_stations.sql             Station ranking, time-of-day flow
│   ├── 04_round_trips.sql          Round-trip rates and leisure signal
│   └── 05_revenue.sql              Fare model and revenue by band/hour
├── tableau/
│   ├── bixi_tableau_report.pdf     Full written report
│   └── screenshots/                Dashboard exports
├── docs/
│   └── methodology.md              Assumptions, caveats, known limitations
└── data/
    └── README.md                   How to obtain the source data
```

Files `01`–`05` run independently and in any order. They read only `trips` and
`stations`; anything else they need (`working_table1`, `fare_bands`) they create
themselves.

## Limitations

The revenue model multiplies trip counts by single-trip fares. Real casual revenue
includes day passes and multi-trip products, so a rider taking four trips is counted
four times here but paid once. Treat these figures as an upper bound on casual revenue
and a sound guide to *relative* demand across bands and hours — not booked revenue.
Full assumptions in [`docs/methodology.md`](docs/methodology.md).

## Data

Bixi publishes historical trip data as open data. See [`data/README.md`](data/README.md).
CSVs are gitignored — the repo ships the schema and queries, not the ~1GB of source rows.
