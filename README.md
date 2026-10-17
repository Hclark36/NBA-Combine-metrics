# Combine → Court

An R research project asking whether NBA combine agility adds predictive information about later defended-shot outcomes beyond size and position. Outputs include an interactive, self-contained HTML dashboard, linked player filters, a draft-class animation, coverage audits, and temporal model comparisons.

**Current status:** fitted on real NBA data through **2025–26**, using original NBA endpoint responses archived by SportsDataverse. There are 323 eligible combine participants and 90 held-out test players. The latest season contributes 11,522 defended shots from 28 eligible players. A separate simulated preview remains available for software testing.

**Recent classes:** the dashboard's **2024 & 2025** tab includes combine measurements
and available NBA results through 2025–26. After retaining each player's earliest combine,
there are 71 participants from 2024 and 72 from 2025; 61 and 48 respectively have matched
shot-defense observations. Their two- and one-season calendar windows remain incomplete,
so these descriptive results do not enter the three-season model scores. A validated
player-level snapshot is in `data/snapshots/recent_combine_2024-2025.csv`, with provenance
in its metadata sidecar. Rebuild the analysis and render after updating an older checkout.

**Robustness update:** 24 threshold/class-window scenarios and 2,000 paired bootstrap resamples per comparison are now included. Agility improves RMSE in 9 of 24 overlapping scenarios; its primary 95% conditional bootstrap interval includes zero. See [the robustness report](reports/robustness-results.md) and the dashboard's Robustness page.

## Quick start

Open `NBA-Combine-metrics.Rproj` in RStudio, or run these commands from this repository's root:

```sh
Rscript scripts/setup.R
Rscript tests/test-pipeline.R
Rscript scripts/run.R --demo
Rscript scripts/render.R --demo
```

Open `dist/demo.html`. The dashboard is a standalone HTML file with embedded widgets; it does not require an R server. Plotly hover, zoom, linked position/year/attempt filters, and class animation work in the browser.

**In the RStudio Console**, use R commands rather than shell commands:

```r
source('scripts/setup.R')
source('scripts/run.R')
source('scripts/render.R')
```

These default to real archived NBA data and produce `dist/archive.html`. After generating the analysis, you can also open `dashboard.qmd` and click **Render**. It loads the project-local R library and applies the same widget compatibility hook. Commands starting with `Rscript` belong in RStudio's **Terminal**, not its R Console.

Requirements: R >= 4.4 and Quarto >= 1.6. The render script discovers Quarto in PATH or the usual macOS RStudio bundle; otherwise set `QUARTO_BIN` to its executable path. Dependencies are installed into ignored project-local `.Rlib/`. A package version snapshot is written to `output/<mode>/session-info.txt` after every successful run. A fully pinned dependency lockfile is not included yet.

## Charts in RStudio and exported figures

After running the analysis, run this in the RStudio Console:

```r
source('scripts/visualize.R')
```

This displays four charts in the Plots pane: model accuracy, agility versus shot defense,
model improvement with uncertainty intervals, and a sensitivity heatmap, plus recent-class
drill distributions and partial NBA outcomes for 2024 and 2025. Use the Plots
pane arrows to browse them. PNG and PDF copies plus a combined `findings.png` chart sheet
are saved in `output/archive/figures/`. In the Terminal, use
`Rscript scripts/visualize.R --archive` (or `--demo` for clearly labeled simulated figures).

The HTML dashboard's Overview page also includes the player scatterplot and sensitivity
heatmap. Hover and zoom there; use Explore players for linked filters and In motion for
the animated combine-class scatterplot.

## Collect real data

Recommended: use the archived original NBA responses, pinned to a source commit:

```sh
Rscript scripts/run.R --archive
Rscript scripts/render.R --archive
```

Open `dist/archive.html`. Both the exact source season and `PerMode=Totals` are validated before import. Archive files use **season ending years**, so the 2025–26 defense file is under `2026`, and the 2023 combine is file `2024.json`; the loader verifies the NBA response parameters instead of trusting filenames.

