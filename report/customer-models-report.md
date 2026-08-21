# Getting Your Fair Share: Data-Driven Insights into the NYC Taxi Market

**Customer Models — Group Assignment 2025/2026**
University of Groningen, Faculty of Economics and Business
Tutorial 2 — Group 1: Ivan Boffa, Jan Kerin, Dea Mustafa, Gerard Amigo

---

## 1. Introduction

As analysts at Customer Models, we are regularly asked by the drivers who lease
our cars to turn data into decisions. This brief addresses two of their most
frequent strategic questions using 100,000 NYC yellow-cab trips from February
2026.

**Challenge 1 — What drives tipping?** Tips are a substantial, discretionary part
of a driver's take-home pay. We identify which trip characteristics are
associated with whether a passenger tips and with how much.

**Challenge 2 — The Morning Launch.** A profitable shift starts well. We identify
which Manhattan pickup zones generate the most morning demand, and explain why,
so a driver knows where to position at 6 a.m.

Because the data are observational, our aim is not airtight causal estimation but
the most defensible strategic advice the data and the course's models can
support. Across the two challenges we apply three model families spanning the
required course weeks: a multinomial logit (Week 3), a Tobit model (Week 4), and
Poisson / Negative Binomial count models (Week 5), supported by a two-part
(Cragg) model and several sensitivity checks.

---

## 2. Data, Cleaning and Exploration

### 2.1 Cleaning

The raw file contains 100,000 trips. We derived trip duration from the pickup and
drop-off timestamps and removed records that are physically impossible or clearly
mis-recorded: non-positive fares, zero-distance trips, durations of zero or over
three hours, and passenger counts outside 1–6. This leaves **94,044 trips** (a
6.0% loss), a conservative clean that discards only clear errors.

One judgement call concerns `passenger_count`: roughly 30% of raw trips have a
missing passenger count, and these same trips carry an undocumented
`payment_type = 0`. Rather than silently dropping ~30,000 rows, we imputed the
modal value (one passenger). As shown below, this has no effect on Challenge 1
because those trips are excluded by our payment-type restriction anyway; we flag
the imputation here for transparency.

### 2.2 Exploration: payment type and the recording of tips

Before specifying any model we examined how tipping relates to payment type — the
single most important data-quality question for this dataset.

| Payment type | Share of cleaned trips | % of trips with recorded tip | Mean recorded tip |
| --- | --- | --- | --- |
| Credit card (code 1) | 62.2% (n = 58,503) | 90.6% | $4.16 |
| Undocumented (code 0) | ~30% | 9.0% | $0.43 |
| Cash (code 2) | 7.8% | ~0% | ~$0.00 |
| No charge / dispute / unknown / voided | 0.79% (n = 740) | ~0% | ~$0.00 |

The pattern is decisive: **cash trips show essentially zero recorded tipping**.
This is not behaviour — cash tips are simply never entered into the taxi meter,
so they are absent from the data. Including a credit-card indicator in a tipping
model would therefore perfectly predict a zero tip for every cash trip, which only
reproduces a recording artifact and tells a driver nothing about real passenger
behaviour. We act on this directly: all Challenge 1 analysis is restricted to
credit-card trips, the only observations for which `tip_amount` is reliably
captured. We remove the artifact from the sample rather than control for it.

### 2.3 Descriptive overview of the analytic sample

After the credit-card restriction and removing a handful of extreme
tip-percentage recording errors (tips above 100% of fare), the Challenge 1
analytic sample is **58,415 trips**.

| Statistic | Value |
| --- | --- |
| Trips with a recorded tip | ~90.6% |
| Mean tip amount | $4.13 |
| Median tip (% of fare) | 26.3% |
| Share "no tip" (0%) | 9.4% |
| Share "low" (0–15%) | 11.6% |
| Share "standard" (15–20%) | 6.7% |
| Share "generous" (>20%) | 72.2% |

The standout feature is that **72% of credit-card trips tip above 20%**. This
reflects the New York point-of-sale screens, which present default tip buttons at
20/25/30%; most passengers simply tap a suggestion. We return to this when
interpreting the models, because it shapes both the choice of reference category
and how much classification accuracy is achievable.

---

## 3. Challenge 1 — What Drives Tipping?

### 3.1 Problem and unit of analysis

