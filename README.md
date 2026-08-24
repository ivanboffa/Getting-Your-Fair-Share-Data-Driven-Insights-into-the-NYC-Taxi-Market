# Getting Your Fair Share — Data-Driven Insights into the NYC Taxi Market

**Where should a New York cab driver start their morning, and what actually makes
a passenger tip?** Two business questions, answered with limited-dependent-variable
and count models on 100,000 yellow-cab trips from February 2026.

<p>
  <img alt="R" src="https://img.shields.io/badge/R-4.x-276DC3?logo=r&logoColor=white">
  <img alt="Models" src="https://img.shields.io/badge/models-multinomial%20logit%20%7C%20Tobit%20%7C%20Negative%20Binomial-2b8a3e">
  <img alt="Sample" src="https://img.shields.io/badge/sample-100k%20trips-555">
  <img alt="Report" src="https://img.shields.io/badge/report-full%20write--up-b23c17">
</p>

> Group assignment for the Customer Models course (University of Groningen,
> Faculty of Economics and Business, 2025/26). Full write-up, including every
> appendix table:
> **[`report/customer-models-report.md`](report/customer-models-report.md)**.

---

## The answers, in one screen

The client is a fleet operator whose drivers lease its cars and want to know
where to be and how to earn more. Five findings the models support:

1. **Start the morning in the Upper West Side → Yorkville → Lenox Hill corridor.**
   These zones deliver roughly **double** the Manhattan average of ~8 morning
   pickups per zone, and the ranking is identical on weekends.
2. **The airport is the tipping play, not the volume play.** An airport pickup is
   worth **+$2.59** in expected tip and cuts the odds of getting stiffed by ~85%
   — by far the largest single effect in either model.
3. **Mornings are a genuine trade-off.** They maximise volume but are the
   *weakest* tipping window (−$0.42 versus an afternoon trip). Which one wins
   depends on a driver's fare-versus-tip mix — so the analysis surfaces the
   tension instead of papering over it.
4. **Discount hard for snow and weekends.** Each centimetre of morning snowfall
   cuts expected pickups by **~22%**; a weekend morning runs **~45%** below a
   weekday.
5. **Bigger parties tip better, not worse.** Each extra passenger adds ~$0.13 to
   the expected tip — the diffusion-of-responsibility intuition does not hold
   here, plausibly because one person pays and absorbs the full social norm.

---

## Why this project is worth a look

It is not a notebook that fits a model and reports an R². The interesting work is
in the modelling decisions, each made against a specific property of the data:

| Decision | The reasoning |
| --- | --- |
| **Drop cash trips instead of controlling for them** | Cash tips are never entered into the meter, so every cash trip records $0. A payment-type dummy would perfectly predict a zero tip and the model would learn the recording artifact rather than passenger behaviour. Restricting the sample removes the artifact instead of adjusting for it. |
| **Tobit framed as a corner solution, not censoring** | A $0 tip is usually a real choice, not a positive latent amount hidden by a constraint. Tobit is used as a convenient joint model for the spike at zero plus the continuous positive part — and then that assumption is *tested* with a Cragg two-part model. |
| **Explicit zeros in the count panel** | The full 64 zone × 28 day grid is constructed and unobserved zone-mornings filled with zero. Aggregating only observed rows truncates the sample at the bottom, never lets the model see a zero, and biases expected counts upward. |
| **Structural predictors over zone fixed effects** | Zone dummies would absorb the very characteristics the analysis is trying to explain, and hundreds of coefficients give a driver nothing usable. Zone labour force both ranks the zones *and* explains them: morning demand is a commuting phenomenon. |
| **Robustness spent where it matters** | No null → minimal → full ladder. The budget goes to the assumptions that could actually overturn the advice: IIA, the single-process assumption, and the arbitrariness of the tip-category cut-offs. |
| **Limitations stated, not buried** | IIA is rejected. McFadden R² is ~0.07. The 74.3% hit rate barely beats always guessing "generous" (72.2%). All of it is reported, and the advice is pitched at the level the evidence supports — direction and ranking, not precise magnitudes. |

---

## Challenge 1 — What drives tipping?

**Unit of analysis:** one credit-card trip (n = 58,415).
**Two linked decisions:** *whether* to tip and *how much*, so two complementary
models rather than a ladder of overlapping specifications.

### Model 1 — Multinomial logit (`mlogit`)