The committed [2025–26 snapshot](data/snapshots/defense_2025-26.csv) contains **580 player records** with exact defended makes/attempts and normal opponent FG%. Its [metadata](data/snapshots/defense_2025-26.metadata.json) records the pinned URL, source commit, units, retrieval date, and CSV SHA-256. These are NBA tracking totals, not per-game estimates, and include no playoff rows.

For direct live requests instead:

```sh
Rscript scripts/run.R --live
Rscript scripts/render.R --live
```

The first command requests combine drills, anthropometrics, and overall defended-shot totals from NBA Stats. All requests must succeed before a new analysis is saved. Successful responses and fetch timestamps are retained in `data/raw/`; rerunning resumes from the cache. There is no automatic fallback to demo data.

NBA endpoints can time out or reject automated requests. A failure stops collection with an error, leaving successful cached responses intact. Retry later on a network with access to `stats.nba.com`. Use `--fetch-only` to collect without modeling; use `--refresh` only when deliberately replacing cached responses. The downloader pauses between uncached requests and uses bounded retries. Inspect the raw JSON and metadata before drawing conclusions; documented endpoint availability does not guarantee historical completeness.

Outputs:

| Path | Contents |
| --- | --- |
| `dist/demo.html` | Clearly labeled simulated preview |
| `dist/live.html` | Dashboard from successfully collected live NBA data |
| `dist/archive.html` | Real NBA analysis from the pinned archive through 2025–26 |
| `data/snapshots/defense_2025-26.csv` | Committed latest-season NBA totals and provenance sidecar |
| `output/<mode>/cohort.csv` | Participants, outcome totals, and inclusion status |
| `output/<mode>/recent.csv` | Recent combine classes, partial outcomes, and calendar-window coverage |
| `output/<mode>/coverage.csv` | Measurement availability by combine class |
| `output/<mode>/flow.csv` | Mutually exclusive inclusion/exclusion counts |
| `output/<mode>/repeated.csv` | Later repeat combine records removed |
| `output/<mode>/excluded_defense.csv` | Ambiguous player-season source rows excluded before matching |
| `output/<mode>/model_metrics.csv` | Untouched test-class RMSE and MAE |
| `output/<mode>/holdout_predictions.csv` | Per-player predictions for each model |
| `output/<mode>/primary_uncertainty.csv` | Paired RMSE/MAE improvements and conditional 95% intervals |
| `output/<mode>/robustness_comparisons.csv` | Alternative class windows and exposure cutoffs, with intervals |
| `output/<mode>/robustness_splits.csv` | Train, tuning, embargo, and test classes for every evaluated scenario |
| `output/<mode>/robustness_skipped.csv` | Unevaluable scenarios and explicit reasons, if any |
| `output/<mode>/robustness_predictions.csv` | Paired per-player predictions for every scenario |
| `output/<mode>/analysis.rds` | Full analysis, fitted models, tuning scores, provenance |

Raw download caches, generated dashboards, and dependencies are ignored by Git. The validated latest-season snapshot and a concise results report are tracked alongside the source. Nothing in a demo run should be described as an empirical basketball result.

## Research design

Default combine classes: **2013–2025**, with **2013–2023** eligible for the complete-window model. Requested NBA seasons: **2013–14 through 2025–26**. For combine year Y, the outcome window is seasons starting Y, Y+1, and Y+2. This is a calendar window after the combine, not a player's first three NBA appearances. All three seasons must be in the configured request range; a player may have observations in fewer seasons. Change `config.R` to adjust years and the minimum 100 defended-shot threshold.

Link only using NBA player IDs; never guess IDs from names or merge missing IDs. Retain unmatched participants in the audit, and use the earliest combine for repeat attendees. The archive adapter excludes all rows from ambiguous duplicate player-season keys rather than guessing how to pool position splits; eight rows from four player-seasons were excluded, and none match a combine participant in this dataset. The core pipeline still rejects any remaining duplicates. A successful but empty endpoint response is an explicit collection failure. Unknown numeric formats and invalid FG% units also stop the analysis.

