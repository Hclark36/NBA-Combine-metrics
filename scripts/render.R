if (!file.exists('config.R')) stop('Run from the repository root.')
if (dir.exists('.Rlib')) .libPaths(c(normalizePath('.Rlib'), .libPaths()))
args <- commandArgs(trailingOnly = TRUE)
if (any(!args %in% '--demo')) stop('Only --demo is supported.')
mode <- if ('--demo' %in% args) 'demo' else 'live'
if (!file.exists(file.path('output', mode, 'analysis.rds'))) stop('Run scripts/run.R first for mode: ', mode)
quarto <- Sys.getenv('QUARTO_BIN', unset = Sys.which('quarto'))
if (!nzchar(quarto)) {
  candidate <- '/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto'
  if (file.exists(candidate)) quarto <- candidate
}
if (!nzchar(quarto)) stop('Install Quarto from https://quarto.org or set QUARTO_BIN.')
Sys.setenv(NBA_ANALYSIS_MODE = mode)
# Quarto launches a new R process; set its UTF-8 locale before it parses chunks.
Sys.setenv(LANG = 'en_US.UTF-8', LC_ALL = 'en_US.UTF-8')
invisible(Sys.setlocale('LC_CTYPE', 'en_US.UTF-8'))
if (dir.exists('.Rlib')) Sys.setenv(R_LIBS_USER = normalizePath('.Rlib'))
status <- system2(quarto, c('render', 'dashboard.qmd', '--output', paste0(mode, '.html')))
if (status != 0L) stop('Quarto render failed with status ', status)
html_path <- file.path('dist', paste0(mode, '.html'))
# Quarto 1.6 can place its bundled DataTables before htmlwidgets' jQuery.
# Move the existing embedded jQuery to the front of <head>; never add a second
# copy (which would reset already-registered plugins). No network dependency.
html <- paste(readLines(html_path, warn = FALSE, encoding = 'UTF-8'), collapse = '\n')
start <- regexpr('<script>/*! jQuery', html, fixed = TRUE)[1]
if (start > 0L) {
  relative_end <- regexpr('</script>', substring(html, start, nchar(html)), fixed = TRUE)[1]
  if (relative_end < 1L) stop('Could not locate embedded jQuery closing tag.')
  end <- start + relative_end + nchar('</script>') - 2L
  jquery <- substr(html, start, end)
  html <- paste0(substr(html, 1, start - 1L), substring(html, end + 1L, nchar(html)))
  head_end <- regexpr('<head>', html, fixed = TRUE)[1] + nchar('<head>') - 1L
  if (head_end < nchar('<head>')) stop('Rendered HTML has no head element.')
  html <- paste0(substr(html, 1, head_end), '\n', jquery, '\n', substring(html, head_end + 1L, nchar(html)))
  writeLines(enc2utf8(html), html_path, useBytes = TRUE)
}
cat('Dashboard: ', normalizePath(file.path('dist', paste0(mode, '.html'))), '\n', sep = '')
