# In RStudio: source('scripts/visualize.R'). In Terminal: Rscript scripts/visualize.R --archive
if (!file.exists('config.R')) stop('Open NBA-Combine-metrics.Rproj before running this script.')
if (dir.exists('.Rlib')) .libPaths(c(normalizePath('.Rlib'), .libPaths()))
args <- commandArgs(trailingOnly = TRUE)
if (any(!args %in% c('--archive', '--demo', '--live')) || length(args) > 1L)
  stop('Choose one mode: --archive, --demo, or --live.')
mode <- if (length(args)) sub('^--', '', args) else 'archive'
path <- file.path('output', mode, 'analysis.rds')
if (!file.exists(path)) stop('Run scripts/run.R for mode ', mode, ' first.')
source('R/visuals.R')
result <- readRDS(path)
plots <- finding_plots(result)
summary_plots <- plots
plots <- c(plots, recent_class_plots(result))
folder <- file.path('output', mode, 'figures')
dir.create(folder, recursive = TRUE, showWarnings = FALSE)
for (name in names(plots)) {
  ggplot2::ggsave(file.path(folder, paste0(name, '.png')), plots[[name]],
    width = 10, height = 6, dpi = 180, bg = 'white')
  ggplot2::ggsave(file.path(folder, paste0(name, '.pdf')), plots[[name]],
    width = 10, height = 6, bg = 'white')
}
grDevices::png(file.path(folder, 'findings.png'), width = 2400, height = 1800, res = 150)
tryCatch({
  grid::grid.newpage()
  grid::pushViewport(grid::viewport(layout = grid::grid.layout(2, 2)))
  for (i in seq_along(summary_plots)) print(summary_plots[[i]], vp = grid::viewport(
    layout.pos.row = (i - 1L) %/% 2L + 1L, layout.pos.col = (i - 1L) %% 2L + 1L))
}, finally = grDevices::dev.off())
if (interactive()) for (p in plots) print(p)
cat('Charts saved to ', normalizePath(folder), '\n', sep = '')
