# V5 diversity funnel — hard CPU stop before claim

Date: 2026-08-27 UTC (`2026-08-27T07:16:09.8255754Z`)

Branch: `agents/board-advisor`

Status: stopped before backlog ranking, claiming, build, compile, smoke, repair,
or Q02 enqueue because the explicit backtest CPU ceiling was binding.

## Binding capacity result

Five fresh one-second whole-host CPU readings were `98.0825%`, `100%`, `100%`,
`100%`, and `100%`. Their average was `99.6165%` and their maximum was `100%`.
Both measures exceeded the farm worker's `CPU_MAX_LOAD_PERCENT = 97.0`
admission ceiling.

The supported farm slot scan at `2026-08-27T07:15:31Z` simultaneously found
seven governed factory terminals running: T2, T3, T4, T6, T8, T9, and T10.
All seven had reservations, and no orphaned factory terminal process was
reported. `T_Live` and the unrelated FTMO terminal were observed only so they
could be excluded; neither was controlled.

## Farm coordination

The read-only farm DB query reported nine active work items: one Q03, one Q07,
three Q09, and four Q10_NEWS rows. Seven matched the live factory processes.
The T1/QM5_11124 and T5/QM5_13036 rows did not have a live process or
reservation in the point-in-time slot snapshot. This is recorded only as a
snapshot divergence, not as a stale-row verdict or permission to reclaim a
slot; no reconciliation or repair ran at saturation.

The live T9 row is the diverse market-neutral Q03 basket `QM5_20238` on
`USDCAD/EURJPY`. It was left undisturbed. No approved build card was ranked or
claimed, so this paced agent cannot collide with another builder.

The immediately preceding receipt observed five running factory terminals.
The current seven-terminal topology adds T6 and T10 while host CPU remains
saturated, making this a fresh capacity delta rather than a duplicate EA build
or queue mutation.

## Stop disposition

Per the mission's hard stop, no card, EA identity, magic row, resolver, source,
setfile, EX5, build verdict, queue priority, work item, or pipeline verdict was
created or changed. No compiler, build check, smoke, backtest, dispatch tick,
worker action, or terminal action was started.

After CPU clears, the next valid unit is to re-sample capacity, atomically
claim the highest-diversity approved card in the farm DB, complete its strict
non-live build, and enqueue exactly its governed Q02 handoff.

The portfolio gate, `T_Live` manifest, `T_Live`, and AutoTrading were untouched.

Machine-readable evidence:
`artifacts/diversity_funnel_cpu_stop_20260827T071609Z_board_advisor.json`.
