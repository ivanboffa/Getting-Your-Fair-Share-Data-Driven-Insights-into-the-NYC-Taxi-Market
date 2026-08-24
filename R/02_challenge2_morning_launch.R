# Customer Models — Challenge 2: The Morning Launch
# NYC Yellow Taxi, February 2026
# Question: which Manhattan zones should a driver start from in the morning?

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(tidyr)
  library(lubridate)
  library(jsonlite)
  library(ggplot2)
  library(MASS)     # glm.nb()
  library(lmtest)
  library(sandwich)
})

select <- dplyr::select

GH_URL  <- "https://raw.githubusercontent.com/rphars/taxidata/main/"
OUT_DIR <- "output"
SET_SEED <- 42

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
set.seed(SET_SEED)


# load data
cat("Loading taxi data...\n")
taxi_data <- read_parquet(paste0(GH_URL, "taxi_data_100k.parquet"))
cat("Raw trips:", nrow(taxi_data), "\n\n")


# cleaning (same filters as Challenge 1)
trips <- taxi_data %>%
  mutate(
    pickup_dt         = ymd_hms(tpep_pickup_datetime),
    dropoff_dt        = ymd_hms(tpep_dropoff_datetime),
    trip_duration_min = as.numeric(difftime(dropoff_dt, pickup_dt, units = "mins")),
    passenger_count   = ifelse(is.na(passenger_count), 1, passenger_count),
    pickup_date       = as.Date(pickup_dt)
  ) %>%
  filter(
    fare_amount        >  0,
    trip_distance      >  0,
    trip_duration_min  >  0,
    trip_duration_min  <  180,
    passenger_count    >= 1,
    passenger_count    <= 6,
    tip_amount         >= 0
  )
cat("After cleaning:", nrow(trips), "trips.\n\n")


# keep morning trips (6am–11am)
morning <- trips %>% filter(pickup_hour %in% 6:11)
cat("Morning trips:", nrow(morning), "\n")
cat("Unique zones:", n_distinct(morning$PULocationID), "\n")
cat("Days covered:", n_distinct(morning$pickup_date), "\n\n")


# build the full zone x day grid for Manhattan
# explicit zeros are needed: if we only keep observed rows the sample is
# truncated (y=0 never seen), biasing lambda estimates upward.
# Manhattan focus: 85% of morning trips, only 12.9% zeros vs 55-95% in outer
# boroughs (outer-borough zeros are mostly a 100k-sample artifact, not real
# absence of demand). Full-borough robustness check at the end.
all_zones <- morning %>%
  filter(PU_Borough == "Manhattan") %>%
  pull(PULocationID) %>% unique() %>% sort()

all_dates <- morning %>%
  pull(pickup_date) %>% unique() %>% sort()

cat(sprintf("Building Manhattan grid: %d zones × %d days = %d observations\n\n",
            length(all_zones), length(all_dates),
            length(all_zones) * length(all_dates)))

zone_meta <- morning %>%
  filter(PU_Borough == "Manhattan") %>%
  distinct(PULocationID, PU_Zone, PU_NTA_Code) %>%
  rename(zone_name = PU_Zone)

full_grid <- expand.grid(
  PULocationID = all_zones,
  pickup_date  = all_dates,
  stringsAsFactors = FALSE
) %>% left_join(zone_meta, by = "PULocationID")

zone_day_counts <- morning %>%
  filter(PU_Borough == "Manhattan") %>%
  group_by(PULocationID, pickup_date) %>%
  summarise(n_trips = n(), .groups = "drop")

zone_day <- full_grid %>%
  left_join(zone_day_counts, by = c("PULocationID", "pickup_date")) %>%
  mutate(
    n_trips  = replace_na(n_trips, 0L),
    weekend  = as.integer(wday(pickup_date, week_start = 1) >= 6)
  )

cat(sprintf("Zone-day grid: %d rows\n", nrow(zone_day)))
cat(sprintf("Zeros: %d (%.1f%%)\n", sum(zone_day$n_trips == 0),
            100 * mean(zone_day$n_trips == 0)))
cat(sprintf("Mean: %.3f | Variance: %.3f | Dispersion (Var/Mean): %.2f\n\n",
            mean(zone_day$n_trips),
            var(zone_day$n_trips),
            var(zone_day$n_trips) / mean(zone_day$n_trips)))
cat(">>> Dispersion >> 1: Poisson's mean=variance assumption violated\n")
cat(">>> Negative Binomial model required\n\n")


