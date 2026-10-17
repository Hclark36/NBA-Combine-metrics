# Quarto 1.6 can emit DataTables before htmlwidgets' jQuery. Move the existing
# embedded script rather than adding a second copy and resetting its plugins.
if (.Platform$OS.type == 'unix') invisible(Sys.setlocale('LC_CTYPE', 'en_US.UTF-8'))
fix_widget_order <- function(path) {
  html <- paste(readLines(path, warn = FALSE, encoding = 'UTF-8'), collapse = '\n')
  start <- regexpr('<script>/*! jQuery', html, fixed = TRUE)[1]
  first_script <- regexpr('<script', html, fixed = TRUE)[1]
  if (start < 1L || start == first_script) return(invisible(FALSE))
  relative_end <- regexpr('</script>', substring(html, start, nchar(html)), fixed = TRUE)[1]
  if (relative_end < 1L) stop('Could not locate embedded jQuery closing tag: ', path)
  end <- start + relative_end + nchar('</script>') - 2L
  jquery <- substr(html, start, end)
  html <- paste0(substr(html, 1, start - 1L), substring(html, end + 1L, nchar(html)))
  head <- regexpr('<head>', html, fixed = TRUE)[1]
  if (head < 1L) stop('Rendered HTML has no head element: ', path)
  head_end <- head + nchar('<head>') - 1L
  html <- paste0(substr(html, 1, head_end), '\n', jquery, '\n',
                 substring(html, head_end + 1L, nchar(html)))
  writeLines(enc2utf8(html), path, useBytes = TRUE)
  invisible(TRUE)
}
files <- strsplit(Sys.getenv('QUARTO_PROJECT_OUTPUT_FILES'), '\n', fixed = TRUE)[[1]]
for (path in files[grepl('\\.html$', files)]) {
  if (file.exists(path)) fix_widget_order(path)
}
