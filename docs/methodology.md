# Methodology, assumptions, and limitations

## Data

Bixi Montréal open trip data, 2016 and 2017 seasons. Roughly 8.6M trip records
and 540 stations. Bixi operates approximately April through November; there is
no winter data, and the absence of December–March rows is a real gap in the
service calendar rather than missing data.

## Definitions

| Term | Definition |
|---|---|
| **Trip** | One row in `trips` — a bike undocked and re-docked. |
| **Member** | `is_member = 1`. Annual subscription holder. |
| **Casual user** | `is_member = 0`. Single trip, day pass, or short-term product. The data does not distinguish among these. |
| **Round trip** | `start_station_code = end_station_code`. |
| **Operating day** | A calendar date with at least one trip. Used as the denominator for trips-per-day so that partial months at season boundaries are not understated. |

## Data-quality handling

Checks run in `sql/00_setup.sql` before any analysis:

- **Orphaned station codes** — trips referencing a station code absent from
  `stations`. Station inventory changes between seasons, so some drift is
  expected. Left joins are used where the count should survive; inner joins
  where a station name is required for the output to be meaningful.
- **Duration outliers** — trips are filtered to 60 s ≤ duration ≤ 86,400 s for
  all duration averages. Sub-minute trips are typically docking errors (a bike
  removed and immediately replaced); trips over 24 hours are abandoned or
  stolen bikes. Both distort means badly and neither represents a rider journey.
  Trip *counts* are unfiltered — a docking error is still a system event.

## Analytical choices

**Half-open date ranges.** All date filtering uses `>= start AND < next_start`
rather than `BETWEEN`. On a `DATETIME` column, `BETWEEN '2016-01-01' AND
'2016-12-31'` excludes everything after midnight on December 31 — roughly a
day of data silently dropped per year.

**Within-year normalisation for seasonality.** Comparing raw monthly counts
across years conflates growth with seasonality. Expressing each month as a
percentage of its own year's total isolates the seasonal shape, which is what
shows the two years follow the same curve at different levels.

**Median alongside mean for duration.** Trip duration is right-skewed. The mean
is pulled upward by a long tail, and casual trips have a heavier tail than
member trips, so the mean *exaggerates* the gap between segments. Both are
reported so the reader can see how much of the difference is typical behaviour
versus tail effects.

## Revenue model

Modelled as `trip count × single-trip fare` for casual users only, using the
published fare card:

| Duration | Fare |
|---|---|
| ≤ 30 min | $2.99 |
| 30–45 min | $4.79 |
| 45–60 min | $7.79 |

**Known limitations of this model:**

1. **Day passes and multi-trip products are not represented.** A casual rider
   taking four trips on a day pass is counted four times here and paid once in
   reality. This inflates the modelled figure, and it inflates it *unevenly* —
   most at high-volume tourist stations and peak weekend hours, which are
   exactly the segments the analysis highlights.
2. **Trips over 60 minutes are excluded** rather than extrapolated. The
   published fare card does not extend past an hour; any number for them would
   be invented.
3. **No member revenue.** Subscription revenue is not derivable from trip data,
   so the ~80% of trips taken by members contribute nothing to these figures.
   The revenue analysis describes a minority of trips.

The right way to read these numbers is as **relative** demand signal — which
duration bands and which hours drive casual usage — not as booked revenue.

## Interpretive claims and their evidence

The original report drew inferences from geography (Métro Jean-Drapeau is near
a park, therefore leisure). Those inferences are plausible but were not tested
against the data. `sql/04_round_trips.sql` Q3 tests the leisure reading directly:
if round trips are leisure trips, they should be longer, more weekend-weighted,
and more casual-driven than point-to-point trips. Where a claim rests on
external context rather than the dataset, the report should say so — the
distinction matters to a stakeholder deciding how much weight to put on it.

## Not addressed

- **Weather.** Almost certainly the largest single driver of daily variation,
  and entirely absent. Joining Environment Canada daily observations for
  Montréal would let the seasonal curve be decomposed into temperature,
  precipitation, and residual demand — the most valuable extension available.
- **Rebalancing operations.** Bikes moved by truck appear in neither table, so
  net flow per station reflects rider behaviour only, not actual dock occupancy.
- **Individual riders.** No user identifier, so no repeat-usage, retention, or
  conversion analysis is possible.