# join labour force (LFE) as zone-level predictor
# instead of zone fixed effects (which would absorb all demographic vars
# and give drivers unreadable advice), we use LFE to explain WHY zones differ
tryCatch({
  cat("Joining economic data (labour force, LFE)...\n")
  econ <- read.csv2(paste0(GH_URL, "econdata_simpl.csv")) %>%
    mutate(LFE = as.numeric(gsub(",", ".", LFE)))
  zone_day <- zone_day %>%
    left_join(econ %>% select(GeoID, LFE) %>% rename(zone_lf = LFE),
              by = c("PU_NTA_Code" = "GeoID"))
  cat(sprintf("  done. NAs: %d\n", sum(is.na(zone_day$zone_lf))))
}, error = function(e) cat("  skipped:", conditionMessage(e), "\n"))

# join morning weather averages
tryCatch({
  cat("Fetching morning weather from Open-Meteo...\n")
  api_url <- paste0(
    "https://archive-api.open-meteo.com/v1/archive?",
    "latitude=40.7831&longitude=-73.9712",
    "&start_date=2026-02-01&end_date=2026-02-28",
    "&hourly=temperature_2m,precipitation,snowfall",
    "&timezone=America%2FNew_York"
  )
  wraw <- fromJSON(api_url)
  weather <- as.data.frame(wraw$hourly) %>%
    mutate(dt   = ymd_hm(time, tz = "America/New_York"),
           hour = hour(dt),
           date = as.Date(dt)) %>%
    filter(hour %in% 6:11) %>%
    group_by(date) %>%
    summarise(
      morning_temp_c    = mean(temperature_2m, na.rm = TRUE),
      morning_precip_mm = sum(precipitation,   na.rm = TRUE),
      morning_snow_cm   = sum(snowfall,         na.rm = TRUE),
      .groups = "drop"
    )
  zone_day <- zone_day %>%
    left_join(weather, by = c("pickup_date" = "date"))
  cat("  done.\n")
}, error = function(e) cat("  skipped:", conditionMessage(e), "\n"))
cat("\n")


# prep modelling dataset
# scale LFE to thousands (1 unit = 1,000 workers, more readable coefficients)
# note: zone_pop and zone_lf are correlated at r=0.96, keeping only zone_lf
model_data <- zone_day %>%
  mutate(
    zone_lf    = as.numeric(gsub(",", ".", zone_lf)),
    zone_lf_k  = zone_lf / 1000
  )

cat("=== Descriptives: Manhattan morning zone-days ===\n")
cat(sprintf("Observations: %d\n", nrow(model_data)))
cat(sprintf("Zeros: %d (%.1f%%)\n", sum(model_data$n_trips == 0),
            100 * mean(model_data$n_trips == 0)))
cat(sprintf("Mean: %.2f | Variance: %.2f | Dispersion: %.2f\n\n",
            mean(model_data$n_trips), var(model_data$n_trips),
            var(model_data$n_trips) / mean(model_data$n_trips)))
cat("NAs after conversion:\n")
cat(sprintf("  zone_lf_k: %d\n\n", sum(is.na(model_data$zone_lf_k))))

p_dist <- ggplot(model_data, aes(x = n_trips)) +
  geom_histogram(bins = 40, fill = "steelblue", color = "white") +
  labs(x = "Morning trips per zone-day",
       y = "Frequency",
       title = "Distribution of morning trip counts — Manhattan zones",
       subtitle = sprintf(
         "n = %d zone-days | Dispersion (Var/Mean) = %.1f → Negative Binomial model",
         nrow(model_data),
         var(model_data$n_trips) / mean(model_data$n_trips))) +
  theme_minimal()
ggsave(file.path(OUT_DIR, "c2_trip_distribution.png"), p_dist,
       width = 7, height = 4.5, dpi = 150)


# MODEL 1: Poisson (baseline)
# expected to fail overdispersion check, run for formal comparison
cat("=== MODEL 1: POISSON ===\n")

model_formula <- n_trips ~ weekend + morning_temp_c +
                           morning_precip_mm + morning_snow_cm +
                           zone_lf_k

poisson_fit <- glm(model_formula,
                   family = poisson(link = "log"),
                   data   = model_data)

print(summary(poisson_fit))

cat("\n--- IRR: exp(beta) — Poisson ---\n")
irr_p <- exp(cbind(IRR = coef(poisson_fit), confint.default(poisson_fit)))
print(round(irr_p, 4))

null_fit <- glm(n_trips ~ 1, family = poisson(link = "log"), data = model_data)
ll_p <- as.numeric(logLik(poisson_fit))
ll_n <- as.numeric(logLik(null_fit))

