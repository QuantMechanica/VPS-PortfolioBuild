# QM5_20246 FX cointegration Q03 hard-CPU stop

Date: 2026-08-31 UTC (`2026-08-31T05:51:13Z`); 07:51 Europe/Berlin

Branch: `agents/board-advisor`

Status: the next exact existing FX successor was identified and fully
revalidated, but the apply-time CPU maximum reached `99.806936%`. The binding
ceiling is `97%` on either the five-sample average or maximum, so work stopped
before any queue, priority, claim, tester, terminal, or pipeline mutation.

## Frontier result

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its frozen v3 study
tested 66 FX relationships and admitted only two under the published criterion
of positive DEV Sharpe, OOS net Sharpe above 0.8, and at least four OOS trades:

| EA | Pair | Current canonical frontier |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS; Q04 FAIL |

Neither anchor has a current logical-basket Q02 `ONINIT` or `NO_HISTORY`
blocker. Historical invalid physical-leg rows do not supersede the later
logical-basket PASS rows.

The committed sign-aware audit accounts for all 66 relationships. A fresh
census found 120 approved Cards containing `cointegration` or `coint`, 120
unique EA IDs, and a matching EA directory for all 120. There is no approved
unbuilt identity. Creating another Card or EA would duplicate governed
coverage or weaken the published source criterion, so the mission's existing
forex fallback applies. The card-extraction and EA-build skill gates therefore
remained closed.

## Selected existing pair

The next untouched, dependency-complete sleeve is frozen-scan rank 60,
`QM5_20246_USDJPY_EURGBP_COINTEGRATION_D1`. It trades `USDJPY.DWX` and
`EURGBP.DWX`; `GBPUSD.DWX` and `EURUSD.DWX` provide conversion history only.
The fixed beta is `-1.281773609960` on D1.

This comes after the farther-advanced rank-46 `QM5_20224`, whose unique Q07
retry is already priority-bound, and rank-59 `QM5_20240`, whose exact Q03 row
already carries `priority_track`. Rewriting either would be duplicate work.
QM5_20246's exact Q03 row has not received a priority handoff.

The source evidence remains deliberately adverse: DEV net Sharpe
`0.252701098850`, OOS net Sharpe `-0.456864966287`, OOS return
`-6.371810072221%`, 13 OOS state changes, and a `132.813394758594`-bar
half-life. This is a one-shot pipeline falsification, not permission to refit
the beta, add a rescue filter, or substitute parameters.

## Package and lineage verification

Card schema/ML lint passed with no missing sections or ML hits. The EA remains
structural, fixed-beta, deterministic, low-frequency, and free of adaptive
refits, banned indicators, grid, martingale, or portfolio feedback. Its basket
manifest declares the two traded legs and two conversion-only histories.

The logical setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Its clean checkout has a final-newline convention
difference: CRLF canonicalization reproduces the exact Q02-sealed SHA-256
`94923d6a78f9e2abbc66b4c8b268fb5b5cb9cbdc50c4a24f6c5b1aa7b5bb7cbb`.
No setfile or strategy file was edited.

Canonical lineage:

| Phase | Work item | State |
|---|---|---|
| Q02 | `d8619249-7764-4d80-a714-6b7922b73b4b` | done / PASS; 136 trades, PF 1.11, DD 5.43%, no OnInit failure |
| Q03 | `46c97cb3-45f9-475d-8e6b-aa7bdd40df0e` | pending, unclaimed, attempt zero, unverdict, no priority/hold/supersession/quarantine |
| Q04 | `1a269ff4-cbef-429b-afa4-47a3cc692916` | pending; deliberately not advanced before Q03 PASS |

The Q03 row's canonical pending rank was 8,422. The intended bounded action
was an exact-ID, in-place priority payload CAS, not a new enqueue. That action
was not started after the capacity stop bound.

## Capacity stop

The initial five readings were `58.708368%`, `70.170466%`, `74.417455%`,
`70.613942%`, and `73.440538%` (average `69.470154%`, maximum
`74.417455%`). At apply time the five readings were `99.806936%`,
`94.253562%`, `85.945302%`, `86.329572%`, and `92.106487%` (average
`91.688372%`, maximum `99.806936%`). The maximum crossed the hard ceiling even
though the average did not, so the stop rule binds.

The immediately preceding farm snapshot showed nine active rows: four
`OPT_CENSUS`, one Q07, and four `Q10_NEWS`. No logical multisymbol row was
active at that instant. Exact factory paths showed T1, T4, and T10 running;
all ten worker daemons were present and no orphaned factory terminal was
reported. `T_Live` was observed only to exclude it and was not controlled.

## Safety and continuation

No Card, EA, EX5, setfile, basket manifest, registry, magic row, queue row,
priority, status, claim, attempt, verdict, dispatch, compile, smoke run, or
backtest was created or changed. The portfolio gate, `portfolio_admission`,
portfolio `_kpi`, `_q08_contribution`, T_Live manifest, AutoTrading, and all
live/deploy manifests were untouched. Concurrent unrelated worktree changes
were preserved.

On a later paced wake, take a fresh five-sample CPU window. Proceed only if
both average and maximum are below 97%; then revalidate and priority-bind the
same exact Q03 row in place. Do not enqueue another Q02/Q03 row, advance Q04
before Q03 PASS, or manually force a second basket.

Machine-readable evidence:
`artifacts/qm5_20246_q03_hard_cpu_stop_20260831T055113Z_board_advisor.json`.
