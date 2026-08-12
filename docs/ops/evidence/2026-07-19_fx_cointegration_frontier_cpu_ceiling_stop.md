# FX Cointegration Frontier / CPU-Ceiling Stop - 2026-07-19

**Branch:** `agents/board-advisor`

**Captured:** `2026-07-19T19:08:15Z`

**Scope:** select one non-duplicate FX cointegration pair from the OWNER-requested
66-pair scan, or advance an existing forex sleeve.

## Research Decision

No approved, non-duplicate pair remains unbuilt.

- The controlling scan in
  `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` certifies only two
  positive-hedge rows under its fixed rule (DEV net Sharpe above zero, OOS net
  Sharpe above 0.8, and at least four OOS state changes):
  `EURJPY~GBPJPY` (`QM5_12533`) and `AUDUSD~NZDUSD` (`QM5_12532`). Both are
  already approved, built, manifested, compiled, and tested.
- The approved sign-aware continuation is exhausted too. Its final strict row,
  `USDJPY~EURAUD`, is already built as `QM5_13119`; the preceding strict rows
  likewise have approved cards and EA directories.
- The best nominal dedicated tail row without its own EA is
  `GBPUSD~USDCHF`, but it is ineligible: DEV net Sharpe is `-0.37` despite OOS
  net Sharpe `0.94`, its half-life is about 117 D1 bars, and the pair is already
  represented in `QM5_1156` and `QM5_1257`. Carding it would violate the
  reputable-source screen and duplicate existing pair coverage.

The method lineage remains Ernest Chan, *Quantitative Trading* (Wiley, 2009),
locally extracted at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. No below-screen
card was created and no EA ID was allocated.

## Anchor Status

The preferred anchors have resolved Q02 infrastructure and terminal downstream
strategy verdicts:

| EA | Pair | Current chain | Open Q02 rows |
|---|---|---|---:|
| `QM5_12532` | `AUDUSD~NZDUSD` | Q02 PASS, Q04 PASS, Q05 FAIL (PF 0.95, 204 trades) | 0 |
| `QM5_12533` | `EURJPY~GBPJPY` | Q02 PASS, Q04 FAIL (pooled PF 0.432, 43 trades) | 0 |

Requeueing either anchor at Q02 would duplicate completed logical-basket work
and bypass the real economic verdict. Historical `NO_HISTORY` / account-currency
failures on `QM5_12533` are already repaired; neither anchor has a current
`ONINIT` or `NO_HISTORY` blocker.

## CPU-Ceiling Stop

`tools/strategy_farm/farmctl.py` defines the active-work-item pause threshold as
7. The read-only farm snapshot at the capture time was:

| Status | Count |
|---|---:|
| active | 9 |
| pending | 3,921 |
| done | 48,433 |
| failed | 47,131 |

The active rows occupied `T1`, `T2`, `T3`, `T4`, `T6`, `T7`, `T8`, `T9`, and
`T10`. Because the farm was already two jobs above the configured ceiling, this
mission stopped without selecting a fallback queue mutation. No duplicate Q02
or downstream work item was inserted, no priority was changed, and no MT5
tester or dispatch tick was launched.

## Safety Boundary

No strategy logic, setfile, registry, compiled artifact, `T_Live` file,
AutoTrading state, deploy manifest, portfolio gate, `portfolio_admission`,
portfolio KPI, or Q08 contribution path was touched.