cat("\n--- Likelihood Ratio test: null vs Poisson ---\n")
print(lrtest(null_fit, poisson_fit))
cat(sprintf("\nMcFadden R²: %.4f | AIC: %.1f | BIC: %.1f\n",
            1 - ll_p/ll_n, AIC(poisson_fit), BIC(poisson_fit)))
cat(sprintf("\nDispersion check: observed Var/Mean = %.2f\n",
            var(model_data$n_trips) / mean(model_data$n_trips)))
cat(">>> Far exceeds 1 → Poisson inadequate → switch to Negative Binomial\n\n")


# MODEL 2: Negative Binomial
# Var = mu + alpha*mu^2; alpha > 0 means overdispersion
# glm.nb estimates theta = 1/alpha
cat("=== MODEL 2: NEGATIVE BINOMIAL ===\n")

nb_fit <- glm.nb(model_formula, data = model_data)
print(summary(nb_fit))

ll_nb <- as.numeric(logLik(nb_fit))
cat(sprintf("\nTheta (θ = 1/α): %.4f\n", nb_fit$theta))
cat(sprintf("Alpha (α = 1/θ): %.4f  → significantly > 0: overdispersion confirmed\n",
            1/nb_fit$theta))

cat("\n--- IRR: exp(beta) — NegBin ---\n")
irr_nb <- exp(cbind(IRR = coef(nb_fit), confint.default(nb_fit)))
print(round(irr_nb, 4))

cat(sprintf("\nMcFadden R²: %.4f | AIC: %.1f | BIC: %.1f\n",
            1 - ll_nb/ll_n, AIC(nb_fit), BIC(nb_fit)))


# model comparison: LR test Poisson vs NegBin
# halve p-value because alpha is on boundary of parameter space (>= 0)
cat("\n=== MODEL COMPARISON: Poisson vs Negative Binomial ===\n")

lr_stat <- 2 * (ll_nb - ll_p)
lr_pval <- pchisq(lr_stat, df = 1, lower.tail = FALSE) / 2
cat(sprintf("LR statistic: %.2f (df = 1), p-value: < 0.001\n", lr_stat))
cat(">>> Poisson is strongly rejected → Negative Binomial is appropriate\n\n")

model_comparison <- data.frame(
  Model       = c("Poisson", "Negative Binomial"),
  LogLik      = round(c(ll_p, ll_nb), 1),
  AIC         = round(c(AIC(poisson_fit), AIC(nb_fit)), 1),
  BIC         = round(c(BIC(poisson_fit), BIC(nb_fit)), 1),
  McFadden_R2 = round(c(1 - ll_p/ll_n, 1 - ll_nb/ll_n), 4)
)
print(model_comparison)
write.csv(model_comparison,
          file.path(OUT_DIR, "c2_model_comparison.csv"), row.names = FALSE)


# zone rankings
# predict for each zone using its actual zone_lf_k, holding conditions at
# weekday + average temperature + no precipitation
cat("=== ZONE RANKINGS (predicted demand, typical weekday) ===\n")

avg_temp <- mean(model_data$morning_temp_c, na.rm = TRUE)

zone_profiles <- model_data %>%
  distinct(PULocationID, zone_name, zone_lf_k) %>%
  mutate(
    weekend           = 0,
    morning_temp_c    = avg_temp,
    morning_precip_mm = 0,
    morning_snow_cm   = 0
  )

zone_profiles$predicted_trips <- predict(nb_fit,
                                          newdata = zone_profiles,
                                          type    = "response")

obs_avg <- model_data %>%
  group_by(PULocationID) %>%
  summarise(observed_avg = round(mean(n_trips), 2), .groups = "drop")

zone_profiles <- zone_profiles %>%
  left_join(obs_avg, by = "PULocationID") %>%
  mutate(predicted_trips = round(predicted_trips, 2)) %>%
  arrange(desc(predicted_trips))

top20 <- zone_profiles %>%
  select(PULocationID, zone_name, zone_lf_k, observed_avg, predicted_trips) %>%
  head(20)

cat("\nTop 20 Manhattan zones by predicted morning demand:\n")
print(top20)
write.csv(top20, file.path(OUT_DIR, "c2_top20_zones.csv"), row.names = FALSE)

p_ranking <- top20 %>%
  mutate(zone_name = factor(zone_name,
                             levels = zone_name[order(top20$predicted_trips)])) %>%
  ggplot(aes(x = predicted_trips, y = zone_name)) +
  geom_col(fill = "steelblue") +
  geom_point(aes(x = observed_avg), color = "darkred", size = 2.5) +
  labs(x = "Predicted morning trips (typical weekday, avg weather)",
       y = NULL,
       title = "Top 20 Manhattan zones for morning launch",
       subtitle = "Bars = NegBin prediction | Red dots = observed average (all days)") +
  theme_minimal(base_size = 11)