Trips are classified by generosity against US norms: `no_tip` (0%), `low`
(0–15%), `standard` (15–20%), `generous` (>20%). **`generous` is the reference
category** because it is modal at 72% — NYC point-of-sale screens default to
20/25/30% presets and most passengers simply tap a suggestion — so every
coefficient reads as a deviation from the prevailing norm.

Selected results for the `no_tip` versus `generous` equation:

| Predictor | Coefficient | Interpretation |
| --- | --- | --- |
| Airport pickup | −1.881 \*\*\* | Odds of leaving no tip ~85% lower |
| Trip duration (per minute) | +0.087 \*\*\* | Largest continuous effect — long, slow trips depress tipping |
| Weekend | +0.266 \*\*\* | Weekend trips more likely to end in no tip |
| Passenger count | −0.239 \*\*\* | Larger groups tip more reliably |
| Fare amount | −0.025 \*\*\* | Higher fares less likely to go untipped |
| Trip distance | +0.001 (n.s.) | Already priced into the fare |

Fit: McFadden R² = 0.072, hit rate 74.3%, LR test versus intercept-only
χ²(27) = 7,474.8, p < 0.001. Predicted market shares reproduce the observed
proportions closely.

**Assumption check.** A Hausman–McFadden test **rejects IIA** (χ² = 43.3, df = 20,
p = 0.002). Reported as a real limitation: signs and rough magnitudes of the
policy-relevant effects are stable, and a nested logit grouping
{`no_tip`, `low`} against {`standard`, `generous`} would be the formal fix.

### Model 2 — Tobit Type 1 (`AER::tobit`)

Dependent variable: tip amount in dollars, left-censored at 0. Marginal effects
on the observed expected tip:

| Predictor | Marginal effect on E[tip] |
| --- | --- |
| Airport pickup | **+$2.59** |
| Fare amount | +$0.17 per $1 of fare |
| Trip duration | −$0.08 per minute |
| Morning (vs afternoon) | −$0.42 |
| Weekend | −$0.23 |
| Passenger count | +$0.13 |

Squared correlation between predicted and observed tips ≈ 0.55.

### Robustness

- **Cragg two-part model** — a logit for P(tip > 0) and an OLS on log(tip) among
  tippers. Signs agree for every policy-relevant variable, supporting Tobit as an
  adequate summary. The informative exception is **trip duration**: it *lowers*
  the probability of tipping at all (−0.084) but *raises* the amount among those
  who do tip (+0.017). Long rides put some passengers off entirely, but those who
  do tip give more — exactly the nuance a single-process model cannot capture.
- **Threshold sensitivity** — re-estimating at 10%/25% and 12%/22% cut-offs
  leaves every policy-relevant effect sign-stable; only magnitudes and fit
  statistics move.

---

## Challenge 2 — The morning launch

**Unit of analysis:** one Manhattan pickup zone on one morning, 6–11 a.m.
**Dependent variable:** the raw count of trips starting there — deliberately not
a constructed "successful trip" indicator, because any threshold would be
arbitrary and "expected pickups" is exactly what a driver wants to know.

**Panel:** 64 zones × 28 days = 1,792 zone-mornings, with unobserved
zone-mornings filled as explicit zeros.

### Poisson versus Negative Binomial

The counts are heavily overdispersed — variance-to-mean ratio **8.81** against
the Poisson assumption of 1.

| Model | Log-lik. | AIC | BIC | McFadden R² |
| --- | --- | --- | --- | --- |
| Poisson | −8,605 | 17,222 | 17,255 | 0.133 |
| **Negative Binomial** | **−5,430** | **10,873** | **10,912** | **0.453** |

The Negative Binomial dominates on every criterion; the LR test gives
χ²(1) = 6,350.7, p < 0.001 (boundary-adjusted), with θ = 1.208 (α ≈ 0.828).

A detail worth flagging: **temperature is significant under Poisson and not under
Negative Binomial** — a clean demonstration of why overdispersion has to be
handled *before* drawing inference.

### Incidence rate ratios

| Predictor | IRR | 95% CI | Reading |
| --- | --- | --- | --- |
| Weekend | 0.554 | 0.499–0.615 | 44.6% fewer trips than a comparable weekday |
| Snowfall (per cm) | 0.783 | 0.718–0.854 | Each extra cm cuts trips ~21.7% |
| Temperature (per °C) | 0.995 | 0.985–1.005 | Not significant |
| Precipitation (per mm) | 0.969 | 0.916–1.024 | Not significant |
| Zone labour force | — | — | +100 working residents ≈ **+2.3%** morning trips |

### The deliverable — where to be at 6 a.m.

Predicted trips under standardised conditions (typical weekday, average February
temperature, no precipitation):

