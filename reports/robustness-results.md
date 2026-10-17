# Does the agility result survive sensitivity checks?

Analysis updated October 17, 2026. Original NBA data through 2025–26, archived by SportsDataverse and pinned to commit `a9233ab1546e90714768644e694b2c891c1f2920`. This extends the existing ridge models without changing the three-season outcome definition or using test outcomes for penalty tuning.

## Finding

There is **no consistent added predictive advantage from lane agility** in these checks. Agility reduces held-out RMSE in **9 of 24 scenarios** and increases it in 15. The scenarios overlap and are not independent replications, so this count is descriptive rather than a statistical win rate.

In the primary 100-shot, 2021–2023 comparison, the estimated RMSE improvement from agility is **0.0024 percentage points**, with a **95% paired bootstrap interval from −0.0067 to +0.0109 pp**. Zero means no difference; negative values mean adding agility increases error. This interval includes both small benefits and small worsening.

## Primary uncertainty

Comparison: size + position model minus the named model's error. Positive differences favor the named model. All models use the same 90 test players across three combine classes.

| Added model / comparator | RMSE improvement (pp) | 95% interval | MAE improvement (pp) | 95% interval |
| --- | ---: | --- | ---: | --- |
| + Lane agility | 0.0024 | −0.0067 to 0.0109 | 0.0056 | −0.0037 to 0.0147 |
| Full combine | 0.0772 | −0.0250 to 0.1803 | 0.0847 | −0.0002 to 0.1720 |
| Training mean | 0.0295 | −0.1789 to 0.2507 | 0.0539 | −0.1047 to 0.2225 |

The full combine model's lower point-estimate error also has an interval that includes zero. These results do not establish that the full combine model reliably outperforms size and position.

## Sensitivity design

- Defended-shot cutoffs: **50, 100, 250, 500**, applied over the same three-season outcome window.
- Held-out windows: **2021**, **2022**, **2023**, **2021–2022**, **2022–2023**, **2021–2023**.
- All **24 planned scenarios** were evaluable. Test samples range from **20 to 101 players**.
- Each scenario independently selects its ridge penalty using earlier, fully observed training classes. The three-season gap is enforced in tuning and final evaluation.
- Eligibility is rebuilt from the full audited cohort. A lower shot cutoff can therefore restore players who failed the primary 100-shot cutoff.

One of the 24 agility RMSE intervals lies entirely above zero and three lie entirely below zero. These are exploratory, pointwise intervals with no adjustment for multiple comparisons. The isolated favorable interval at 500 shots in the 2022 class does not establish a repeatable advantage.

The complete numeric results, split definitions, and primary intervals are committed beside this report as CSVs. The dashboard provides interactive interval charts and a table of every agility scenario.

## What the intervals mean

For each comparison, resample held-out players **2,000 times within draft class**, retaining each class's sample size. The same selected player indices are used for all models in a replicate, preserving pairing. Recalculate each model's RMSE and MAE, then take the 2.5th and 97.5th percentiles of their paired differences. Seeds are recorded in the exported tables; the primary scenario uses seed 36.

These intervals measure test-player sampling uncertainty **conditional on the fitted models and the observed draft classes**. Models are not refitted inside bootstrap resamples. The intervals do not include training-set variability, generalization to future draft classes, shot-level measurement uncertainty, or dependence arising from shared teams and opponents. Class sensitivity is examined through the temporal scenarios, not estimated by these intervals.

All tested class windows have already been inspected as part of this exploratory study. These checks should not be described as new, independent confirmatory validation, and the best threshold/window should not be selected as the final claim.

## Reproduce

```sh
Rscript tests/test-pipeline.R
Rscript scripts/run.R --archive
Rscript scripts/render.R --archive
```

The pipeline writes `primary_uncertainty.csv`, `robustness_comparisons.csv`, `robustness_splits.csv`, `robustness_skipped.csv`, and `robustness_predictions.csv` in `output/archive/`. The HTML report is `dist/archive.html`. Thresholds, class starts, and bootstrap replicates are configured in `config.R`.

Next research priorities are position/shot-category outcomes, selection-bias audits, and nonlinear benchmarks. The present results do not show that defensive-slide training causes better NBA defense.
