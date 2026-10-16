# Combine → Court

An R research project asking whether NBA combine agility adds predictive information about later defended-shot outcomes beyond size and position. Outputs include an interactive, self-contained HTML dashboard, linked player filters, a draft-class animation, coverage audits, and temporal model comparisons.

**Current status:** working code and a simulated preview. The live NBA Stats smoke request timed out during development. No real NBA findings have been established. Demo players, IDs, and outcomes are invented and labeled throughout the dashboard.

## Quick start

Open `NBA-Combine-metrics.Rproj` in RStudio, or run these commands from this repository's root:

```sh
Rscript scripts/setup.R
Rscript tests/test-pipeline.R
Rscript scripts/run.R --demo
Rscript scripts/render.R --demo
```

Open `dist/demo.html`. The dashboard is a standalone HTML file with embedded widgets; it does not require an R server. Plotly hover, zoom, linked position/year/attempt filters, and class animation work in the browser.

Requirements: R >= 4.4 and Quarto >= 1.6. The render script discovers Quarto in PATH or the usual macOS RStudio bundle; otherwise set `QUARTO_BIN` to its executable path. Dependencies are installed into ignored project-local `.Rlib/`. A package version snapshot is written to `output/<mode>/session-info.txt` after every successful run. A fully pinned dependency lockfile is not included yet.

## Collect real data

```sh
Rscript scripts/run.R
Rscript scripts/render.R
```

The first command requests combine drills, anthropometrics, and overall defended-shot totals from NBA Stats. All requests must succeed before a new analysis is saved. Successful responses and fetch timestamps are retained in `data/raw/`; rerunning resumes from the cache. There is no automatic fallback to demo data.

NBA endpoints can time out or reject automated requests. A failure stops collection with an error, leaving successful cached responses intact. Retry later on a network with access to `stats.nba.com`. Use `--fetch-only` to collect without modeling; use `--refresh` only when deliberately replacing cached responses. The downloader pauses between uncached requests and uses bounded retries. Inspect the raw JSON and metadata before drawing conclusions; documented endpoint availability does not guarantee historical completeness.

Outputs:

| Path | Contents |
| --- | --- |
| `dist/demo.html` | Clearly labeled simulated preview |
| `dist/live.html` | Dashboard from successfully collected NBA data |
| `output/<mode>/cohort.csv` | Participants, outcome totals, and inclusion status |
| `output/<mode>/coverage.csv` | Measurement availability by combine class |
| `output/<mode>/flow.csv` | Mutually exclusive inclusion/exclusion counts |
| `output/<mode>/repeated.csv` | Later repeat combine records removed |
| `output/<mode>/model_metrics.csv` | Untouched test-class RMSE and MAE |
| `output/<mode>/holdout_predictions.csv` | Per-player predictions for each model |
| `output/<mode>/analysis.rds` | Full analysis, fitted models, tuning scores, provenance |

Raw data, generated results, and dependencies are ignored by Git. Only project source is published to GitHub; nothing in a demo run should be described as an empirical basketball result.

## Research design

Default combine classes: **2013–2023**. Requested NBA seasons: **2013–14 through 2025–26**. For combine year Y, the outcome window is seasons starting Y, Y+1, and Y+2. This is a calendar window after the combine, not a player's first three NBA appearances. All three seasons must be in the configured request range; a player may have observations in fewer seasons. Change `config.R` to adjust years and the minimum 100 defended-shot threshold.

Link only using NBA player IDs; never guess IDs from names or merge missing IDs. Retain unmatched participants in the audit, and use the earliest combine for repeat attendees. Defensive player-season duplicates raise an error rather than double-counting traded-player totals. A successful but empty endpoint response is an explicit collection failure. Unknown numeric formats and invalid FG% units also stop the analysis.

**Outcome:** 100 × [sum of defended makes / sum of defended attempts − attempt-weighted normal opponent FG%]. Lower is better. This measures one aspect of shot defense; it is not a direct measure of defensive slides, isolation containment, or overall defense. Verify lane-agility and modified-lane-agility drill definitions before equating either with a specific slide test.

Four benchmarks use the same eligible players:

1. Training-set mean.
2. Ridge regression: height without shoes, wingspan, weight, primary listed position, combine year.
3. The same model plus lane agility.
4. The same model plus all available combine drills.

The latest three available combine classes are held out. Both final testing and rolling validation **purge overlapping outcome windows**: a training class's three-season window must finish before the prediction combine. By default, train on 2013–2018, omit 2019–2020, and test on 2021–2023. Ridge penalty strength is selected by rolling earlier-to-later validation inside those training classes; medians, missing indicators, and scaling are learned within each fold. No held-out outcomes enter tuning. Evaluation weights players equally, reports RMSE/MAE in percentage points, and requires at least 80 eligible players and sufficient draft classes. The response curve is a model diagnostic over training profiles, not a causal estimate or uncertainty interval.

Participation, nonrandom missingness, and NBA playing opportunity limit generalization. Missing tracking observations are not zero outcomes. Team schemes, assignments, opponent mix, injuries, and minutes are not fully controlled by this first model. Held-out score differences have no uncertainty intervals yet and should not be used to claim a definitive effect.

## Project structure

```text
config.R             Analysis window and thresholds
R/api.R              HTTP requests, raw cache, schema validation
R/data.R             ID joins, outcome aggregation, coverage audit
R/model.R            Temporal validation, ridge models, predictions
R/demo.R             Invented fixture for software verification
scripts/setup.R      Project-local dependency installation
scripts/run.R        Fetch → prepare → model → export
scripts/render.R     Standalone Quarto HTML rendering
dashboard.qmd        Report narrative, filters, plots, animation
tests/               Aggregation, schema, ID, and leakage checks
```

## Next research steps

- Verify real endpoint coverage and the exact drill protocol.
- Examine shot categories separately and add exposure sensitivity analyses.
- Add uncertainty for held-out performance differences and class-window sensitivity.
- Compare ridge with a nonlinear model only after confirming adequate sample size.
- Add player archetypes, vertical-versus-rebounding, and draft-value studies.

## Sources

- [NBA combine drill schema](https://github.com/swar/nba_api/blob/master/docs/nba_api/stats/endpoints/draftcombinedrillresults.md)
- [NBA anthropometric schema](https://github.com/swar/nba_api/blob/master/docs/nba_api/stats/endpoints/draftcombineplayeranthro.md)
- [NBA defended-shot schema](https://github.com/swar/nba_api/blob/master/docs/nba_api/stats/endpoints/leaguedashptdefend.md)
- [Quarto dashboards](https://quarto.org/docs/dashboards/)

`nba_api` is an API client and documentation project, not the downloaded dataset. This project uses direct R HTTP requests so raw responses and collection failures remain inspectable. NBA data is subject to its provider's terms.
