# Portfolio Next Rescue Plan - 2026-06-28

Scope: expand the live-test candidate pool without touching `T_Live`. Priority
is true diversification, then infrastructure false negatives, then narrow
strategy refinements.

## Active Actions

- `QM5_10558 EURUSD`:
  - Q04 `PASS_LOWFREQ`, Q05 `PASS`, Q06 `PASS`, Q07 `PASS`.
  - Q08 failed by `ACTIVE_TIMEOUT`, not by a written Q08 aggregate.
  - Evidence showed Q08 generated a fresh baseline (`394` trades, PF `1.21`)
    and then spent the default 30-minute Q08 budget in neighborhood/PBO support
    work.
  - Action taken: requeued Q08 with `timeout_min=120`.
  - Infra fix: farm active-timeout logic now honors per-work-item
    `payload.timeout_min`, matching the terminal worker monitor.

- `QM5_12712 EURGBP/EURAUD cointegration`:
  - Q05 active.
  - Current `tester.ini` is correctly capped at `ToDate=2024.12.31`.

- `QM5_12532 AUDNZD cointegration`:
  - Q04 `PASS`, Q05 active.
  - Current rerun is correctly capped at `ToDate=2024.12.31`; the earlier
    uncapped 2025 start remains only as audit evidence.

## Near-Miss Q05 Rescue Queue

These failed Q05 by a small PF or drawdown margin after useful Q04 evidence.
The first group is more portfolio-useful because it avoids adding more XAU/US
index exposure.

| rank | EA | symbol | prior gate | Q05 issue | read |
|---:|---|---|---|---|---|
| 1 | `QM5_11476` | `USDJPY.DWX` | Q04 `PASS_SOFT` | PF `0.980` | Best quick FX rescue candidate. |
| 2 | `QM5_9636` | `GBPUSD.DWX` | Q04 `PASS_SOFT` | PF `0.980` | GBP diversifier; inspect setfile/filter. |
| 3 | `QM5_10198` | `GBPUSD.DWX` | Q04 `PASS` | PF `0.970` | Strong candidate; Q04 all folds > 1. |
| 4 | `QM5_10041` | `GBPUSD.DWX` | Q04 `PASS` | PF `0.950` | Already on shortlist; small filter likely. |
| 5 | `QM5_11708` | `AUDUSD.DWX` | Q04 `PASS_LOWFREQ` | PF `0.920` | Useful AUD exposure if stable. |
| 6 | `QM5_11340` | `EURUSD.DWX` | Q04 `PASS` | PF `0.910` | Lower priority while `10558` Q08 is pending. |
| 7 | `QM5_10300` | `XTIUSD.DWX` | Q04 `PASS_SOFT` | PF `0.900` | Commodity diversifier; worth a separate filter pass. |

Index/XAU near-misses exist, but they are lower portfolio priority unless the
farm produces an unusually clean Q08/Q09 path.

## Q04 Near-Miss Research Queue

These are not pipeline-ready, but they are good strategy-repair targets because
two folds are positive or the failed fold is close to the floor:

- `QM5_9300 EURUSD`: Q04 PFs `0.909 / 1.143 / 1.175`.
- `QM5_10542 EURUSD`: Q04 PFs `0.938 / 1.017 / 1.086`.
- `QM5_11337 USDJPY`: Q04 PFs `0.906 / 1.051 / 1.035`.
- `QM5_10110 GBPUSD`: Q04 PFs `0.850 / 1.087 / 1.021`.
- `QM5_10300 GBPUSD`: Q04 PFs `1.035 / 1.210 / 0.959`.
- `QM5_12732 EURUSD/GBPUSD cointegration`: Q04 PFs `0.974 / 1.327 / 0.896`.

Action pattern: inspect card/spec + setfile drift first; only then decide on a
small filter or session/risk refinement. Do not simply rerun unchanged.

## Q04 Infra-Fail Cluster

Latest DB scan shows many old and recent Q04 `INFRA_FAIL` rows. The dominant
patterns are:

- `incomplete_fold`: large historical backlog, likely mixed old runner behavior.
- `BARS_ZERO`, `HISTORY_CONTEXT_INVALID`, `RUN_STATUS_INVALID`, `M0_1970_PERIOD`.
- Current failures often hit a subset of folds rather than all folds.

Next engineering step:

1. Split Q04 infra rows into old-runner backlog versus fresh post-patch rows.
2. For fresh rows, group by terminal/symbol/fold and inspect raw `tester.ini` +
   `summary.json`.
3. Only then decide whether Q04 needs a harness patch or whether this is terminal
   history hygiene.

## Read-Only Live Monitor Idea

Keep this read-only and separate from deployment:

- Verify `T_Live` terminal process is present.
- Parse `T_Live` config for the visible AutoTrading/Experts state.
- Hash-check live `.set` and `.ex5` files against the Go-Live package.
- Parse live setfiles for `RISK_PERCENT`, `PORTFOLIO_WEIGHT`, magic slot offset,
  EA id, symbol, and environment.
- Produce a JSON/Markdown snapshot and alerts, but never write to `T_Live`, never
  start/stop terminals, and never toggle AutoTrading.
