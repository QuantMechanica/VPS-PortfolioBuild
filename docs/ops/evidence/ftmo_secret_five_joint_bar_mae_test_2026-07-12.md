# FTMO Secret Five Joint Bar-MAE Admission Test

Status: **NO DEVELOPMENT SURVIVOR; RESEARCH ONLY / NO GO**  
Date: 2026-07-12

## Scope

The five user-supplied Research Survivors were carried into the locked FTMO
book without assigning fictitious EA IDs or deployment permission. Native MT5
round trips were replayed on synchronized bar equity with the official FTMO
cost snapshot dated 2026-07-11. Secret trade paths use uncapped observed-bar
high/low for adverse fill; AUDJPY is explicitly coarser at H1, while the other
secret symbols use M15 or finer data resampled to M15.

The predeclared screen covered each strategy alone, the equal five-strategy
book, and the already frozen Segment-B allocation at candidate weights of
0.5%, 1%, 2%, 3%, 5%, 7.5%, and 10%. Candidate weight was carved
proportionally from every locked incumbent sleeve. The governor remained fixed
at risk 25, daily stop 4,500, full-risk room 4,000, and retention 0.2.

## Development Result

Development includes 2018, 2019, 2021, and 2022. The locked control scored:

| Fill | Pass rate |
|---|---:|
| Normal threshold | 59.0585% |
| Adverse bar | 51.3552% |

No representation and weight strictly improved both fills. The closest joint
results were:

| Representation | Weight | Normal | Delta | Adverse | Delta |
|---|---:|---:|---:|---:|---:|
| XAU SMA50 impulse hold | 3% | 59.4151% | +0.3566 pp | 50.2140% | -1.1412 pp |
| XAU M5 EMA20 impulse | 3% | 59.2725% | +0.2140 pp | 50.0713% | -1.2839 pp |
| Five equal | 3% | 59.4151% | +0.3566 pp | 49.7860% | -1.5692 pp |
| Pre-FOMC event-flat | 3% | 59.4151% | +0.3566 pp | 49.7860% | -1.5692 pp |
| Frozen Segment-B five | 3% | 59.3438% | +0.2853 pp | 49.7147% | -1.6405 pp |
| JPY SMA20 risk-on | 3% | 59.2725% | +0.2140 pp | 49.4294% | -1.9258 pp |

Breadth Turnaround Tuesday did not improve the normal control at any tested
weight, so its adverse evaluations were correctly short-circuited.

## Decision

The five strategies remain legitimate standalone Research Survivors, but they
do not improve the locked FTMO book under joint floating-risk reconstruction.
The predeclared 2023 validation remained closed. The 2024-2025 period was not
opened either and could not have served as a pristine holdout because the
source families had already been selected with global visibility.

## Evidence

- Predeclaration:
  `artifacts/ftmo_secret_five_joint_bar_mae_predeclaration_2026-07-12.json`
- Merged selection:
  `artifacts/ftmo_secret_five_joint_bar_mae_selection_2026-07-12.json`
- Seven development shards:
  `artifacts/ftmo_secret_joint_bar_mae_dev_*_2026-07-12.json`
- Replay tool:
  `tools/strategy_farm/portfolio/ftmo_secret_joint_bar_mae_screen.py`
- Merge tool:
  `tools/strategy_farm/portfolio/ftmo_merge_secret_joint_shards.py`
