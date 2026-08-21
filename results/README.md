# Results tables

These are the estimated model results reported in
[`../report/customer-models-report.md`](../report/customer-models-report.md),
transcribed here as CSVs so the headline numbers are readable without an R
installation.

They correspond to the run described in the report: the 100k-trip February 2026
yellow-cab extract, cleaned as documented in the scripts. Re-running
`Rscript R/run_all.R` regenerates the same tables (plus several more) into
`../output/`.

| File | Contents |
| --- | --- |
| `c1_mnl_coefficients.csv` | Full multinomial logit matrix — all three equations (`no_tip`, `low`, `standard`) against the `generous` reference, with standard errors and significance stars |
| `c1_tobit_coefficients.csv` | Tobit Type 1 coefficients, standard errors, z-values, and marginal effects on the expected tip in dollars |
| `c1_tobit_vs_twopart.csv` | Tobit against the Cragg two-part model, with the sign-agreement check that tests the single-process assumption |
| `c1_threshold_sensitivity.csv` | The multinomial logit re-estimated at three different generosity cut-offs |
| `c2_model_comparison.csv` | Poisson against Negative Binomial on log-likelihood, AIC, BIC, and McFadden R² |
| `c2_negbin_irr.csv` | Negative Binomial incidence rate ratios with 95% confidence intervals |
| `c2_top20_zones.csv` | The deliverable — top 20 Manhattan zones by predicted morning demand |

Significance codes follow R's convention: `***` p < 0.001, `**` p < 0.01,
`*` p < 0.05, `.` p < 0.1.
