# Customer Models — package bootstrap
# Installs every package the two analysis scripts depend on.
# Run once before 01_/02_:  Rscript R/00_setup.R

required <- c(
  "arrow",      # read the parquet trip extract
  "dplyr",      # data wrangling
  "tidyr",      # replace_na() in Challenge 2
  "lubridate",  # timestamp handling
  "jsonlite",   # Open-Meteo weather API
  "ggplot2",    # figures
  "mlogit",     # multinomial logit (Challenge 1)
  "dfidx",      # index structure required by mlogit
  "AER",        # tobit() (Challenge 1)
  "MASS",       # glm.nb() (Challenge 2)
  "lmtest",     # likelihood-ratio tests
  "sandwich"    # robust covariance estimators
)

missing <- required[!(required %in% rownames(installed.packages()))]

if (length(missing) == 0) {
  cat("All", length(required), "required packages are already installed.\n")
} else {
  cat("Installing", length(missing), "missing package(s):",
      paste(missing, collapse = ", "), "\n")
  install.packages(missing, repos = "https://cloud.r-project.org")
}

still_missing <- required[!(required %in% rownames(installed.packages()))]
if (length(still_missing) > 0) {
  stop("Could not install: ", paste(still_missing, collapse = ", "),
       "\nOn Linux these usually need system libraries (libcurl, libssl, libxml2).")
}

cat("Setup complete. R version:", R.version.string, "\n")
