# Diversity funnel — CPU-ceiling stop before claim

Date: 2026-08-31 UTC (`2026-08-31T00:02:51.1076785Z`); 2026-08-31
02:02 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `8918c3027fc8c213681e23de4a2b28f61dfe4c22`

Status: stopped at the explicit backtest CPU ceiling before approved-backlog
ranking, farm claim, EA selection, build, infrastructure repair, mechanization,
compile, smoke, or Q02 enqueue.

## Binding capacity result

The fresh five-sample whole-host CPU window measured `98.535497%`,
`97.278067%`, `98.351502%`, `99.707174%`, and `98.927920%`. Average CPU was
`98.560032%` and maximum CPU was `99.707174%`. The paced admission rule
requires both measures to remain strictly below `97%`; both sides of the rule
therefore bound.

No confirmation window was used to reopen this wake. Once the explicit stop
condition bound, work admission remained closed.

## Farm coordination state

The supported read-only farm status, captured immediately before the capacity
sample, exposed three active and 64 pending `build_ea` tasks. No task was
ranked or claimed.

The supported MT5 slot scan showed four process-bound factory rows:

- `T4`: `QM5_10571`, `XAUUSD.DWX`, Q07, work item
  `2356cfd9-dd59-4347-a080-13d2e48a2624`.
- `T6`: `QM5_41163`, `USDCAD.DWX`, OPT_CENSUS, work item
  `8a6839ef-3266-52e4-89fd-658dfbf87ea3`.
- `T7`: `QM5_20086`, `EURUSD.DWX`, Q10_NEWS, work item
  `d5311da3-01b0-4902-9347-638506db0ccf`.
- `T10`: `QM5_41196`, `XAUUSD.DWX`, OPT_CENSUS, work item
  `312966db-c11b-58d5-a6e3-6aeb18a04682`.

All four terminals had matching fresh reservations. Ten terminal-worker
daemons were present, with no duplicate worker and no orphaned factory
terminal process. The `T_Live` process and an external FTMO terminal were
observed by the read-only scan only; neither was controlled or changed.

## Non-duplicate delta

The most recent committed capacity receipt, at `2026-08-30T02:00:53Z`, saw
three visible factory terminals (`T2`, `T3`, `T10`) and six active farm rows.
This sample saw a changed four-terminal roster (`T4`, `T6`, `T7`, `T10`) with
two OPT_CENSUS rows plus Q07 and Q10_NEWS work. The pending `build_ea` count
also rose from 58 to 64. The changed workload topology and fresh, materially
binding CPU window make this a distinct coordination receipt, not a duplicate
of the prior stop.

## Scope and safety boundary

The `qm-build-ea-from-card` procedure and standard `codex_build_ea` contract
were read for preflight only. No Strategy Card, G0 decision, EA source or
binary, setfile, registry, magic row, resolver, build result, queue row, claim,
priority, task status, work-item status, verdict, or pipeline evidence was
mutated. No compile, build check, smoke, backtest, dispatch tick, terminal
control, or worker control was started.

The portfolio gate, portfolio-admission surfaces, `T_Live`, AutoTrading, and
live/deploy manifests were untouched. Existing unrelated shared-worktree
changes were preserved and excluded from this commit.

Machine-readable evidence is in
`artifacts/diversity_funnel_cpu_ceiling_stop_20260831T000251Z_board_advisor.json`.

## Continuation condition

A later paced wake must take a fresh five-sample capacity window. Proceed only
when both average and maximum are strictly below `97%`; then rank and
atomically claim exactly one distinct diversity-first unit through the farm
DB, prefer an approved forex, available crypto, non-XNG energy, rates, or
market-neutral card, keep backtest setfiles at `RISK_FIXED`, and enqueue Q02
without dispatching or touching portfolio/live surfaces.
