# FX Cointegration Frontier Exhaustion / CPU-Ceiling Stop - 2026-07-20

**Branch:** `agents/board-advisor`

**Captured:** `2026-07-20T01:32:12Z`

**Scope:** select one non-duplicate market-neutral FX cointegration pair from
the OWNER-requested 66-pair scan, or advance an existing forex sleeve.

## Decision

No reputable-screen, non-duplicate pair remains unbuilt.

The controlling positive-hedge scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` admits only two of 66
pairs under its fixed rule (DEV Sharpe above zero, OOS net Sharpe above 0.8,
and at least four OOS state changes):

| Pair | DEV Sharpe | OOS net Sharpe | Existing EA |
|---|---:|---:|---|
| EURJPY/GBPJPY | 0.59 | 1.53 | `QM5_12533` |
| AUDUSD/NZDUSD | 0.13 | 1.29 | `QM5_12532` |

The approved sign-aware reproduction adds five strict rows. All seven strict
rows already have registered EA directories, compiled artifacts, fixed-risk
logical setfiles, and basket manifests:

| Pair | DEV Sharpe | OOS net Sharpe | Existing EA |
|---|---:|---:|---|
| GBPUSD/USDCAD | 0.26 | 1.55 | `QM5_12978` |
| EURJPY/GBPJPY | 0.59 | 1.53 | `QM5_12533` |
| AUDUSD/NZDUSD | 0.13 | 1.29 | `QM5_12532` |
| USDCAD/NZDUSD | 0.46 | 1.13 | `QM5_13003` |
| AUDUSD/EURGBP | 0.55 | 1.05 | `QM5_13106` |
| EURGBP/AUDJPY | 0.42 | 0.89 | `QM5_13117` |
| USDJPY/EURAUD | 0.51 | 0.88 | `QM5_13119` |

Creating another card would duplicate a built pair or weaken the preregistered
screen. The reputable structural-method lineage remains Ernest P. Chan,
*Quantitative Trading* (Wiley, 2009), Example 3.6 and Chapter 7, with the local
source extraction at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`.

## Anchor Status

Neither preferred anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker:

- `QM5_12532`: logical-basket Q02 PASS and Q04 PASS, followed by a Q05 FAIL.
- `QM5_12533`: logical-basket Q02 PASS, followed by a genuine Q04 FAIL.

The historical `QM5_12533` detached-terminal/history failures were recovered
and reclassified from infrastructure failure to Q02 PASS before Q04 was
created. Requeueing either anchor at Q02 would duplicate completed work and
bypass its later economic verdict.

## Strict-Frontier Closure

The last strict sleeve that had remained alive, `QM5_13117` EURGBP/AUDJPY,
completed Q08 with `FAIL_HARD` on 2026-07-18. The canonical aggregate contains
208 trades, baseline PF 1.44, cost-cushion PASS, and an `EDGE_HARD` runs test
(`p=0.04878`); its other weak sub-gates were calibrated soft. This is a current
downstream strategy verdict, not a Q02 setup failure.

The empirical rank-one existing strict row is `QM5_12978` GBPUSD/USDCAD, but it
already has a Q04 strategy failure. No downstream row was bypassed or replayed.

## CPU-Ceiling Stop

`tools/strategy_farm/farmctl.py` sets
`BUILD_BACKPRESSURE_ACTIVE_WORK_ITEM_LIMIT = 7`. The read-only live query

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm work-items --status active
```

returned eight active work items:

| Phase | Active |
|---|---:|
| Q02 | 4 |
| Q04 | 3 |
| Q08 | 1 |

Because the fleet was already one work item above the configured ceiling, the
mission stopped at the required boundary. No card, EA, registry row, work item,
priority mutation, dispatch tick, or MT5 tester run was created.

## Evidence And Safety

- Scan: `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`.
- Sign-aware method and threshold:
  `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py`.
- Seven-row de-dup reconciliation:
  `docs/research/MULTICURRENCY_STRATEGY_SURVEY_2026-07-15.md`.
- Anchor phase evidence:
  `docs/research/FX_COINTEGRATION_USDJPY_EURAUD_REVIEW_2026-07-10.md`.
- Current `QM5_13117` Q08 aggregate:
  `D:/QM/reports/work_items/d9f360d4-6fa3-47ab-bddb-6a33a616f540/QM5_13117/Q08/QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1/aggregate.json`.

No strategy logic, setfile, manifest, compiled artifact, live artifact,
AutoTrading state, deploy manifest, portfolio gate, `portfolio_admission`,
portfolio KPI, Q08 contribution path, or `T_Live` path was touched. Existing
unrelated worktree changes were left intact.
