# Customer Models — run the full analysis end to end.
# Usage (from the repository root):  Rscript R/run_all.R
#
# Both scripts download their inputs at runtime (taxi parquet + NTA tables from
# GitHub, weather from the Open-Meteo archive API), so an internet connection is
# required. Everything is written to ./output.

t0 <- Sys.time()

scripts <- c(
  "R/01_challenge1_tipping.R",
  "R/02_challenge2_morning_launch.R"
)

for (s in scripts) {
  cat("\n", strrep("=", 70), "\n", sep = "")
  cat("RUNNING: ", s, "\n", sep = "")
  cat(strrep("=", 70), "\n\n", sep = "")
  source(s, echo = FALSE)
}

cat("\nAll scripts completed in ",
    round(difftime(Sys.time(), t0, units = "mins"), 1), " minutes.\n", sep = "")
cat("Outputs are in ./output\n")
