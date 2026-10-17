# Run from the repository root. Dependencies stay inside this project.
dir.create('.Rlib', showWarnings = FALSE)
.libPaths(c(normalizePath('.Rlib'), .libPaths()))
packages <- c('httr2', 'jsonlite', 'digest', 'dplyr', 'tidyr', 'ggplot2', 'glmnet',
              'plotly', 'crosstalk', 'htmltools', 'knitr', 'rmarkdown', 'testthat')
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing, repos = 'https://cloud.r-project.org')
unavailable <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(unavailable)) stop('Dependencies still missing: ', paste(unavailable, collapse = ', '))
cat('Dependencies ready. Run Rscript scripts/run.R --demo for the preview.\n')
