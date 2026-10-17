# Paired, class-stratified bootstrap of held-out players, CONDITIONAL on fits.
# This does not refit models or estimate variation across future draft classes.
paired_uncertainty <- function(predictions, reps = 2000L, seed = 36L) {
  if (reps < 20L) stop('Use at least 20 bootstrap replicates.')
  assert_unique(predictions, c('player_id', 'model'), 'Bootstrap predictions')
  target_counts <- predictions |>
    dplyr::group_by(player_id) |>
    dplyr::summarise(n_targets = dplyr::n_distinct(defense_gap_pp),
                     n_classes = dplyr::n_distinct(combine_year), .groups = 'drop')
  if (any(target_counts$n_targets != 1L | target_counts$n_classes != 1L))
    stop('Models must use identical outcomes and classes per player.')
  models <- c('Size + position', '+ Lane agility', 'Full combine', 'Training mean')
  wide <- predictions |>
    dplyr::select(player_id, combine_year, defense_gap_pp, model, predicted) |>
    tidyr::pivot_wider(names_from = model, values_from = predicted) |>
    dplyr::arrange(combine_year, player_id)
  if (!all(models %in% names(wide)) ||
      any(!is.finite(as.matrix(wide[c('defense_gap_pp', models)]))))
    stop('Bootstrap requires complete, finite paired predictions from every model.')
  errors <- as.matrix(wide[models]) - wide$defense_gap_pp
  groups <- split(seq_len(nrow(wide)), wide$combine_year)
  delta <- function(indices) {
    rmse <- sqrt(colMeans(errors[indices, , drop = FALSE]^2))
    mae <- colMeans(abs(errors[indices, , drop = FALSE]))
    c(rmse[1] - rmse[-1], mae[1] - mae[-1])
  }
  # Retain the caller's RNG state so enabling diagnostics doesn't alter later work.
  had_seed <- exists('.Random.seed', envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) previous_seed <- get('.Random.seed', envir = .GlobalEnv)
  on.exit({
    if (had_seed) assign('.Random.seed', previous_seed, envir = .GlobalEnv)
    else if (exists('.Random.seed', envir = .GlobalEnv, inherits = FALSE))
      rm('.Random.seed', envir = .GlobalEnv)
  }, add = TRUE)
  set.seed(seed)
  draws <- replicate(reps, {
    indices <- unlist(lapply(groups, function(g) g[sample.int(length(g), length(g), replace = TRUE)]),
                      use.names = FALSE)
    delta(indices)
  })
  point <- delta(seq_len(nrow(wide)))
  limits <- apply(draws, 1, stats::quantile, probs = c(.025, .975), names = FALSE)
  data.frame(comparison = models[-1],
    delta_rmse = unname(point[1:3]), rmse_lower = limits[1, 1:3], rmse_upper = limits[2, 1:3],
    delta_mae = unname(point[4:6]), mae_lower = limits[1, 4:6], mae_upper = limits[2, 4:6],
    players = nrow(wide), classes = length(groups), bootstrap_reps = reps,
    seed = seed, interval = '95% paired percentile; players stratified by draft class',
    row.names = NULL)
}

run_robustness <- function(prepared, cfg) {
  scenarios <- list()
  skipped <- list()
  predictions <- list()
  splits <- list()
  latest_class <- max(prepared$analysis$combine_year)
  primary_years <- tail(sort(unique(prepared$analysis$combine_year)), cfg$holdout_classes)
  case_number <- 0L
  for (threshold in cfg$robustness_thresholds) {
    # Rebuild eligibility from the audited cohort; changing the threshold must
    # be able to restore players excluded by the primary 100-shot cutoff.
    eligible <- prepared$cohort |>
      dplyr::filter(is.finite(defense_gap_pp), defended_attempts >= threshold,
        is.finite(lane_agility_time), lane_agility_time > 0, !is.na(player_id), player_id > 0,
        status != 'Incomplete calendar window')
    for (start in cfg$robustness_test_starts) for (end in seq.int(start, latest_class)) {
      case_number <- case_number + 1L
      years <- seq.int(start, end)
      scenario <- paste0('shots_', threshold, '_test_', start, '_', end)
      local_cfg <- cfg
      local_cfg$holdout_classes <- length(years)
      attempt <- tryCatch({
        fit <- evaluate_models(eligible, local_cfg, test_years = years)
        seed <- if (threshold == cfg$min_defended_attempts && identical(as.integer(years), as.integer(primary_years)))
          cfg$seed else cfg$seed + case_number
        uncertainty <- paired_uncertainty(fit$predictions, cfg$bootstrap_reps, seed)
        list(fit = fit, uncertainty = uncertainty)
      }, error = function(e) e)
      if (inherits(attempt, 'error')) {
        skipped[[scenario]] <- data.frame(scenario = scenario, threshold = threshold,
          test_start = start, test_end = end, reason = conditionMessage(attempt))
        next
      }
      fit <- attempt$fit
      scenarios[[scenario]] <- dplyr::mutate(attempt$uncertainty,
        scenario = scenario, threshold = threshold, test_start = start, test_end = end,
        train_players = fit$train_n, train_start = min(fit$train_years), train_end = max(fit$train_years))
      predictions[[scenario]] <- dplyr::mutate(fit$predictions, scenario = scenario,
        threshold = threshold, test_start = start, test_end = end)
      splits[[scenario]] <- data.frame(scenario = scenario, threshold = threshold,
        train_years = paste(fit$train_years, collapse = ','),
        validation_years = paste(fit$validation_years, collapse = ','),
        embargo_years = paste(fit$embargo_years, collapse = ','),
        test_years = paste(fit$test_years, collapse = ','),
        train_end = max(fit$train_years), test_start = min(fit$test_years),
        train_players = fit$train_n, test_players = fit$test_n)
    }
  }
  if (!length(scenarios)) stop('No robustness scenarios could be evaluated; inspect eligibility and class coverage.')
  skipped <- dplyr::bind_rows(skipped)
  if (!ncol(skipped)) skipped <- data.frame(scenario = character(), threshold = integer(),
    test_start = integer(), test_end = integer(), reason = character())
  list(comparisons = dplyr::bind_rows(scenarios), predictions = dplyr::bind_rows(predictions),
       splits = dplyr::bind_rows(splits), skipped = skipped,
       planned_cases = case_number)
}
