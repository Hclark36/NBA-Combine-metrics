# Run from the repository root, not the scripts directory.
if (!file.exists('config.R')) stop('Run this script from the repository root.')
if (.Platform$OS.type == 'unix') invisible(Sys.setlocale('LC_CTYPE', 'en_US.UTF-8'))
if (dir.exists('.Rlib')) .libPaths(c(normalizePath('.Rlib'), .libPaths()))
source('config.R')
for (file in c('api', 'archive', 'data', 'model', 'robustness', 'demo')) source(paste0('R/', file, '.R'))
args <- commandArgs(trailingOnly = TRUE)
allowed <- c('--demo', '--archive', '--live', '--refresh', '--fetch-only')
if (any(!args %in% allowed)) stop('Unknown argument. Supported: ', paste(allowed, collapse = ', '))
modes <- intersect(args, c('--demo', '--archive', '--live'))
if (length(modes) > 1L) stop('Choose one data mode: --demo, --archive, or --live.')
mode <- if (length(modes)) sub('^--', '', modes) else 'archive'
inputs <- switch(mode, demo = demo_inputs(config),
  archive = download_archive_inputs(config, '--refresh' %in% args),
  live = download_inputs(config, '--refresh' %in% args))
if ('--fetch-only' %in% args) quit(status = 0)
prepared <- prepare_data(inputs, config)
models <- evaluate_models(prepared$analysis, config)
uncertainty <- paired_uncertainty(models$predictions, config$bootstrap_reps, config$seed)
robustness <- run_robustness(prepared, config)
dir.create(file.path('output', mode), recursive = TRUE, showWarnings = FALSE)
result <- list(mode = mode, generated_at = format(Sys.time(), tz = 'UTC', usetz = TRUE),
               config = config, prepared = prepared, models = models,
               uncertainty = uncertainty, robustness = robustness,
               source_commit = if (mode == 'archive') archive_commit else NULL,
               session = capture.output(sessionInfo()))
# Write only after the full pipeline succeeds. Demo and live outputs never overwrite each other.
saveRDS(result, file.path('output', mode, 'analysis.rds'))
for (name in c('cohort', 'coverage', 'flow', 'repeated', 'excluded_defense'))
  write.csv(prepared[[name]], file.path('output', mode, paste0(name, '.csv')), row.names = FALSE,
            fileEncoding = 'UTF-8')
write.csv(models$metrics, file.path('output', mode, 'model_metrics.csv'), row.names = FALSE)
write.csv(models$predictions, file.path('output', mode, 'holdout_predictions.csv'), row.names = FALSE)
write.csv(uncertainty, file.path('output', mode, 'primary_uncertainty.csv'), row.names = FALSE)
for (name in c('comparisons', 'splits', 'skipped', 'predictions'))
  write.csv(robustness[[name]], file.path('output', mode, paste0('robustness_', name, '.csv')),
            row.names = FALSE, fileEncoding = 'UTF-8')
writeLines(result$session, file.path('output', mode, 'session-info.txt'))
cat('Completed ', toupper(mode), ' analysis: ', nrow(prepared$analysis), ' eligible players.\n', sep = '')
cat('Render with: Rscript scripts/render.R --', mode, '\n', sep = '')