| Rank | Zone | Predicted morning trips |
| --- | --- | --- |
| 1–2 | Upper West Side (North / South) | 17.5 |
| 3–4 | Yorkville (East / West) | 14.6 |
| 5–7 | Lenox Hill (East / West), Roosevelt Island | 14.5 |
| 8 | Washington Heights North | 13.3 |
| 9 | Central Harlem North | 13.2 |
| 10–12 | East Chelsea, Flatiron, West Chelsea | 12.6 |

Manhattan-wide average: **7.98** trips per zone-morning. The full top 20 with
labour-force values and observed averages is in
[`results/c2_top20_zones.csv`](results/c2_top20_zones.csv).

**A caveat we make openly.** Roosevelt Island ranks 7th on predicted demand,
driven by its resident labour force, but averages only ~0.32 observed trips per
morning. The gap is informative: resident labour force is a good structural proxy
that breaks down where strong transit substitutes exist (the island's tram and
subway). The model explains structural propensity, not realised ridership
everywhere.

### Robustness

- **Weekday versus weekend** — re-ranking under weekend conditions leaves the
  top 10 **identical (10/10)**. The weekend effect scales every zone down by the
  same 44.6% without reordering them, so the "where to start" advice holds
  regardless of the day.
- **All five boroughs** — re-estimating with borough indicators (n = 6,496
  zone-days, 232 zones) preserves the key directions: weekend IRR 0.603, snowfall
  IRR 0.803, both p < 0.001. The Manhattan conclusions are not an artifact of the
  sample restriction.

---

## Repository layout

```
├── R/
│   ├── 00_setup.R                     Installs the package dependencies
│   ├── 01_challenge1_tipping.R        Challenge 1: MNL, Tobit, two-part, sensitivity
│   ├── 02_challenge2_morning_launch.R Challenge 2: Poisson, NegBin, zone rankings
│   └── run_all.R                      Runs both end to end
├── data/README.md                     Sources, schema, cleaning rules
├── results/                           Estimated model tables as CSV
├── report/customer-models-report.md   Full write-up with appendix tables
└── output/                            Generated at runtime (git-ignored)
```

## Running it

Requires R 4.x and an internet connection — the scripts download the trip
extract, the NTA tables, and the Open-Meteo weather series at runtime. Nothing
needs to be placed on disk first, and no API key is required.

```bash
git clone https://github.com/ivanboffa/Getting-Your-Fair-Share-Data-Driven-Insights-into-the-NYC-Taxi-Market.git
cd Getting-Your-Fair-Share-Data-Driven-Insights-into-the-NYC-Taxi-Market

Rscript R/00_setup.R    # install dependencies (once)
Rscript R/run_all.R     # run both challenges
```

Or run a single challenge:

```bash
Rscript R/01_challenge1_tipping.R
Rscript R/02_challenge2_morning_launch.R
```

Everything lands in `output/` — CSV tables, PNG figures, and serialised model
objects (`.rds`) for further inspection. Challenge 1 takes a few minutes; the
multinomial logit on 58k trips is the slow step. Set `SAMPLE_N <- 25000` near the
top of the script for a fast smoke test.

**Reproducibility:** `set.seed(42)` in both scripts. The one moving part is the
Open-Meteo archive, which occasionally revises historical values — weather
coefficients may shift marginally between runs.

## Toolchain

`arrow` (parquet I/O) · `dplyr` / `tidyr` / `lubridate` (wrangling) ·
`mlogit` + `dfidx` (multinomial logit) · `AER` (Tobit) · `MASS` (`glm.nb`) ·
`lmtest` + `sandwich` (LR tests, robust covariance) · `jsonlite` (weather API) ·
`ggplot2` (figures)

## Honest limitations

These are associations in a one-month observational extract, not causal effects.
Tipping is dominated by an unrecorded point-of-sale default mechanism; cash
behaviour is invisible by construction; and the morning model leans on a
residential proxy for demand. The advice is strong on direction and ranking,
lighter on precise magnitudes — and the write-up says so.

## Credits

Group assignment for **Customer Models**, University of Groningen, Faculty of
Economics and Business (2025/26), Tutorial 2 — Group 1: Ivan Boffa, Jan Kerin,
Dea Mustafa, and Gerard Amigo.

Data: NYC Taxi & Limousine Commission trip records; NYC Department of City
Planning NTA demographic and labour-force tables; Open-Meteo historical weather
archive.

## Licence

[MIT](LICENSE) for the code. The report is coursework, shared for portfolio
purposes.
