# Agility and defense: real data through 2025–26

Source: original NBA Stats JSON archived by [SportsDataverse](https://github.com/sportsdataverse/hoopR-nba-stats-raw), pinned to commit `a9233ab1546e90714768644e694b2c891c1f2920`. The source response explicitly specifies `Season=2025-26`, `SeasonType=Regular Season`, `DefenseCategory=Overall`, and `PerMode=Totals`.

The latest completed season is 2025–26 as of October 16, 2026; [the NBA's next regular season begins October 20](https://www.nba.com/news/2026-27-nba-regular-season-schedule). The existing configuration already targeted seasons through 2025–26, but previously no live NBA data had been obtained. This update supplies real observations and fits the model.

## Data and matching

- Latest-season snapshot: **580 NBA player records**.
- Combine participants after earliest-attendance deduplication: **688**; 38 later repeat records removed.
- Eligible for matched three-season analysis: **323**.
- 177 training players (2013–2018 combine classes); 90 test players (2021–2023).
- 2019–2020 classes are omitted from training and test to keep future outcome windows out of the training labels.
- **28 players** from the 2023 combine contribute **11,522 defended attempts** from 2025–26 to their outcomes.
- Eight ambiguous rows representing four player-seasons were excluded before matching. None match combine participants in the imported drill table. No totals were reconstructed from per-game rates.

The 2024–2026 combine classes do not yet have complete three-season calendar windows and are not added to the training labels. This preserves the same research question and target horizon.

## Held-out results

Outcome: defended FG% minus attempt-weighted normal opponent FG%, measured in percentage points. Lower is better. Errors below are measured on the same 90 test players, with equal player weights.

| Model | RMSE (pp) | MAE (pp) |
| --- | ---: | ---: |
| Training mean | 2.513 | 1.932 |
| Size + position | 2.543 | 1.986 |
| Size + position + lane agility | 2.540 | 1.981 |
| Full combine | 2.465 | 1.902 |

Adding lane agility reduces RMSE by approximately **0.0024 pp** relative to size and position. Both models perform slightly worse than simply predicting the training mean. This run provides little evidence of useful additional predictive value from lane agility alone. The full combine model has lower point-estimate error, but the comparison has no uncertainty interval and should be replicated across more temporal splits before making a scouting claim.

This is an observational shot-defense analysis, not an estimate of the causal effect of defensive-slide training or a measure of overall defensive ability. Missing drill participation and tracking observations limit generalization.

## Reproduce

```sh
Rscript scripts/setup.R
Rscript tests/test-pipeline.R
Rscript scripts/run.R --archive
Rscript scripts/render.R --archive
```

Generated report: `dist/archive.html`. Exact CSVs, fitted models, tuning results, source exclusions, and session versions are in `output/archive/`. Raw archived responses and per-file SHA-256 metadata are cached under `data/raw/archive/`.
