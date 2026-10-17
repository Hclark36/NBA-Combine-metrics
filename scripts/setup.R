# Run from the repository root. Dependencies stay inside this project.
dir.create('.Rlib', showWarnings = FALSE)
.libPaths(c(normalizePath('.Rlib'), .libPaths()))
packages <- c('httr2', 'jsonlite', 'digest', 'dplyr', 'tidyr', 'ggplot2', 'glmnet',
              'plotly', 'crosstalk', 'htmltools', 'knitr', 'rmarkdown', 'testthat')
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
# Preserve repositories configured by RStudio or setup-r (including Linux
# binary repositories). Fall back to CRAN only when no usable mirror is set.
repos <- getOption('repos')
if (is.null(repos) || !length(repos)) repos <- c(CRAN = 'https://cloud.r-project.org')
repos[repos == '@CRAN@'] <- 'https://cloud.r-project.org'
if (length(missing)) install.packages(missing, repos = repos)
unavailable <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(unavailable)) stop('Dependencies still missing: ', paste(unavailable, collapse = ', '))
cat('Dependencies ready. Run Rscript scripts/run.R --demo for the preview.\n')
