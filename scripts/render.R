if (!file.exists('config.R')) stop('Run from the repository root.')
if (dir.exists('.Rlib')) .libPaths(c(normalizePath('.Rlib'), .libPaths()))
args <- commandArgs(trailingOnly = TRUE)
if (any(!args %in% c('--demo', '--archive', '--live'))) stop('Supported modes: --demo, --archive, or --live.')
modes <- intersect(args, c('--demo', '--archive', '--live'))
if (length(modes) > 1L) stop('Choose one data mode.')
mode <- if (length(modes)) sub('^--', '', modes) else 'archive'
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
# Widget script ordering is handled by the shared Quarto post-render hook,
# so RStudio's Render button receives the same correction as this helper.
cat('Dashboard: ', normalizePath(file.path('dist', paste0(mode, '.html'))), '\n', sep = '')