**Outcome:** 100 × [sum of defended makes / sum of defended attempts − attempt-weighted normal opponent FG%]. Lower is better. This measures one aspect of shot defense; it is not a direct measure of defensive slides, isolation containment, or overall defense. Verify lane-agility and modified-lane-agility drill definitions before equating either with a specific slide test.

Four benchmarks use the same eligible players:

1. Training-set mean.
2. Ridge regression: height without shoes, wingspan, weight, primary listed position, combine year.
3. The same model plus lane agility.
4. The same model plus all available combine drills.

The latest three available combine classes are held out. Both final testing and rolling validation **purge overlapping outcome windows**: a training class's three-season window must finish before the prediction combine. By default, train on 2013–2018, omit 2019–2020, and test on 2021–2023. Ridge penalty strength is selected by rolling earlier-to-later validation inside those training classes; medians, missing indicators, and scaling are learned within each fold. No held-out outcomes enter tuning. Evaluation weights players equally, reports RMSE/MAE in percentage points, and requires at least 80 eligible players and sufficient draft classes. The response curve is a model diagnostic over training profiles, not a causal estimate or uncertainty interval.

Participation, nonrandom missingness, and NBA playing opportunity limit generalization. Missing tracking observations are not zero outcomes. Team schemes, assignments, opponent mix, injuries, and minutes are not fully controlled by this first model. The 95% bootstrap intervals pair the same test players across models and preserve the number of players in each class. They are conditional on fitted models and observed classes: they do not include refitting, future-class variability, or shot-level outcome uncertainty.

Sensitivity analyses use 50, 100, 250, and 500 defended attempts and all six contiguous test windows within 2021–2023. Each scenario retunes on earlier classes with the existing three-season gap; low cutoffs restore eligible players from the audited cohort rather than filtering the already-selected primary sample. The windows overlap and intervals are pointwise, without multiple-comparison adjustment. Treat them as exploratory diagnostics, not independent replications or a way to choose a winning model on the test set.

## Project structure

```text
config.R             Analysis window and thresholds
R/api.R              HTTP requests, raw cache, schema validation
R/archive.R          Pinned original NBA JSON archive and parameter checks
R/data.R             ID joins, outcome aggregation, coverage audit
R/model.R            Temporal validation, ridge models, predictions
R/robustness.R       Paired bootstrap and class/threshold sensitivity analysis
R/demo.R             Invented fixture for software verification
scripts/setup.R      Project-local dependency installation
scripts/run.R        Fetch → prepare → model → export
scripts/render.R     Standalone Quarto HTML rendering
dashboard.qmd        Report narrative, filters, plots, animation
tests/               Aggregation, schema, ID, and leakage checks
```

## Next research steps

- Verify the exact drill protocol and assess coverage selection effects.
- Examine shot categories separately and add exposure sensitivity analyses.
- Extend uncertainty beyond fixed fitted models with refitting and more draft classes as they become available.
- Compare ridge with a nonlinear model only after confirming adequate sample size.
- Add player archetypes, vertical-versus-rebounding, and draft-value studies.

## Sources

- [NBA combine drill schema](https://github.com/swar/nba_api/blob/master/docs/nba_api/stats/endpoints/draftcombinedrillresults.md)
- [NBA anthropometric schema](https://github.com/swar/nba_api/blob/master/docs/nba_api/stats/endpoints/draftcombineplayeranthro.md)
- [NBA defended-shot schema](https://github.com/swar/nba_api/blob/master/docs/nba_api/stats/endpoints/leaguedashptdefend.md)
- [SportsDataverse original NBA response archive](https://github.com/sportsdataverse/hoopR-nba-stats-raw)
- [Quarto dashboards](https://quarto.org/docs/dashboards/)

`nba_api` is an API client and documentation project, not the downloaded dataset. This project uses direct R HTTP requests so raw responses and collection failures remain inspectable. NBA data is subject to its provider's terms.
