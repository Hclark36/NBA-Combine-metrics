# Direct NBA Stats requests preserve raw JSON and fail explicitly on bad data.
parse_result <- function(body, required) {
  payload <- jsonlite::fromJSON(body, simplifyVector = FALSE)
  sets <- payload$resultSets
  if (is.null(sets) && !is.null(payload$resultSet)) sets <- list(payload$resultSet)
  if (is.null(sets)) stop('NBA response has no resultSets.')
  matches <- Filter(function(x) all(required %in% unlist(x$headers)), sets)
  if (length(matches) != 1L) stop('Expected exactly one result set with required fields.')
  x <- matches[[1]]
  headers <- unlist(x$headers)
  if (!length(x$rowSet)) stop('NBA returned an empty result set; inspect coverage before proceeding.')
  rows <- lapply(x$rowSet, function(row) {
    if (length(row) != length(headers)) stop('NBA row/header length mismatch.')
    values <- lapply(row, function(value) if (is.null(value)) NA else value)
    names(values) <- tolower(headers)
    as.data.frame(values, stringsAsFactors = FALSE)
  })
  dplyr::bind_rows(rows)
}

fetch_nba <- function(endpoint, parameters, required, timeout = 20, refresh = FALSE) {
  dir.create('data/raw', recursive = TRUE, showWarnings = FALSE)
  # Sort parameter names to create a stable, readable cache key.
  parameters <- parameters[order(names(parameters))]
  key <- gsub('[^[:alnum:]_-]', '_', paste(names(parameters), parameters, collapse = '_'))
  path <- file.path('data/raw', paste0(endpoint, '_', key, '.json'))
  if (file.exists(path) && !refresh) {
    return(parse_result(paste(readLines(path, warn = FALSE), collapse = '\n'), required))
  }
  req <- httr2::request(paste0('https://stats.nba.com/stats/', endpoint))
  req <- do.call(httr2::req_url_query, c(list(req), parameters))
  req <- httr2::req_headers(req, Referer = 'https://www.nba.com/',
                           `User-Agent` = 'Mozilla/5.0', Accept = 'application/json')
  req <- httr2::req_timeout(req, timeout)
  # Bounded retries; successful previous responses remain cached after failures.
  req <- httr2::req_retry(req, max_tries = 2, max_seconds = timeout * 2 + 5)
  response <- httr2::req_perform(req)
  body <- httr2::resp_body_string(response)
  result <- parse_result(body, required) # Never cache HTML, errors, or empty data.
  writeLines(body, path)
  jsonlite::write_json(list(endpoint = endpoint, parameters = parameters,
    fetched_at_utc = format(Sys.time(), tz = 'UTC', usetz = TRUE), rows = nrow(result)),
    paste0(path, '.metadata.json'), auto_unbox = TRUE, pretty = TRUE)
  result
}

download_inputs <- function(cfg, refresh = FALSE) {
  get <- function(endpoint, parameters, required) {
    message('Fetching ', endpoint, ': ', paste(parameters, collapse = ' / '))
    result <- fetch_nba(endpoint, parameters, required, cfg$timeout_seconds, refresh)
    Sys.sleep(cfg$request_pause_seconds)
    result
  }
  drills <- anthro <- list()
  for (year in cfg$combine_years) {
    args <- list(LeagueID = '00', SeasonYear = year)
    drills[[as.character(year)]] <- get('draftcombinedrillresults', args,
      c('PLAYER_ID', 'PLAYER_NAME', 'LANE_AGILITY_TIME')) |>
      dplyr::mutate(combine_year = year)
    anthro[[as.character(year)]] <- get('draftcombineplayeranthro', args,
      c('PLAYER_ID', 'HEIGHT_WO_SHOES', 'WINGSPAN', 'WEIGHT')) |>
      dplyr::mutate(combine_year = year)
  }
  defense <- list()
  for (year in cfg$season_starts) {
    season <- sprintf('%d-%02d', year, (year + 1) %% 100)
    args <- list(LeagueID = '00', Season = season, SeasonType = 'Regular Season',
      DefenseCategory = 'Overall', PerMode = 'Totals', College = '', Conference = '',
      Country = '', DateFrom = '', DateTo = '', Division = '', DraftPick = '',
      DraftYear = '', GameSegment = '', Height = '', LastNGames = 0, Location = '',
      Month = 0, OpponentTeamID = 0, Outcome = '', PORound = '', Period = 0,
      PlayerExperience = '', PlayerID = '', PlayerPosition = '', SeasonSegment = '',
      StarterBench = '', TeamID = '', VsConference = '', VsDivision = '', Weight = '')
    defense[[season]] <- get('leaguedashptdefend', args,
      c('CLOSE_DEF_PERSON_ID', 'D_FGM', 'D_FGA', 'NORMAL_FG_PCT')) |>
      dplyr::mutate(season_start = year)
  }
  list(drills = dplyr::bind_rows(drills), anthro = dplyr::bind_rows(anthro),
       defense = dplyr::bind_rows(defense))
}