One observation is one credit-card taxi trip. Tipping is really two linked
decisions — whether to tip and how much — so we approach it with two
complementary models rather than a long ladder of overlapping specifications. We
do not report a stand-alone logit for the tip/no-tip decision: the Tobit model
below already contains that decision within it, and the two-part robustness check
reports it once. The binary tip/no-tip decision (Week 2) is thus covered by Part 1
of the two-part model in §3.5, which estimates a logit for P(tip > 0) on the full
predictor set.

### 3.2 Dependent variables and predictors

For the multinomial logit we classify each trip by tip generosity, anchored on
widely documented US norms (15% acceptable, 20% good):

- `no_tip` (0%), `low` (0–15%), `standard` (15–20%), `generous` (>20%).

We set **`generous` as the reference category** because it is modal (72%), so
every coefficient reads naturally as a deviation from the prevailing "tap the
20%+ default" norm. For the Tobit model the dependent variable is the tip amount
in dollars.

Predictors (identical across models for comparability): `fare_amount`,
`trip_distance`, `trip_duration_min`, an `airport_pickup` indicator (JFK,
LaGuardia, Newark), `time_of_day` (afternoon as reference; morning, evening,
night), a `weekend` indicator, and `passenger_count`. We deliberately exclude
average speed: it is mechanically (distance ÷ duration) collinear with two
variables already in the model and would only destabilise the estimates.

On strategy: rather than estimating a null → minimal → full sequence, we estimate
a single, theory-driven specification per model. A "model ladder" would add
little, since the variables above are all ex ante plausible drivers of tipping;
comparing nested versions would mainly re-confirm that adding real predictors
improves fit. We instead spend our robustness budget on assumptions that
genuinely matter (the IIA assumption, the single-process assumption, and
threshold choices).

### 3.3 Model 1 — Multinomial logit (Week 3)

**Why this model.** The outcome has four unordered categories, so OLS is
inappropriate and a binary logit would discard information. We estimate a
multinomial logit with `mlogit`, modelling each category's log-odds relative to
"generous."

**Fit and validation.** The model is globally significant (LR test vs.
intercept-only: χ²(27) = 7,474.8, p < 0.001) with a McFadden R² of 0.072 and a
hit rate of 74.3%; predicted market shares reproduce the observed proportions
closely (generous 72.2%, no_tip 9.4%, low 11.6%, standard 6.7%).

**Results — drivers of not tipping** (coefficients are log-odds relative to the
generous baseline):

| Predictor | Coef. (no_tip vs generous) | Interpretation |
| --- | --- | --- |
| Airport pickup | −1.881 \*\*\* | Airport pickups are far less likely to end in no tip (odds ~85% lower); marginal effect ≈ −0.70 pp on P(no tip) |
| Trip duration | +0.087 \*\*\* | Longer trips strongly increase P(no tip) — largest continuous predictor |
| Weekend | +0.266 \*\*\* | Weekend trips more likely to receive no tip |
| Passenger count | −0.239 \*\*\* | Larger groups less likely to leave no tip |
| Fare amount | −0.025 \*\*\* | Higher fares less likely no tip |
| Evening (vs afternoon) | −0.214 \*\*\* | Evening trips less likely to receive no tip |
| Trip distance | +0.001 (n.s.) | Not significant (p = 0.14) |

