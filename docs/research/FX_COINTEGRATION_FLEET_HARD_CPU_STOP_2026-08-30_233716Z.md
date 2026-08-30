# FX cointegration fleet — hard CPU ceiling stop

Date: 2026-08-30 UTC (`2026-08-30T23:37:16.4720738Z`); 01:37 on
2026-08-31 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `eaac72f4c3656762688c856f762f7469ff4edcb6`

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
The durable sign-aware coverage receipt accounts for all 66 relationships. A
fresh census found 120 approved cointegration Card identities, 120 matching
EA directories, and zero approved unbuilt identities. Since the preceding
receipt, the only changed cointegration path is an automatically generated
Q06 stress setfile for the already-built active predecessor `QM5_20224`; no
Card or EA identity changed. Creating a new Card or EA would therefore
duplicate governed coverage or weaken the reputable-source criterion. The
Strategy Card extraction and EA build gates stayed closed.

## One concrete existing-pair fallback

The next dependency-correct pair is frozen-scan rank 59,
`QM5_20240_USDCHF_GBPJPY_COINTEGRATION_D1`. Its approved Tier-A Chan-backed
Card, basket manifest, compiled package, and canonical logical-basket setfile
passed fresh static checks. The setfile remains `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; the strategy is structural D1
fixed-beta residual reversion with no learned model, adaptive refit, banned
indicator, grid, or martingale.

The exact Q03 row `65a8b9cb-2c57-4068-81fb-2158f7b1beb7` is pending,
unclaimed, attempt zero, v4, unique, free of holds/supersession/quarantine, and
already `priority_track=true` at canonical pending rank 1,562. Its Q02
predecessor `24154a28-be35-469e-a5be-58881e29733c` is PASS. The existing Q04
row must remain untouched until Q03 passes. The original scan evidence is
adverse (DEV Sharpe -0.079, OOS Sharpe -0.430), so this remains a one-shot
falsification path with retirement rather than rescue tuning after a terminal
economic failure.

## New serialized-fleet progress

The state materially advanced after the preceding stop receipt:

- `QM5_20232` moved from active Q04 to terminal `FAIL` at
  `2026-08-30T22:27:37Z`;
- `QM5_20238` moved from pending Q04 to terminal `FAIL` at
  `2026-08-30T23:01:22Z`; and
- `QM5_20224` moved beyond Q05 PASS and is now the single active FX basket at
  Q06, work item `d13cf596-44a4-429d-92a7-2de6b1a3e7f0` on T10.

This is new lineage evidence, not a duplicate of the 22:17 UTC receipt.

## Binding capacity result

Five fresh one-second whole-host CPU samples were `91.322538%`, `94.353506%`,
`99.420222%`, `100%`, and `100%`. Average CPU was `97.019253%` and maximum CPU
was `100%`. The mission ceiling binds when either measure reaches 97%; both
measures triggered the stop.

The canonical farm snapshot immediately afterward contained seven active
rows: three `OPT_CENSUS`, one Q06, one Q07, and two `Q10_NEWS`. No worker or
terminal was controlled.

## Safety boundary and continuation

No Card, EA, EX5, setfile, basket manifest, registry, magic row, queue row,
payload, priority, claim, status, verdict, reservation, worker, terminal,
compile, smoke test, or backtest was created or changed. The portfolio gate,
`portfolio_admission`, portfolio `_kpi`, `_q08_contribution`, T_Live manifest,
AutoTrading, and all live/deploy manifests were untouched. The unrelated
pre-existing worktree edits to `QM5_41229_wti-samecal-trimean5.mq5` and
`compile_work_items.py` were preserved and excluded from this commit.

Machine-readable evidence is in
`artifacts/fx_cointegration_fleet_hard_cpu_stop_20260830T233716Z_board_advisor.json`.

On the next paced wake, take a fresh five-sample whole-host CPU window. Only
when both average and maximum are strictly below 97%, and after the active
`QM5_20224` Q06 basket reaches a canonical terminal state, may the resident
paced worker claim the existing exact `QM5_20240` Q03 row. Never enqueue a
duplicate, never advance its Q04 row before Q03 PASS, and do not priority-bind
rank-60 `QM5_20246` ahead of rank-59 `QM5_20240`.
