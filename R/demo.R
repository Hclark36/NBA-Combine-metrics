# Synthetic fixture for software verification only. All names and IDs are invented.
demo_inputs <- function(cfg) {
  set.seed(cfg$seed)
  years <- rep(cfg$combine_years, each = 40)
  n <- length(years)
  pos <- sample(c('PG', 'SG', 'SF', 'PF', 'C'), n, replace = TRUE)
  height <- rnorm(n, 75 + match(pos, c('PG', 'SG', 'SF', 'PF', 'C')), 1.6)
  lane <- rnorm(n, 11.2 + (height - 78) * .06, .5)
  drills <- data.frame(player_id = 900000 + seq_len(n),
    player_name = sprintf('Demo prospect %03d', seq_len(n)), position = pos,
    combine_year = years, lane_agility_time = lane,
    modified_lane_agility_time = rnorm(n, 3.1, .2),
    three_quarter_sprint = rnorm(n, 3.3, .15),
    standing_vertical_leap = rnorm(n, 29, 3), max_vertical_leap = rnorm(n, 35, 3.5),
    bench_press = sample(0:20, n, replace = TRUE))
  anthro <- data.frame(player_id = drills$player_id, combine_year = years,
    height_wo_shoes = height, wingspan = height + rnorm(n, 5, 2),
    weight = 210 + (height - 78) * 8 + rnorm(n, 0, 12))
  # Inject missing features and unmatched players to exercise the audit.
  drills$lane_agility_time[sample(n, 25)] <- NA
  drills$modified_lane_agility_time[sample(n, 70)] <- NA
  anthro$weight[sample(n, 20)] <- NA
  unavailable <- sample(n, 35)
  true_gap <- -.01 + .012 * (lane - 11.2) + rnorm(n, 0, .02)
  defense <- dplyr::bind_rows(lapply(seq_len(cfg$window_seasons), function(k) {
    attempts <- sample(20:400, n, replace = TRUE)
    result <- data.frame(close_def_person_id = drills$player_id,
      season_start = years + k - 1L, d_fga = attempts,
      d_fgm = rbinom(n, attempts, pmin(.7, pmax(.2, .46 + true_gap))),
      normal_fg_pct = .46)
    result <- result[-unavailable, ]
    result[result$season_start %in% cfg$season_starts, ]
  }))
  list(drills = drills, anthro = anthro, defense = defense)
}
