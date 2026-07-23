# Data

The CSVs are gitignored (~1GB). Obtain them from Bixi's open data portal:
<https://bixi.com/en/open-data>

Expected files in this directory:

| File | Rows | Columns |
|---|---|---|
| `trips.csv` | ~8.6M | `start_date`, `start_station_code`, `end_date`, `end_station_code`, `duration_sec`, `is_member` |
| `stations.csv` | ~540 | `code`, `name`, `latitude`, `longitude` |

Bixi's yearly exports have changed column names and file layout between seasons.
If you pull a year other than 2016–2017, check the headers against the schema in
`sql/00_setup.sql` before loading.

Load by uncommenting the `LOAD DATA LOCAL INFILE` blocks in `sql/00_setup.sql`.
This requires `local_infile=1` on both server and client:

```bash
mysql --local-infile=1 -u root -p
```
