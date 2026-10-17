if (dir.exists('.Rlib')) .libPaths(c(normalizePath('.Rlib'), .libPaths()))
library(testthat)
source('config.R')
for (file in c('api', 'archive', 'data', 'model', 'robustness', 'demo')) source(paste0('R/', file, '.R'))

test_that('archive import rejects wrong seasons and per-game units', {
  body <- '{"parameters":{"Season":"2025-26","PerMode":"Totals"},"resultSets":[{"headers":["CLOSE_DEF_PERSON_ID","D_FGA"],"rowSet":[[1,100]]}]}'
  expect_equal(validate_archive(body, c('D_FGA'),
    list(Season = '2025-26', PerMode = 'Totals'), 'fixture')$d_fga, 100)
  expect_error(validate_archive(body, c('D_FGA'),
    list(Season = '2024-25'), 'fixture'), 'parameter mismatch: Season')
  expect_error(validate_archive(body, c('D_FGA'),
    list(PerMode = 'PerGame'), 'fixture'), 'parameter mismatch: PerMode')
})

test_that('committed latest-season snapshot contains exact valid totals', {
  path <- 'data/snapshots/defense_2025-26.csv'
  if (!file.exists(path)) skip('Snapshot not present')
  d <- read.csv(path)
  expect_equal(nrow(d), 580L)
  expect_true(all(d$season_start == 2025L))
  expect_equal(anyDuplicated(d$close_def_person_id), 0L)
  expect_true(all(d$d_fga >= d$d_fgm & d$d_fgm >= 0))
  expect_true(all(d$d_fga == round(d$d_fga)))
  expect_true(all(d$normal_fg_pct >= 0 & d$normal_fg_pct <= 1))
  expect_equal(digest::digest(file = path, algo = 'sha256'),
    jsonlite::read_json('data/snapshots/defense_2025-26.metadata.json')$csv_sha256)
})

test_that('NBA JSON parsing preserves nulls and rejects incompatible schemas', {
  body <- '{"resultSets":[{"headers":["PLAYER_ID","LANE_AGILITY_TIME"],"rowSet":[[1,null],[2,11.2]]}]}'
  x <- parse_result(body, c('PLAYER_ID', 'LANE_AGILITY_TIME'))
  expect_equal(x$player_id, c(1, 2))
  expect_true(is.na(x$lane_agility_time[1]))
  expect_equal(x$lane_agility_time[2], 11.2)
  expect_error(parse_result(body, 'MISSING'), 'Expected exactly one')
  expect_error(parse_result('{"resultSets":[]}', 'PLAYER_ID'), 'Expected exactly one')
})

test_that('outcomes pool attempts and matching uses IDs instead of names', {
  cfg <- config
  cfg$combine_years <- 2019L
  cfg$season_starts <- 2019:2021
  cfg$min_defended_attempts <- 1L
  drills <- data.frame(player_id = c(1, NA), player_name = c('Same name', 'Same name'),
    position = 'SG', combine_year = 2019L, lane_agility_time = 11)
  anthro <- data.frame(player_id = c(1, NA), combine_year = 2019L,
    height_wo_shoes = c(77, 99), wingspan = c(81, 99), weight = c(210, 999))
  defense <- data.frame(close_def_person_id = 1, season_start = 2019:2021,
    d_fgm = c(10, 60, 30), d_fga = c(20, 100, 80), normal_fg_pct = c(.5, .6, .5))
  out <- prepare_data(list(drills = drills, anthro = anthro, defense = defense), cfg)
  expect_equal(out$analysis$defended_attempts, 200)
  expect_equal(out$analysis$defense_gap_pp, -5) # 100/200 minus 110/200
  expect_equal(nrow(out$analysis), 1L)
  expect_true(is.na(out$cohort$height_wo_shoes[2]))
  expect_equal(out$cohort$status[2], 'Missing NBA player ID')
  broken <- defense[c(1, 1, 2, 3), ]
  expect_error(prepare_data(list(drills = drills, anthro = anthro, defense = broken), cfg), 'duplicate keys')
  bad <- defense
  bad$normal_fg_pct <- 50
  expect_error(prepare_data(list(drills = drills, anthro = anthro, defense = bad), cfg), 'Invalid defensive units')
})

test_that('later repeat attendees and incomplete calendar windows are audited', {
  inputs <- demo_inputs(config)
  repeat_drill <- inputs$drills[1, ]
  repeat_drill$combine_year <- repeat_drill$combine_year + 1
  repeat_anthro <- inputs$anthro[1, ]
  repeat_anthro$combine_year <- repeat_anthro$combine_year + 1
  inputs$drills <- rbind(inputs$drills, repeat_drill)
  inputs$anthro <- rbind(inputs$anthro, repeat_anthro)
  out <- prepare_data(inputs, config)
  expect_equal(nrow(out$repeated), 1L)
  expect_equal(sum(out$cohort$player_id == repeat_drill$player_id), 1L)
  cfg <- config
  cfg$season_starts <- 2013:2023
  out <- prepare_data(demo_inputs(cfg), cfg)
  expect_true(all(out$cohort$status[out$cohort$combine_year >= 2022] == 'Incomplete calendar window'))
})

