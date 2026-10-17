# Run from the repository root, not the scripts directory.
if (!file.exists('config.R')) stop('Run this script from the repository root.')
if (.Platform$OS.type == 'unix') invisible(Sys.setlocale('LC_CTYPE', 'en_US.UTF-8'))
if (dir.exists('.Rlib')) .libPaths(c(normalizePath('.Rlib'), .libPaths()))
source('config.R')
for (file in c('api', 'archive', 'data', 'model', 'demo')) source(paste0('R/', file, '.R'))
args <- commandArgs(trailingOnly = TRUE)
allowed <- c('--demo', '--archive', '--refresh', '--fetch-only')
if (any(!args %in% allowed)) stop('Unknown argument. Supported: ', paste(allowed, collapse = ', '))
demo <- '--demo' %in% args
if (demo && '--archive' %in% args) stop('Choose either --demo or --archive.')
mode <- if (demo) 'demo' else if ('--archive' %in% args) 'archive' else 'live'
inputs <- switch(mode, demo = demo_inputs(config),
  archive = download_archive_inputs(config, '--refresh' %in% args),
  live = download_inputs(config, '--refresh' %in% args))
if ('--fetch-only' %in% args) quit(status = 0)
prepared <- prepare_data(inputs, config)
models <- evaluate_models(prepared$analysis, config)
dir.create(file.path('output', mode), recursive = TRUE, showWarnings = FALSE)
result <- list(mode = mode, generated_at = format(Sys.time(), tz = 'UTC', usetz = TRUE),
               config = config, prepared = prepared, models = models,
               source_commit = if (mode == 'archive') archive_commit else NULL,
               session = capture.output(sessionInfo()))
# Write only after the full pipeline succeeds. Demo and live outputs never overwrite each other.
saveRDS(result, file.path('output', mode, 'analysis.rds'))
for (name in c('cohort', 'coverage', 'flow', 'repeated', 'excluded_defense'))
  write.csv(prepared[[name]], file.path('output', mode, paste0(name, '.csv')), row.names = FALSE,
            fileEncoding = 'UTF-8')
write.csv(models$metrics, file.path('output', mode, 'model_metrics.csv'), row.names = FALSE)
write.csv(models$predictions, file.path('output', mode, 'holdout_predictions.csv'), row.names = FALSE)
writeLines(result$session, file.path('output', mode, 'session-info.txt'))
cat('Completed ', toupper(mode), ' analysis: ', nrow(prepared$analysis), ' eligible players.\n', sep = '')
cat('Render with: Rscript scripts/render.R ', if (mode != 'live') paste0('--', mode) else '', '\n', sep = '')