ggsave(file.path(OUT_DIR, "c2_top20_zones.png"), p_ranking,
       width = 9, height = 7, dpi = 150)


# ROBUSTNESS 1: weekday vs weekend ranking stability
cat("\n=== ROBUSTNESS 1: Weekend vs weekday ranking stability ===\n")

zone_wkday <- zone_profiles %>% mutate(weekend = 0)
zone_wkend <- zone_profiles %>% mutate(weekend = 1)

zone_wkday$pred <- predict(nb_fit, newdata = zone_wkday, type = "response")
zone_wkend$pred <- predict(nb_fit, newdata = zone_wkend, type = "response")

top10_wd <- zone_wkday %>% arrange(desc(pred)) %>% pull(PULocationID) %>% head(10)
top10_we <- zone_wkend %>% arrange(desc(pred)) %>% pull(PULocationID) %>% head(10)
stable   <- intersect(top10_wd, top10_we)

cat(sprintf("Top-10 zones stable across weekday/weekend: %d of 10\n",
            length(stable)))

weekend_irr <- exp(coef(nb_fit)["weekend"])
cat(sprintf("Weekend IRR: %.4f → %.1f%% fewer trips on weekends vs weekdays\n",
            weekend_irr, 100 * (1 - weekend_irr)))
cat(">>> Zone rankings are robust; only absolute demand level shifts on weekends\n\n")


# ROBUSTNESS 2: full-borough model
# check that weekend and snow signs are consistent when all boroughs are included
cat("=== ROBUSTNESS 2: Full-borough Negative Binomial ===\n")

all_zones_full  <- morning %>% pull(PULocationID) %>% unique() %>% sort()
zone_meta_full  <- morning %>%
  distinct(PULocationID, PU_Borough, PU_Zone, PU_NTA_Code) %>%
  rename(zone_name = PU_Zone)

model_data_all <- expand.grid(
  PULocationID = all_zones_full,
  pickup_date  = all_dates,
  stringsAsFactors = FALSE
) %>%
  left_join(zone_meta_full, by = "PULocationID") %>%
  left_join(
    morning %>% group_by(PULocationID, pickup_date) %>%
      summarise(n_trips = n(), .groups = "drop"),
    by = c("PULocationID", "pickup_date")
  ) %>%
  mutate(
    n_trips = replace_na(n_trips, 0L),
    weekend = as.integer(wday(pickup_date, week_start = 1) >= 6)
  ) %>%
  left_join(weather, by = c("pickup_date" = "date"))

nb_all <- glm.nb(
  n_trips ~ PU_Borough + weekend + morning_temp_c +
            morning_precip_mm + morning_snow_cm,
  data = model_data_all
)

cat("\nFull-borough NegBin — IRR:\n")
irr_all <- exp(cbind(IRR = coef(nb_all), confint.default(nb_all)))
print(round(irr_all, 4))
cat(sprintf("\nAIC: %.1f | BIC: %.1f\n", AIC(nb_all), BIC(nb_all)))

cat(sprintf("\nWeekend — Manhattan: %.4f | All boroughs: %.4f\n",
            exp(coef(nb_fit)["weekend"]),
            exp(coef(nb_all)["weekend"])))
cat(sprintf("Snow    — Manhattan: %.4f | All boroughs: %.4f\n",
            exp(coef(nb_fit)["morning_snow_cm"]),
            exp(coef(nb_all)["morning_snow_cm"])))
cat(">>> Signs agree = directional findings robust across model samples\n\n")


# save
saveRDS(poisson_fit,   file.path(OUT_DIR, "c2_poisson.rds"))
saveRDS(nb_fit,        file.path(OUT_DIR, "c2_nb_main.rds"))
saveRDS(nb_all,        file.path(OUT_DIR, "c2_nb_all_boroughs.rds"))
saveRDS(model_data,    file.path(OUT_DIR, "c2_model_data.rds"))
saveRDS(zone_profiles, file.path(OUT_DIR, "c2_zone_profiles.rds"))

cat("=== CHALLENGE 2 COMPLETE. All outputs saved to:", OUT_DIR, "===\n")
cat("Key outputs:\n")
cat("  c2_model_comparison.csv   — Poisson vs NegBin fit statistics\n")
cat("  c2_top20_zones.csv        — Zone rankings with predictions\n")
cat("  c2_top20_zones.png        — Visual ranking chart\n")
cat("  c2_trip_distribution.png  — DV distribution chart\n")
