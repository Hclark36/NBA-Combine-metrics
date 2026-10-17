# Shared plots for the interactive dashboard and exported research figures.
finding_plots <- function(result) {
  d <- result$prepared$analysis
  title <- function(x) paste0(if (identical(result$mode, 'demo')) 'SIMULATED | ' else '', x)
  style <- ggplot2::theme_minimal(base_size = 12) + ggplot2::theme(
    panel.grid.minor = ggplot2::element_blank(),
    plot.title = ggplot2::element_text(face = 'bold', color = '#142f34'),
    plot.title.position = 'plot', plot.background = ggplot2::element_rect(fill = 'white', color = NA),
    plot.caption = ggplot2::element_text(hjust = 0, color = '#536568'),
    legend.position = 'bottom')
  metrics <- result$models$metrics
  metrics$model <- factor(metrics$model, levels = c('Training mean', 'Size + position',
    '+ Lane agility', 'Full combine'))
  accuracy <- ggplot2::ggplot(metrics, ggplot2::aes(model, rmse, fill = model)) +
    ggplot2::geom_col(width = .6, show.legend = FALSE) +
    ggplot2::geom_text(ggplot2::aes(label = sprintf('%.3f', rmse)), hjust = -.15, size = 4) +
    ggplot2::coord_flip() +
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0, .16))) +
    ggplot2::scale_fill_manual(values = c('Training mean' = '#77918b',
      'Size + position' = '#0d776f', '+ Lane agility' = '#ce7231', 'Full combine' = '#5b66a5')) +
    ggplot2::labs(title = title('Does agility improve prediction?'),
      subtitle = sprintf('%d held-out players | shorter bars are better', result$models$test_n),
      x = NULL, y = 'Prediction error: RMSE (percentage points)',
      caption = 'All four models are evaluated on the same test players.') + style
  measured <- d[is.finite(d$lane_agility_time) & is.finite(d$defense_gap_pp), ]
  agility <- ggplot2::ggplot(measured, ggplot2::aes(lane_agility_time, defense_gap_pp,
    color = position_group)) +
    ggplot2::geom_hline(yintercept = 0, linetype = 'dashed', color = '#7c8987') +
    ggplot2::geom_point(alpha = .65, size = 2.3) +
    ggplot2::scale_color_manual(values = c(G = '#087f78', F = '#ce7231', C = '#5b66a5', Other = '#777777')) +
    ggplot2::labs(title = title('Faster drill, better shot defense?'),
      subtitle = sprintf('%d measured players | each dot is one player', nrow(measured)),
      x = 'Lane agility (seconds; faster to the left)',
      y = 'Defensive shooting gap (pp; better below zero)', color = 'Position',
      caption = 'Raw association across eligible players; not an adjusted or causal effect.') + style
  u <- result$uncertainty
  uncertainty <- ggplot2::ggplot(u, ggplot2::aes(delta_rmse, comparison)) +
    ggplot2::geom_vline(xintercept = 0, linetype = 'dashed', color = '#7c8987') +
    ggplot2::geom_segment(ggplot2::aes(x = rmse_lower, xend = rmse_upper, yend = comparison),
      linewidth = 1.2, color = '#0d776f') +
    ggplot2::geom_point(size = 3.5, color = '#ce7231') +
    ggplot2::labs(title = title('How certain is the improvement?'),
      subtitle = 'Dots: RMSE improvement | lines: 95% paired bootstrap intervals',
      x = 'RMSE improvement over size + position (pp; positive is better)', y = NULL,
      caption = 'Conditional on fitted models and observed classes; crossing zero is inconclusive.') + style
  s <- result$robustness$comparisons
  s <- s[s$comparison == '+ Lane agility', ]
  s$window <- ifelse(s$test_start == s$test_end, as.character(s$test_start),
    paste(s$test_start, s$test_end, sep = '-'))
  s$window <- factor(s$window, levels = unique(s$window))
  limit <- max(abs(s$delta_rmse), .001)
  sensitivity <- ggplot2::ggplot(s, ggplot2::aes(factor(threshold), window, fill = delta_rmse)) +
    ggplot2::geom_tile(color = 'white', linewidth = 1.5) +
    ggplot2::geom_text(ggplot2::aes(label = sprintf('%+.3f', delta_rmse)), size = 3.4) +
    ggplot2::scale_fill_gradient2(low = '#d88b5b', mid = '#f5f4ef', high = '#168579',
      midpoint = 0, limits = c(-limit, limit), breaks = c(-limit, 0, limit),
      labels = function(x) sprintf('%.2f', x)) +
    ggplot2::labs(title = title('Does the result hold across samples?'),
      subtitle = sprintf('Agility improves error in %d of %d overlapping scenarios',
        sum(s$delta_rmse > 0), nrow(s)), x = 'Minimum defended attempts', y = 'Held-out combine classes',
      fill = 'RMSE gain (pp)', caption = 'Green: lower error with agility. Orange: higher error. Exploratory comparisons.') + style
  list(accuracy = accuracy, agility = agility, uncertainty = uncertainty, sensitivity = sensitivity)
}
