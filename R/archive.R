# Exact NBA endpoint responses archived by SportsDataverse, pinned to a commit.
# Both defense folders and combine filenames use season END years.
# Validate response parameters explicitly: combine year Y is asset Y+1.
archive_commit <- 'a9233ab1546e90714768644e694b2c891c1f2920'
archive_base <- paste0('https://raw.githubusercontent.com/sportsdataverse/hoopR-nba-stats-raw/',
                       archive_commit, '/nba_stats/json/')

validate_archive <- function(body, required, expected, relative_path) {
  payload <- jsonlite::fromJSON(body, simplifyVector = FALSE)
  for (key in names(expected)) {
    if (!identical(as.character(payload$parameters[[key]]), as.character(expected[[key]])))
      stop('Archive parameter mismatch: ', key, ' in ', relative_path)
  }
  parse_result(body, required)
}

fetch_archive <- function(relative_path, required, expected, refresh = FALSE) {
  path <- file.path('data/raw/archive', archive_commit, relative_path)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  url <- paste0(archive_base, relative_path)
  if (!file.exists(path) || refresh) {
    req <- httr2::request(url) |> httr2::req_timeout(30) |>
      httr2::req_retry(max_tries = 2, max_seconds = 65)
    response <- httr2::req_perform(req)
    body <- httr2::resp_body_string(response)
  } else body <- paste(readLines(path, warn = FALSE), collapse = '\n')
  result <- validate_archive(body, required, expected, relative_path)
  if (!file.exists(path) || refresh) {
    writeLines(body, path, useBytes = TRUE)
    jsonlite::write_json(list(source_url = url, archive_commit = archive_commit,
      retrieved_at_utc = format(Sys.time(), tz = 'UTC', usetz = TRUE),
      sha256 = digest::digest(file = path, algo = 'sha256'), rows = nrow(result)),
      paste0(path, '.metadata.json'), auto_unbox = TRUE, pretty = TRUE)
  }
  result
}

download_archive_inputs <- function(cfg, refresh = FALSE) {
  drills <- anthro <- defense <- list()
  for (year in cfg$combine_years) {
    message('Archived combine: ', year)
    expected <- list(SeasonYear = year, LeagueID = '00')
    drills[[as.character(year)]] <- fetch_archive(paste0('draftcombinedrillresults/', year + 1L, '.json'),
      c('PLAYER_ID', 'PLAYER_NAME', 'LANE_AGILITY_TIME'), expected, refresh) |>
      dplyr::mutate(combine_year = year)
    anthro[[as.character(year)]] <- fetch_archive(paste0('draftcombineplayeranthro/', year + 1L, '.json'),
      c('PLAYER_ID', 'HEIGHT_WO_SHOES', 'WINGSPAN', 'WEIGHT'), expected, refresh) |>
      dplyr::mutate(combine_year = year)
  }
  for (year in cfg$season_starts) {
    season <- sprintf('%d-%02d', year, (year + 1L) %% 100L)
    message('Archived defense: ', season)
    defense[[season]] <- fetch_archive(paste0('leaguedashptdefend/', year + 1L,
        '/regular-season_overall_totals.json'),
      c('CLOSE_DEF_PERSON_ID', 'D_FGM', 'D_FGA', 'NORMAL_FG_PCT'),
      list(Season = season, SeasonType = 'Regular Season', PerMode = 'Totals',
           DefenseCategory = 'Overall', LeagueID = '00'), refresh) |>
      dplyr::mutate(season_start = year)
  }
  inputs <- list(drills = dplyr::bind_rows(drills), anthro = dplyr::bind_rows(anthro),
                 defense = dplyr::bind_rows(defense))
  # Some original responses split a player-season across listed positions.
  # Exclude ALL ambiguous rows rather than guessing whether they overlap.
  keys <- inputs$defense[c('close_def_person_id', 'season_start')]
  ambiguous <- duplicated(keys) | duplicated(keys, fromLast = TRUE)
  inputs$excluded_defense <- inputs$defense[ambiguous, ]
  inputs$defense <- inputs$defense[!ambiguous, ]
  inputs
}
