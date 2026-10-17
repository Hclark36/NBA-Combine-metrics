# Completed seasons only. A combine in year Y is followed by season Y-(Y+1).
# The analysis window is the three seasons AFTER the combine, not first three
# NBA appearances. No draft-history or name-based linkage is assumed.
config <- list(
  combine_years = 2013:2023,
  season_starts = 2013:2025,
  window_seasons = 3L,
  min_defended_attempts = 100L,
  holdout_classes = 3L,
  robustness_thresholds = c(50L, 100L, 250L, 500L),
  robustness_test_starts = 2021:2023,
  bootstrap_reps = 2000L,
  timeout_seconds = 20,
  request_pause_seconds = 1,
  seed = 36L
)
