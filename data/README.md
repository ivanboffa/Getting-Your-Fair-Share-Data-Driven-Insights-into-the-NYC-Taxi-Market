# Data

No data files are stored in this repository. Every input is fetched at runtime by
the analysis scripts, so a clone stays small and the pipeline stays reproducible
from source.

## Sources

| Source | What it provides | How it is accessed |
| --- | --- | --- |
| NYC TLC yellow-cab trip records, February 2026 | 100,000 trips — the unit of analysis for both challenges | `taxi_data_100k.parquet`, read over HTTPS with `arrow::read_parquet()` |
| NYC Department of City Planning (NTA tables) | Neighbourhood population (`demdata_simpl.csv`) and labour force (`econdata_simpl.csv`) | `read.csv2()` over HTTPS, joined on `PU_NTA_Code` |
| [Open-Meteo historical weather archive](https://open-meteo.com/) | Hourly temperature, precipitation, snowfall and wind for Manhattan across February 2026 | JSON API, no key required |

The taxi and NTA files are served from the course data repository
(`https://raw.githubusercontent.com/rphars/taxidata/main/`). Both scripts wrap
the demographic and weather joins in `tryCatch()`, so the models still estimate
if a source is unreachable — the affected predictors are simply dropped with a
message.

## Trip-level schema (columns used)

| Column | Type | Notes |
| --- | --- | --- |
| `tpep_pickup_datetime`, `tpep_dropoff_datetime` | timestamp | Trip duration is derived from the difference |
| `passenger_count` | integer | ~30% missing in the raw file, all on `payment_type = 0`; imputed to the modal value of 1 |
| `trip_distance` | double | Miles |
| `payment_type` | integer | 0 undocumented, 1 credit card, 2 cash, 3 no charge, 4 dispute, 5 unknown, 6 voided |
| `fare_amount`, `tip_amount`, `tolls_amount`, `total_amount` | double | Dollars. `tip_amount` is **only reliable for `payment_type = 1`** — see below |
| `PULocationID`, `DOLocationID` | integer | TLC taxi zone identifiers. Airport zones are 1 (Newark), 132 (JFK), 138 (LaGuardia) |
| `PU_Borough`, `PU_Zone` | character | Human-readable pickup location |
| `PU_NTA_Code`, `PU_NTA_Name` | character | Neighbourhood Tabulation Area — the join key to the demographic and labour-force tables |
| `pickup_date`, `pickup_hour` | date / integer | Pre-computed convenience columns |

Also present but unused here: `RatecodeID`, `mta_tax`, `improvement_surcharge`,
`congestion_surcharge`, `Airport_fee`, `cbd_congestion_fee`, and the drop-off
borough / zone / NTA fields.

## The one data caveat that shapes everything

Cash tips are never entered into the taxi meter, so **every cash trip records a
$0 tip regardless of what the passenger actually handed over**. This is a
recording artifact, not behaviour. Challenge 1 therefore restricts the sample to
credit-card trips rather than controlling for payment type — a payment dummy
would perfectly predict `tip = 0` on cash trips and the model would learn the
artifact instead of the behaviour.

## Cleaning filters

Applied identically in both scripts, dropping 6.0% of the raw file (100,000 →
94,044 trips):

```r
fare_amount       >  0
trip_distance     >  0
trip_duration_min >  0
trip_duration_min <  180      # three hours
passenger_count   >= 1 & <= 6
tip_amount        >= 0
```

Challenge 1 additionally keeps only credit-card trips and drops tips above 100%
of the fare, giving an analytic sample of **58,415 trips**. Challenge 2
aggregates to a Manhattan zone × day panel of **64 zones × 28 days = 1,792
zone-mornings**.