test_that('preprocessing uses training medians and reports missing features', {
  train <- data.frame(height_wo_shoes = c(75, 77, NA), position_group = c('G', 'F', 'C'))
  test <- data.frame(height_wo_shoes = c(NA, 999), position_group = c('Other', 'G'))
  a <- design(train, 'height_wo_shoes')
  b <- design(test, 'height_wo_shoes', a$medians)
  expect_equal(a$medians[[1]], 76)
  expect_equal(unname(b$x[1, 'height_wo_shoes']), 76)
  expect_equal(unname(b$x[1, 'height_wo_shoes_missing']), 1)
  expect_identical(colnames(a$x), colnames(b$x))
})

test_that('held-out outcomes cannot affect tuning, fitted predictions, or response curves', {
  d <- prepare_data(demo_inputs(config), config)$analysis
  a <- evaluate_models(d, config)
  changed <- d
  mask <- changed$combine_year %in% a$test_years
  changed$defense_gap_pp[mask] <- changed$defense_gap_pp[mask] + 50
  b <- evaluate_models(changed, config)
  expect_true(max(a$train_years) < min(a$test_years))
  expect_true(max(a$train_years) + config$window_seasons <= min(a$test_years))
  expect_equal(a$embargo_years, c(2019, 2020))
  expect_equal(a$tuning, b$tuning)
  expect_equal(a$predictions$predicted, b$predictions$predicted)
  expect_equal(a$effects, b$effects)
  expect_true(all(a$metrics$players == a$test_n))
  expect_true(all(is.finite(a$metrics$rmse)))
})
test_that('paired bootstrap preserves player pairing, class strata, and RNG state', {
  # Each class has one player: resampling within a class must always return
  # that same player, including when its row index is greater than one.
  fixture <- dplyr::bind_rows(lapply(c('Size + position', '+ Lane agility', 'Full combine', 'Training mean'),
    function(m) data.frame(player_id = c(10, 20), combine_year = c(2022, 2023),
      defense_gap_pp = 0, model = m, predicted = if (m == '+ Lane agility') c(0, 0) else c(1, 2))))
  set.seed(12)
  state <- .Random.seed
  a <- paired_uncertainty(fixture, reps = 40, seed = 36)
  expect_identical(.Random.seed, state)
  b <- paired_uncertainty(fixture[nrow(fixture):1, ], reps = 40, seed = 36)
  expect_equal(a, b)
  agility <- a[a$comparison == '+ Lane agility', ]
  expect_equal(agility$delta_rmse, sqrt(2.5))
  expect_equal(agility$rmse_lower, agility$delta_rmse)
  expect_equal(agility$rmse_upper, agility$delta_rmse)
  equal <- a[a$comparison == 'Full combine', ]
  expect_equal(equal$delta_rmse, 0)
  expect_equal(equal$rmse_lower, 0)
  expect_equal(equal$rmse_upper, 0)
  expect_error(paired_uncertainty(fixture[-1, ], reps = 40), 'complete, finite paired')
  changed <- fixture
  changed$defense_gap_pp[1] <- 1
  expect_error(paired_uncertainty(changed, reps = 40), 'identical outcomes')
})

test_that('robustness rebuilds eligibility and uses purged chronological splits', {
  prepared <- prepare_data(demo_inputs(config), config)
  cfg <- config
  cfg$bootstrap_reps <- 40L
  cfg$robustness_thresholds <- c(50L, 100L)
  cfg$robustness_test_starts <- 2023L
  r <- run_robustness(prepared, cfg)
  expect_equal(r$planned_cases, 2L)
  expect_equal(nrow(r$skipped), 0L)
  expect_true(all(r$splits$train_end + cfg$window_seasons <= r$splits$test_start))
  expect_true(all(r$splits$train_end < r$splits$test_start))
  # A lower threshold cannot lose eligible players in the same test class.
  expect_gte(r$splits$test_players[r$splits$threshold == 50],
             r$splits$test_players[r$splits$threshold == 100])
  for (scenario in r$splits$scenario) {
    p <- r$predictions[r$predictions$scenario == scenario, ]
    expect_equal(length(unique(p$player_id)), nrow(p) / 4)
    expect_equal(sort(unique(p$combine_year)), 2023)
  }
})
test_that('shared widget hook preserves long HTML and is idempotent', {
  source('scripts/fix_widgets.R', local = TRUE)
  p <- tempfile(fileext = '.html')
  on.exit(unlink(p), add = TRUE)
  html <- paste0('<html><head><script>plugin();</script>',
    paste(rep('x', 1100000), collapse = ''),
    '<script>/*! jQuery vTest */ window.jQuery = {};</script></head><body>END</body></html>')
  writeLines(html, p)
  expect_true(fix_widget_order(p))
  out <- paste(readLines(p), collapse = '\n')
  expect_lt(regexpr('/*! jQuery', out, fixed = TRUE)[1], regexpr('plugin();', out, fixed = TRUE)[1])
  expect_true(endsWith(out, '</body></html>'))
  expect_false(fix_widget_order(p))
  expect_equal(paste(readLines(p), collapse = '\n'), out)
})
cat('Pipeline verification complete.\n')
