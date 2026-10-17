# 2024 and 2025 combine classes

The pinned SportsDataverse archive includes original NBA drill and anthropometric
responses for both classes, plus regular-season defended-shot totals through 2025–26.
The importer validates the response's SeasonYear, season, and Totals parameters.

| Combine class | Raw participants | Earliest-combine participants | Recorded agility | Matched NBA outcomes | 100+ defended attempts | Defended attempts so far |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 2024 | 83 | 71 | 67 | 61 | 46 | 42,083 |
| 2025 | 79 | 72 | 69 | 48 | 38 | 17,217 |

Repeat attendees retain their earliest combine across all imported classes. This
removes 12 later appearances from the 2024 class and 7 from 2025. Counts above
include players without recorded lane agility; the early-outcome scatterplot has
58 players from 2024 and 47 from 2025 with both agility and matched NBA outcomes.

The 2024 class can have two calendar seasons of follow-up (2024–25, 2025–26), and
the 2025 class can have one (2025–26). A player's recorded tracking observations may
cover fewer seasons. Missing rows are not assigned zero attempts or a zero outcome.
All matched positive shot volumes appear in the descriptive chart, including small
samples; the 100-shot counts are provided for context, not as its inclusion rule.

The weighted shooting-gap calculation is the same as in the primary analysis, but
these unequal partial windows are not three-season labels. Neither recent class
enters model fitting, tuning, evaluation, or sensitivity scenarios. The original
323 eligible players, 90 held-out players, four model scores, and 24 sensitivity
scenarios are unchanged. The full windows end in 2026–27 and 2027–28 respectively.

## Outputs

- `data/snapshots/recent_combine_2024-2025.csv`: validated, deduplicated player measurements and partial outcomes.
- `data/snapshots/recent_combine_2024-2025.metadata.json`: source URLs, source checksums, pinned commit, and snapshot checksum.
- `output/archive/recent.csv`: regenerated player-level export.
- `output/archive/figures/recent_drills.png` and `recent_outcomes.png`: figures, also exported as PDF.
- Dashboard **2024 & 2025** tab: linked class, position, and player filters with interactive charts.

Rebuild locally in the RStudio Console after opening the project:

```r
source('scripts/run.R')
source('scripts/visualize.R')
source('scripts/render.R')
```