Full three-equation matrix: [Appendix Table A1](#table-a1--full-mnl-coefficient-matrix).

**What it means for drivers.** The strongest and most actionable signal is the
airport effect: airport pickups are markedly more likely to be generous and
markedly less likely to stiff the driver. Two behavioural notes are worth flagging
because they overturn intuitive guesses. First, **larger groups tip more
reliably, not less** — the diffusion-of-responsibility story does not appear here,
plausibly because one person pays for the group and absorbs the full social norm.
Second, **mornings are the weakest tipping window**, which sits in interesting
tension with Challenge 2 (mornings are the best volume window) — a trade-off we
draw out in the conclusion.

**Assumption check — IIA.** The multinomial logit assumes Independence of
Irrelevant Alternatives. A Hausman–McFadden test **rejects IIA**
(χ² = 43.3, df = 20, p = 0.002), so the relative odds between categories are not
fully independent of the others present. This is a genuine limitation rather than
a fatal flaw for our purpose: the signs and rough magnitudes of the
policy-relevant effects (airport, weekend, group size) are stable, and a nested
logit grouping {`no_tip`, `low`} against {`standard`, `generous`} would be the
natural formal fix. We flag this rather than over-claim.

### 3.4 Model 2 — Tobit (Week 4)

**Why this model, and the censoring question.** A zero tip is not classical
censoring: a $0 tip is usually a real, desired choice (a "corner solution"), not a
positive latent amount hidden by some constraint. We therefore use the Tobit
Type 1 model not as a censoring correction but as a convenient single framework
that handles the spike of zeros and the continuous positive amounts jointly,
avoiding the bias OLS incurs by treating zeros as ordinary values. Crucially, we
then test the assumption this buys us — that one process drives both the decision
and the amount — using the two-part model in §3.5.

**Results** (marginal effects on the observed expected tip, in $). The model
tracks observed tips well (squared correlation between predicted and observed
≈ 0.55).

| Predictor | Marginal effect on E[tip] | Reading |
| --- | --- | --- |
| Airport pickup | +$2.59 | Largest single effect — airport runs are the most lucrative for tips |
| Fare amount | +$0.17 per $1 of fare | Tips scale with the bill, as expected |
| Morning (vs afternoon) | −$0.42 | Mornings tip less, echoing the MNL |
| Weekend | −$0.23 | Weekends tip less |
| Trip duration | −$0.08 per minute | Longer (slower) trips depress tips |
| Passenger count | +$0.13 \*\*\* | Larger groups tip more |
| Trip distance | not significant | Distance is already priced into the fare |

Full coefficients: [Appendix Table A2](#table-a2--full-tobit-model-coefficients).

**What it means for drivers.** The dollar story reinforces the probability story:
airport pickups are the clearest win, mornings and weekends are mildly
tip-suppressing, and — usefully — the negative duration effect alongside the
positive fare effect says that a slow, low-fare crawl is the worst combination
for tips, while a high-fare run is rewarded.

### 3.5 Robustness

**Two-part model (Cragg, 1971).** We separate the two decisions: Part 1 is a logit
for P(tip > 0); Part 2 is an OLS of log(tip) on the same predictors among trips
that did tip. If the two parts agree in sign with each other and with the Tobit,
the single-process assumption is reasonable; if they diverge, the decisions are
governed by different mechanisms.

For the policy-relevant variables (fare, airport, weekend, time of day, passenger
count) the two parts agree in sign, supporting Tobit as an adequate summary. The
one informative exception is **trip duration**: it lowers the probability of
tipping (Part 1 ≈ −0.084) but raises the amount among those who do tip
(Part 2 ≈ +0.017). This is economically sensible — long rides discourage some
passengers from tipping at all, but those who do tip on a long ride give more —
and it is precisely the kind of nuance the single-process Tobit cannot capture.
See [Appendix Table A3](#table-a3--tobit-vs-two-part-model-coefficient-comparison).

**Threshold sensitivity.** Our 15%/20% category cut-offs are conventional but not
unique. Re-estimating the MNL at 10%/25% and 12%/22% leaves the direction of the
key effects unchanged (airport strongly reduces no-tip; weekend increases it);
only magnitudes and fit statistics move. See
[Appendix Table A4](#table-a4--threshold-sensitivity).

### 3.6 Critical reflection

Three honest caveats temper the advice. First, explanatory power is modest
(McFadden R² ≈ 0.07): individual tipping is intrinsically noisy and heavily shaped
by the POS default screen, which the data don't record. Second, the 74.3% hit rate
barely improves on a naïve rule of always guessing "generous" (72.2%) — the model
is far better at explaining associations than at classifying individual trips, and
we present it as the former. Third, IIA is rejected, so category-to-category odds
should be read as indicative. None of this undermines the robust, repeatable
signals — airport, group size, weekend, time of day — which is what the advice
rests on.

---

## 4. Challenge 2 — The Morning Launch

### 4.1 Problem, unit of analysis, and defining "success"

A driver starting a morning shift wants to be where the trips are. We therefore
model demand volume directly. The unit of analysis is a **pickup zone × day**: one
observation is one Manhattan zone on one morning (6–11 a.m.), and the dependent
variable is the count of trips starting there that morning.

We deliberately define success as the raw trip count rather than a constructed
"successful-trip" indicator. Thresholds for a "high-demand zone" or an "hourly
median" would be arbitrary and ill-defined; modelling the count itself sidesteps
that entirely and keeps the output interpretable as "expected pickups," which is
exactly what a driver wants to know.

### 4.2 Modelling choices: structure over fixed effects, and the Manhattan focus

**Why not zone fixed effects.** The intuitive move is zone dummies, but it creates
two problems. (i) Fixed effects would absorb the very zone characteristics we want
to explain, and would collide with any socio-economic zone variable we add.
(ii) Even if estimated, hundreds of zone dummies produce no usable advice — a
driver cannot memorise a coefficient per zone, and the model never explains *why*
a zone is busy. We instead include an observable structural predictor — **zone
labour force** (employed working-age residents per neighbourhood) — which both
identifies high-demand zones and explains them: morning demand is a commuting
phenomenon.

**Why Manhattan.** Manhattan accounts for ~85% of morning trips and has only 12.9%
zero zone-days, versus 55–95% in the outer boroughs. Those outer-borough zeros
largely reflect the sampling of a 100k-trip extract rather than a true absence of
demand, and would bias the count models. We restrict the main analysis to
Manhattan and verify directional consistency across all boroughs in §4.6.

**Building the panel.** We construct the full zone × day grid (**64 zones × 28
days = 1,792 observations**) and fill mornings with no observed trips as explicit
zeros. This matters: aggregating only the zone-days we happen to observe would
truncate the sample at the bottom, never letting the model see a zero, and would
bias expected counts upward.

### 4.3 Overdispersion and model choice (Poisson vs. Negative Binomial)

The count data are heavily overdispersed: **variance-to-mean ratio = 8.81**, far
above the Poisson assumption of 1. We therefore estimate a Poisson baseline
(Week 5) and the preferred Negative Binomial, which adds a dispersion parameter
(variance = μ + αμ²).

| Model | Log-lik. | AIC | BIC | McFadden R² |
| --- | --- | --- | --- | --- |
| Poisson | −8,605 | 17,222 | 17,255 | 0.133 |
| Negative Binomial | −5,430 | 10,873 | 10,912 | 0.453 |

The Negative Binomial dominates on every criterion. The LR test of Poisson vs. NB
gives χ²(1) = 6,350.7, p < 0.001 (boundary-adjusted), and the estimated dispersion
is large (θ = 1.208, i.e. α ≈ 0.828) — overdispersion is real and the Poisson is
firmly rejected. All inference below uses the Negative Binomial.

### 4.4 Negative Binomial results — incidence rate ratios

Coefficients are read as incidence rate ratios (IRR = e^β): the multiplicative
change in expected morning trips.

| Predictor | IRR | 95% CI | SE | p | Reading |
| --- | --- | --- | --- | --- | --- |
| Weekend | 0.554 | 0.499–0.615 | 0.053 | < 0.001 | A weekend morning has 44.6% fewer trips than a comparable weekday |
| Snowfall (per cm) | 0.783 | 0.718–0.854 | 0.044 | < 0.001 | Each extra cm of morning snow cuts trips by ~21.7% |
| Temperature (per °C) | 0.995 | 0.985–1.005 | 0.005 | 0.301 | No significant effect once dispersion is handled |
| Precipitation (per mm) | 0.969 | 0.916–1.024 | 0.028 | 0.265 | Not significant (largely absorbed by snowfall on winter days) |
| Zone labour force | see note | — | — | < 0.001 \*\*\* | Higher labour-force zones attract systematically more morning trips |

Estimated dispersion θ = 1.208 (SE = 0.050), α = 0.828, confirming substantial
overdispersion far above the Poisson assumption. n = 1,792 zone-days.

A methodological aside worth a sentence: **temperature was significant under
Poisson but is not under Negative Binomial** — a clean illustration of why
handling overdispersion before drawing inference matters.

> **Note on labour-force variable scaling.** Zone labour force is expressed in
> thousands of employed residents (values 0.03–0.06). The model returns a large
> raw IRR because the scale is compressed, but the interpretation is clean: each
> 100 additional working residents is associated with approximately **2.3% more
> morning trips** (exp(22.57 × 0.001) ≈ 1.023). The direction is robust and is the
> actionable result — zones with more working residents generate more morning
> pickups.

### 4.5 Zone rankings — the deliverable

Holding conditions fixed (typical weekday, average February temperature, no
precipitation) to isolate structural demand, the highest-demand morning zones are:

| Rank | Zone | Predicted morning trips |
| --- | --- | --- |
| 1–2 | Upper West Side (North / South) | 17.5 |
| 3–4 | Yorkville (East / West) | 14.6 |
| 5–7 | Lenox Hill (East / West), Roosevelt Island | 14.5 |
| 8 | Washington Heights North | 13.3 |
| 9 | Central Harlem North | 13.2 |
| 10–12 | East Chelsea, Flatiron, West Chelsea | 12.6 |

For context, the Manhattan-wide morning average is roughly 8 trips per
zone-morning, so the top zones offer roughly **double** the typical pickup rate.
Full top-20: [Appendix Table A5](#table-a5--full-top-20-manhattan-zones-by-predicted-morning-demand).

One ranking deserves a caveat we make openly: **Roosevelt Island** ranks high on
predicted demand (driven by its resident labour force) but has an observed average
of only ~0.32 trips per morning. The gap signals that resident labour force is an
imperfect proxy for taxi demand in places with strong alternative transit (the
island's tram/subway) — a useful reminder that the model explains structural
propensity, not realised ridership everywhere.

### 4.6 Robustness

**Weekday vs. weekend stability.** Re-ranking zones for weekend conditions leaves
the top-10 identical (10/10). The weekend effect scales every zone down by the
same 44.6% without reordering them — structural zone characteristics dominate
day-of-week variation, so the "where to start" advice is stable regardless of the
day.

**All-borough check.** Re-estimating across all five boroughs (with borough
indicators) preserves the key directions: weekend IRR = 0.603 (95% CI:
0.554–0.655) and snowfall IRR = 0.803 (95% CI: 0.748–0.862), both p < 0.001, with
Manhattan carrying far the highest baseline demand (~20× the Bronx reference).
Full-borough model: n = 6,496 zone-days, 232 zones, borough dummies. The
Manhattan-focused conclusions are not an artifact of the sample restriction.

### 4.7 Critical reflection

The model gives clear, robust directional guidance, with three honest limits. The
labour-force scaling issue above means we lead with rankings and signs, not the
literal per-worker IRR. The Roosevelt Island case shows resident labour force is a
good but imperfect demand proxy where transit substitutes exist. And restricting
to Manhattan trades some generality for cleaner estimation — defensible given
where morning demand actually is, and checked against the all-borough model.
Within these bounds, "start in the Upper West Side / Yorkville corridor, expect
roughly double the average, and discount heavily for snow and weekends" is well
supported.

---

## 5. Conclusion and Strategic Advice

Pulling the two challenges together, our advice to a CusMo driver is concrete and,
importantly, internally consistent once the morning trade-off is made explicit.

1. **Position for the morning rush in the Upper West Side / Yorkville / Lenox Hill
   corridor.** These zones deliver the most morning pickups — roughly double the
   Manhattan average — because they are dense with working residents commuting
   out. This holds on weekdays and weekends alike.
2. **Treat the airport as the tipping play, not the volume play.** Airport pickups
   are the single strongest driver of both whether a passenger tips and how much
   (about +$2.59 per trip). A driver optimising tip income should weight airport
   runs heavily; a driver optimising morning volume should weight the residential
   corridor above.
3. **Mind the morning trade-off.** Mornings maximise volume (Challenge 2) but are
   the weakest tipping window (Challenge 1). The right call depends on the
   driver's mix of fare vs. tip income — a genuinely useful tension to surface
   rather than paper over.
4. **Discount for weather and weekends.** Each cm of morning snow cuts expected
   pickups by ~22%, and weekend mornings run ~45% below weekdays. On heavy-snow
   days, repositioning into the high-density corridor (which keeps its relative
   advantage) beats waiting in thinner zones.
5. **Larger groups are good news.** Contrary to intuition, bigger parties tip more
   reliably — no reason to avoid them.

**Overall limitations.** These are associations in a one-month observational
extract, not causal effects; tipping is dominated by an unrecorded POS-default
mechanism; cash behaviour is invisible by construction; and the morning model
leans on a residential proxy for demand. We have been explicit about each so the
advice is used with the right confidence — strong on direction and ranking,
lighter on precise magnitudes.

---

## 6. References

Course slides cited as: Hars, R. (2025/2026). *Customer Models, Lectures 3–5.*
University of Groningen, Faculty of Economics and Business.

- Cragg, J. G. (1971). Some statistical models for limited dependent variables
  with application to the demand for durable goods. *Econometrica, 39*(5),
  829–844.
- Hausman, J., & McFadden, D. (1984). Specification tests for the multinomial
  logit model. *Econometrica, 52*(5), 1219–1240.
- McFadden, D. (1974). Conditional logit analysis of qualitative choice behavior.
  In P. Zarembka (Ed.), *Frontiers in Econometrics.* Academic Press.
- Tobin, J. (1958). Estimation of relationships for limited dependent variables.
  *Econometrica, 26*(1), 24–36.
- Cameron, A. C., & Trivedi, P. K. (2013). *Regression Analysis of Count Data*
  (2nd ed.). Cambridge University Press.
- Data sources: NYC Taxi & Limousine Commission trip records (Feb 2026); NYC
  Department of City Planning, neighbourhood (NTA) demographic and labour-force
  data; Open-Meteo historical weather API.

---

## Appendix

### Table A1 — Full MNL coefficient matrix

All three equations (`no_tip`, `low`, `standard` vs `generous`), coefficients with
standard errors in parentheses.

| Predictor | no_tip vs generous | low vs generous | standard vs generous |
| --- | --- | --- | --- |
| (Intercept) | −3.156 (0.054) \*\*\* | −2.390 (0.043) \*\*\* | −2.392 (0.055) \*\*\* |
| `fare_amount` | −0.025 (0.002) \*\*\* | +0.018 (0.002) \*\*\* | +0.003 (0.003) |
| `trip_distance` | +0.001 (0.001) | −0.055 (0.007) \*\*\* | −0.005 (0.012) |
| `trip_duration_min` | +0.087 (0.002) \*\*\* | +0.022 (0.002) \*\*\* | −0.001 (0.003) |
| `airport_pickup` | −1.881 (0.091) \*\*\* | −0.309 (0.062) \*\*\* | −0.158 (0.093) . |
| morning (vs afternoon) | −0.519 (0.044) \*\*\* | +0.182 (0.040) \*\*\* | +0.103 (0.051) \* |
| evening (vs afternoon) | −0.214 (0.043) \*\*\* | +0.008 (0.034) | +0.037 (0.043) |
| night (vs afternoon) | +0.239 (0.048) \*\*\* | +0.170 (0.039) \*\*\* | +0.027 (0.050) |
| `weekend` | +0.266 (0.037) \*\*\* | +0.102 (0.030) \*\*\* | −0.083 (0.039) \* |
| `passenger_count` | −0.239 (0.032) \*\*\* | −0.051 (0.021) \* | −0.005 (0.027) |

McFadden R² = 0.072 | AIC = 96,442 | Hit rate = 74.3% | LR test vs null:
χ²(27) = 7,474.8, p < 0.001

### Table A2 — Full Tobit model coefficients

Dependent variable: `tip_amount` ($). Left-censored at 0. Corner-solution framing.

| Predictor | β (raw coef.) | Std. Error | z value | p-value |
| --- | --- | --- | --- | --- |
| (Intercept) | 1.584 | 0.037 | 43.37 | < 0.001 \*\*\* |
| `fare_amount` | 0.184 | 0.001 | 141.43 | < 0.001 \*\*\* |
| `trip_distance` | 0.000 | 0.001 | 0.23 | 0.817 |
| `trip_duration_min` | −0.084 | 0.001 | −63.39 | < 0.001 \*\*\* |
| `airport_pickup` | 2.813 | 0.058 | 48.62 | < 0.001 \*\*\* |
| morning (vs afternoon) | −0.457 | 0.036 | −12.71 | < 0.001 \*\*\* |
| evening (vs afternoon) | 0.285 | 0.030 | 9.44 | < 0.001 \*\*\* |
| night (vs afternoon) | −0.083 | 0.035 | −2.37 | 0.018 \* |
| `weekend` | −0.248 | 0.027 | −9.13 | < 0.001 \*\*\* |
| `passenger_count` | 0.136 | 0.019 | 7.13 | < 0.001 \*\*\* |
| Log(scale) | 1.042 | 0.003 | 330.09 | < 0.001 \*\*\* |

AIC = 273,583.8 | Scale (σ) = 2.835 | Wald statistic = 61,550 (df = 9), p < 0.001

### Table A3 — Tobit vs. two-part model coefficient comparison

| Predictor | Tobit (β) | Part 1 — logit P(tip>0) | Part 2 — OLS log(tip) \| tip>0 |
| --- | --- | --- | --- |
| (Intercept) | 1.584 | 3.300 | 0.681 |
| `fare_amount` | 0.184 | 0.026 | 0.015 |
| `trip_distance` | 0.000 | −0.001 | 0.000 |
| `trip_duration_min` | −0.084 | −0.084 | **+0.017** |
| `airport_pickup` | 2.813 | 1.805 | 0.174 |
| morning (vs afternoon) | −0.457 | −0.486 | −0.015 |
| evening (vs afternoon) | +0.285 | +0.217 | +0.066 |
| night (vs afternoon) | −0.083 | −0.217 | **+0.075** |
| `weekend` | −0.248 | −0.259 | −0.036 |
| `passenger_count` | +0.136 | +0.233 | +0.000 |

Bold entries mark the sign disagreements between the two parts — the cases the
single-process Tobit cannot represent.

### Table A4 — Threshold sensitivity

MNL re-estimated at alternative generosity cut-offs.

| Specification | McFadden R² | AIC | Hit rate | airport coef. (no_tip eq.) | weekend coef. (no_tip eq.) |
| --- | --- | --- | --- | --- | --- |
| **Base: low<15 / standard=[15,20] / generous>20** | 0.072 | 96,442 | 74.3% | −1.881 \*\*\* | +0.266 \*\*\* |
| Alt 1: low<10 / standard=[10,25] / generous>25 | 0.126 | 106,481 | 74.3% | negative \*\*\* | positive \*\*\* |
| Alt 2: low<12 / standard=[12,22] / generous>22 | 0.076 | 102,529 | 74.3% | negative \*\*\* | positive \*\*\* |

The base row is the main specification used throughout the report.

### Table A5 — Full top-20 Manhattan zones by predicted morning demand

Predicted trips under standardised conditions: typical weekday, average February
temperature, no precipitation.

| Rank | Zone name | Zone LF (thousands) | Observed avg (all days) | Predicted trips (typical weekday) |
| --- | --- | --- | --- | --- |
| 1 | Upper West Side North | 0.0567 | 18.14 | 17.53 |
| 2 | Upper West Side South | 0.0567 | 18.29 | 17.53 |
| 3 | Yorkville East | 0.0486 | 17.75 | 14.61 |
| 4 | Yorkville West | 0.0486 | 16.61 | 14.61 |
| 5 | Lenox Hill East | 0.0484 | 16.04 | 14.53 |
| 6 | Lenox Hill West | 0.0484 | 18.18 | 14.53 |
| 7 | Roosevelt Island | 0.0484 | 0.32 | 14.53 |
| 8 | Washington Heights North | 0.0445 | 1.50 | 13.30 |
| 9 | Central Harlem North | 0.0440 | 4.64 | 13.16 |
| 10 | East Chelsea | 0.0420 | 11.00 | 12.59 |
| 11 | Flatiron | 0.0420 | 8.18 | 12.59 |
| 12 | West Chelsea / Hudson Yards | 0.0420 | 6.00 | 12.59 |
| 13 | Washington Heights South | 0.0408 | 2.64 | 12.24 |
| 14 | Alphabet City | 0.0402 | 2.79 | 12.09 |
| 15 | East Village | 0.0402 | 11.18 | 12.09 |
| 16 | Lincoln Square East | 0.0402 | 15.21 | 12.08 |
| 17 | Lincoln Square West | 0.0402 | 11.86 | 12.08 |
| 18 | Clinton East | 0.0380 | 13.68 | 11.48 |
| 19 | Clinton West | 0.0380 | 5.82 | 11.48 |
| 20 | Kips Bay | 0.0374 | 8.57 | 11.33 |

Manhattan-wide morning average = 7.98 trips per zone-day. Top zones deliver
roughly 2× the average. Weekend demand is uniformly ~44.6% lower but zone ranking
is identical (top-10 stable 10/10).
