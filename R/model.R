# Every preprocessing statistic is learned from the current training fold.
feature_sets <- list(
  'Size + position' = c('height_wo_shoes', 'wingspan', 'weight', 'combine_year'),
  '+ Lane agility' = c('height_wo_shoes', 'wingspan', 'weight', 'combine_year', 'lane_agility_time'),
  'Full combine' = c('height_wo_shoes', 'wingspan', 'weight', 'combine_year',
    'lane_agility_time', 'modified_lane_agility_time', 'three_quarter_sprint',
    'standing_vertical_leap', 'max_vertical_leap', 'bench_press')
)

design <- function(data, fields, medians = NULL) {
  if (is.null(medians)) medians <- vapply(data[fields], function(x) {
    value <- median(x[is.finite(x)], na.rm = TRUE)
    if (is.finite(value)) value else 0
  }, numeric(1))
  values <- as.matrix(data[fields])
  missing <- !is.finite(values)
  for (j in seq_along(fields)) values[missing[, j], j] <- medians[j]
  colnames(missing) <- paste0(fields, '_missing')
  pos <- sapply(c('G', 'F', 'C', 'Other'), function(p) as.numeric(data$position_group == p))
  colnames(pos) <- paste0('position_', colnames(pos))
  list(x = cbind(values, missing * 1, pos), medians = medians)
}

fit_ridge <- function(train, test, fields, lambda) {
  a <- design(train, fields)
  b <- design(test, fields, a$medians)
  model <- glmnet::glmnet(a$x, train$defense_gap_pp, alpha = 0,
    lambda = sort(unique(c(lambda, 1000, 100, 10, 1, .1, .01)), decreasing = TRUE),
    standardize = TRUE)
  list(pred = as.numeric(predict(model, newx = b$x, s = lambda)),
       model = model, medians = a$medians, fields = fields, lambda = lambda)
}

evaluate_models <- function(data, cfg) {
  assert_unique(data, 'player_id', 'Model data')
  years <- sort(unique(data$combine_year))
  if (length(years) < cfg$holdout_classes + cfg$window_seasons + 5L || nrow(data) < 80L)
    stop('Need at least 80 eligible players and enough classes for purged rolling validation.')
  test_years <- tail(years, cfg$holdout_classes)
  # A class's final outcome season must end before the first test combine.
  # For a three-season window and a 2021 test combine, train through 2018;
  # 2019/2020 outcomes would not yet be fully observable at prediction time.
  train <- data[data$combine_year + cfg$window_seasons <= min(test_years), ]
  test <- data[data$combine_year %in% test_years, ]
  embargo_years <- setdiff(years, c(unique(train$combine_year), test_years))
  if (nrow(test) < 15L) stop('Too few held-out players (need 15).')
  train_years <- sort(unique(train$combine_year))
  validation_years <- train_years[vapply(train_years, function(y)
    sum(train_years + cfg$window_seasons <= y) >= 3L, logical(1))]
  if (!length(validation_years)) stop('Need three earlier, fully observed classes for a rolling validation fold.')
  lambdas <- c(.01, .1, 1, 10, 100)
  predictions <- list()
  tuning <- list()
  fits <- list()
  baseline <- mean(train$defense_gap_pp)
  predictions[['Training mean']] <- dplyr::mutate(test, model = 'Training mean', predicted = baseline)
  for (name in names(feature_sets)) {
    fields <- feature_sets[[name]]
    scores <- lapply(lambdas, function(lambda) {
      errors <- unlist(lapply(validation_years, function(year) {
        a <- train[train$combine_year + cfg$window_seasons <= year, ]
        b <- train[train$combine_year == year, ]
        if (nrow(a) < 20L) return(numeric())
        pred <- fit_ridge(a, b, fields, lambda)$pred
        (pred - b$defense_gap_pp)^2
      }))
      if (!length(errors)) stop('No usable rolling validation folds.')
      data.frame(model = name, lambda = lambda, validation_rmse = sqrt(mean(errors)))
    }) |>
      dplyr::bind_rows()
    best <- scores$lambda[which.min(scores$validation_rmse)]
    fit <- fit_ridge(train, test, fields, best)
    predictions[[name]] <- dplyr::mutate(test, model = name, predicted = fit$pred)
    tuning[[name]] <- scores
    fits[[name]] <- fit
  }
  pred <- dplyr::bind_rows(predictions)
  metrics <- pred |>
    dplyr::group_by(model) |>
    dplyr::summarise(players = dplyr::n(), rmse = sqrt(mean((predicted - defense_gap_pp)^2)),
      mae = mean(abs(predicted - defense_gap_pp)), .groups = 'drop')
  # Position/size-adjusted model response, not a causal estimate or confidence band.
  grid <- seq(quantile(train$lane_agility_time, .05), quantile(train$lane_agility_time, .95), length.out = 35)
  fit <- fits[['+ Lane agility']]
  effects <- dplyr::bind_rows(lapply(grid, function(value) {
    modified <- train
    modified$lane_agility_time <- value
    x <- design(modified, fit$fields, fit$medians)$x
    data.frame(lane_agility_time = value,
      predicted_gap = mean(as.numeric(predict(fit$model, newx = x, s = fit$lambda))))
  }))
  list(metrics = metrics, predictions = pred, tuning = dplyr::bind_rows(tuning),
       effects = effects, train_years = train_years, test_years = test_years,
       embargo_years = embargo_years, validation_years = validation_years,
       train_n = nrow(train), test_n = nrow(test), fits = fits)
}
