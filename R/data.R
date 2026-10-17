numeric_fields <- function(data, fields) {
  for (field in fields) {
    if (!field %in% names(data)) data[[field]] <- NA_real_
    value <- trimws(as.character(data[[field]]))
    value[value %in% c('', 'NA', 'N/A', '-', 'NULL')] <- NA_character_
    parsed <- suppressWarnings(as.numeric(value))
    if (any(!is.na(value) & is.na(parsed))) stop('Non-numeric values in ', field)
    data[[field]] <- parsed
  }
  data
}

assert_unique <- function(data, keys, label) {
  if (anyDuplicated(data[keys])) stop(label, ' has duplicate keys: ', paste(keys, collapse = ', '))
}

position_group <- function(x) {
  x <- toupper(trimws(x))
  # Use the first listed position, consistently for hybrid positions.
  dplyr::case_when(grepl('^(PG|SG|G)', x) ~ 'G', grepl('^(SF|PF|F)', x) ~ 'F',
                  grepl('^C', x) ~ 'C', TRUE ~ 'Other')
}

prepare_data <- function(inputs, cfg) {
  drills <- numeric_fields(inputs$drills, c('player_id', 'lane_agility_time',
    'modified_lane_agility_time', 'three_quarter_sprint', 'standing_vertical_leap',
    'max_vertical_leap', 'bench_press'))
  anthro <- numeric_fields(inputs$anthro, c('player_id', 'height_wo_shoes', 'wingspan', 'weight'))
  defense <- numeric_fields(inputs$defense, c('close_def_person_id', 'd_fgm', 'd_fga', 'normal_fg_pct'))
  if (!all(cfg$season_starts %in% defense$season_start)) stop('Missing requested defensive season(s).')
  if (!all(cfg$combine_years %in% drills$combine_year) ||
      !all(cfg$combine_years %in% anthro$combine_year)) stop('Missing requested combine class(es).')
  # Do not infer IDs from names or merge unidentified players with one another.
  anthro <- dplyr::filter(anthro, !is.na(player_id), player_id > 0)
  defense <- dplyr::filter(defense, !is.na(close_def_person_id), close_def_person_id > 0)
  assert_unique(dplyr::filter(drills, !is.na(player_id), player_id > 0),
                c('player_id', 'combine_year'), 'Drill data')
  assert_unique(anthro, c('player_id', 'combine_year'), 'Anthropometric data')
  # Endpoint must return one league-wide row per player-season; never sum
  # both team rows and a total row for a traded player.
  assert_unique(defense, c('close_def_person_id', 'season_start'), 'Defense data')
  if (any(!is.finite(defense$d_fga) | !is.finite(defense$d_fgm) |
          !is.finite(defense$normal_fg_pct))) stop('Missing or invalid defensive totals.')
  if (any(defense$d_fga < defense$d_fgm | defense$d_fgm < 0 |
          defense$normal_fg_pct < 0 | defense$normal_fg_pct > 1)) stop('Invalid defensive units or totals.')
  # Repeated combine attendees use their earliest recorded combine.
  drills <- dplyr::arrange(drills, combine_year)
  drills$record_key <- seq_len(nrow(drills))
  duplicates <- !is.na(drills$player_id) & drills$player_id > 0 & duplicated(drills$player_id)
  repeated <- drills[duplicates, ]
  drills <- drills[!duplicates, ]
  drills <- drills |>
    dplyr::left_join(dplyr::select(anthro, player_id, combine_year, height_wo_shoes, wingspan, weight),
                     by = c('player_id', 'combine_year'), na_matches = 'never') |>
    dplyr::mutate(position_group = position_group(position))
  eligible_years <- cfg$combine_years[vapply(cfg$combine_years, function(y)
    all(seq.int(y, y + cfg$window_seasons - 1L) %in% cfg$season_starts), logical(1))]
  # An absent player row is not treated as zero defense or proof of no NBA career.
  windows <- drills |>
    dplyr::filter(!is.na(player_id), player_id > 0) |>
    dplyr::select(record_key, player_id, combine_year) |>
    dplyr::inner_join(defense, by = c('player_id' = 'close_def_person_id'),
                     relationship = 'many-to-many') |>
    dplyr::filter(season_start >= combine_year,
                  season_start < combine_year + cfg$window_seasons, d_fga > 0)
  outcomes <- windows |>
    dplyr::group_by(record_key) |>
    dplyr::summarise(defended_attempts = sum(d_fga), defended_makes = sum(d_fgm),
      normal_fg_pct = weighted.mean(normal_fg_pct, d_fga),
      observed_seasons = dplyr::n_distinct(season_start), .groups = 'drop') |>
    dplyr::mutate(defense_gap_pp = 100 * (defended_makes / defended_attempts - normal_fg_pct))
  cohort <- drills |>
    dplyr::left_join(outcomes, by = 'record_key') |>
    dplyr::mutate(status = dplyr::case_when(
      is.na(player_id) | player_id <= 0 ~ 'Missing NBA player ID',
      !combine_year %in% eligible_years ~ 'Incomplete calendar window',
      is.na(defended_attempts) ~ 'No matched defense observations',
      defended_attempts < cfg$min_defended_attempts ~ 'Below defended-shot threshold',
      is.na(lane_agility_time) | lane_agility_time <= 0 ~ 'Missing lane agility',
      TRUE ~ 'Included'))
  metrics <- c('lane_agility_time', 'modified_lane_agility_time', 'three_quarter_sprint',
               'max_vertical_leap', 'height_wo_shoes', 'wingspan', 'weight')
  coverage <- cohort |>
    dplyr::select(combine_year, dplyr::all_of(metrics)) |>
    tidyr::pivot_longer(-combine_year, names_to = 'metric', values_to = 'value') |>
    dplyr::group_by(combine_year, metric) |>
    dplyr::summarise(n = dplyr::n(), available = sum(!is.na(value)),
                     coverage_pct = 100 * mean(!is.na(value)), .groups = 'drop')
  recent <- cohort |>
    dplyr::filter(!combine_year %in% eligible_years) |>
    dplyr::mutate(available_calendar_seasons = vapply(combine_year, function(y)
      sum(seq.int(y, y + cfg$window_seasons - 1L) %in% cfg$season_starts), integer(1)),
      required_calendar_seasons = cfg$window_seasons,
      final_window_season = sprintf('%d-%02d', combine_year + cfg$window_seasons - 1L,
        (combine_year + cfg$window_seasons) %% 100L))
  list(cohort = cohort, analysis = dplyr::filter(cohort, status == 'Included'), recent = recent,
       coverage = coverage, flow = dplyr::count(cohort, status, name = 'players'),
       repeated = repeated, windows = windows,
       excluded_defense = if (is.null(inputs$excluded_defense)) data.frame() else inputs$excluded_defense)
}
