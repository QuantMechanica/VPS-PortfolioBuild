# FX cointegration fleet — hard CPU ceiling stop

Date: 2026-08-30 UTC (`2026-08-30T22:17:08.2698319Z`); 00:17 on
2026-08-31 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `5b77d028fe6fbba75a35dc400889006391b85705`

Status: stopped at the explicit backtest CPU ceiling before any Card, build,
queue mutation, dispatch, compile, smoke test, or backtest.

## Governed frontier decision

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its frozen v3 scan
tested all 66 FX relationships and admitted only two under the published
criterion of positive DEV Sharpe, OOS net Sharpe above 0.8, and at least four
OOS trades:

| EA | Pair | Canonical state |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS; Q04 FAIL |

Neither anchor is currently blocked at Q02 by `ONINIT` or `NO_HISTORY`.
The durable sign-aware coverage receipt
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships. The latest committed census found 120
approved cointegration Card identities, 120 matching EA directories, and zero
approved unbuilt identities. Between that census receipt and this observation
base, eight approved-card/EA paths changed and none was cointegration-related.
Creating a new Card or EA would therefore duplicate governed coverage or
weaken the reputable-source criterion. The Strategy Card extraction and EA
build gates stayed closed.

## Existing forex fallback state

The serialized existing-sleeve chain made real progress after the preceding
handoff:

- rank-46 `QM5_20224_EURUSD_EURJPY_COINTEGRATION_D1` completed Q05 with
  `PASS` at `2026-08-30T21:59:52Z`;
- rank-55 `QM5_20232_USDCHF_NZDUSD_COINTEGRATION_D1` Q04 work item
  `bfad4436-ae19-4b7d-a7cf-1c02a0324d67` is active on T1;
- rank-57 `QM5_20238_USDCAD_EURJPY_COINTEGRATION_D1` retains exactly one
  pending, priority-bound Q04 row,
  `fcc4268d-4966-4ea6-ba14-4b684fe41a28`; and
- the next dependency-correct existing pair, rank-58
  `QM5_20240_USDCHF_GBPJPY_COINTEGRATION_D1`, already has Q02 PASS and an
  existing pending, priority-bound Q03 row. Its existing Q04 row must not be
  advanced before Q03 PASS.

All of these are structural, low-frequency D1 baskets with their existing
fixed-risk contracts. No adaptive refit, machine learning, banned indicator,
grid, martingale, or portfolio feedback was introduced.

## Binding capacity result

Five fresh one-second whole-host CPU samples were `98.634320%`, `95.822161%`,
`100.000000%`, `98.050034%`, and `96.881589%`. Average CPU was `97.877621%`
and maximum CPU was `100.000000%`. The mission ceiling binds when either
measure reaches 97%; both measures triggered the stop.

The canonical farm snapshot immediately afterward contained eight active
rows: five `OPT_CENSUS`, two `Q10_NEWS`, and the single active
`QM5_20232` Q04 basket. No worker or terminal was controlled.

## Non-duplicate delta

Relative to
`artifacts/qm5_20238_q04_priority_20260830T212103Z_board_advisor.json`, the
serialized basket lane advanced from active `QM5_20224` Q05 on T4 to its
canonical PASS, then admitted `QM5_20232` Q04 on T1. The fresh CPU maximum
rose from 94% to 100% and became binding. This changed lineage and capacity
state is new evidence; no duplicate work item or strategy was created.

## Safety boundary and continuation

No Card, EA, EX5, setfile, basket manifest, registry, magic row, queue row,
payload, priority, claim, status, verdict, reservation, worker, terminal,
compile, smoke test, or backtest was created or changed. The portfolio gate,
`portfolio_admission`, portfolio `_kpi`, `_q08_contribution`, T_Live manifest,
AutoTrading, and all live/deploy manifests were untouched. The two unrelated
pre-existing worktree edits were preserved and excluded from this commit.

Machine-readable evidence is in
`artifacts/fx_cointegration_fleet_hard_cpu_stop_20260830T221708Z_board_advisor.json`.

On the next paced wake, take a fresh five-sample whole-host CPU window. Only
when both average and maximum are strictly below 97%, and after the active
`QM5_20232` Q04 row reaches a canonical terminal state, may the resident paced
worker claim the existing exact `QM5_20238` Q04 row. Never enqueue a duplicate
or advance `QM5_20240` Q04 before its existing Q03 row passes.
