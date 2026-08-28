# FX cointegration fleet — hard CPU ceiling stop

Date: 2026-08-28 UTC (`2026-08-28T06:00:51.9467093Z`); 2026-08-28
08:00 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `22096803122fad72b7f43d1a00bddf1a695bd43a`

Status: stopped at the explicit backtest CPU ceiling before claim, card, build,
compile, backtest, dispatch, or queue mutation.

## FX frontier disposition

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published v3
threshold selected only two relationships from the 66-pair scan: `QM5_12532`
AUDUSD/NZDUSD and `QM5_12533` EURJPY/GBPJPY. Both are built. The committed
sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships. There is no new unbuilt scan-qualified pair
without weakening the published criterion or duplicating governed work.

Durable evidence records both anchors as Q02 `PASS`, not blocked by `ONINIT` or
`NO_HISTORY`; their later outcomes are respectively Q04 `PASS` / Q05 `FAIL`
and Q04 `FAIL`. The existing FX fallback `QM5_20255` USDCHF/EURJPY retains a
known exact pending Q04 successor. None of those states was mutated after the
capacity stop bound.

The Strategy Card extraction gate therefore remained closed, and the build
preflight did not open because there is no new approved, registry-ready,
non-duplicate identity.

## Binding capacity result

Five one-second whole-host CPU samples were `100.000000%`, `100.000000%`,
`98.539023%`, `98.047076%`, and `94.448094%`. Average CPU was `98.206839%`
and maximum CPU was `100.000000%`. The governed tester-admission ceiling binds
when either measure reaches `97%`; both measures triggered the stop.

The supported process snapshot at `2026-08-28T06:00:46Z` found three factory
testers running on `T4`, `T6`, and `T10`, with three active reservations, all
ten terminal-worker daemons alive, and no orphaned factory terminal. The
visible work comprised one Q03 and two Q10_NEWS runs. `T_Live` and an unrelated
FTMO terminal were observed only to exclude them; neither was controlled.

The concurrent supported active-work query encountered
`sqlite3.OperationalError: database is locked`. It was not retried after the
binding CPU reading. This is recorded as current database contention, not as
evidence of stale work and not as authority to mutate claims or reservations.

## Non-duplicate delta

Relative to the preceding FX receipt at `2026-08-28T05:18:33Z`, the running
tester set contracted from four terminals to three: `T2` released its
`QM5_12855` Q10_NEWS tester, while `T4`, `T6`, and `T10` remained visible.
Average CPU rose from `97.842491%` to `98.206839%`, and the maximum remained
`100%`. The changed roster, load, and database-lock observation are the
material evidence in this commit; no strategy or queue action was repeated.

## Scope and safety boundary

No card, EA, registry row, magic row, resolver, binary, setfile, basket
manifest, build result, smoke run, backtest, Q02 or later work item, queue
priority, verdict, reservation, terminal, or worker was created or changed.
The portfolio gate, `portfolio_admission`, `_kpi`, `_q08_contribution`,
`T_Live`, AutoTrading, and live/deploy manifests were untouched. Existing
unrelated shared-worktree changes were preserved and excluded from this
evidence commit.

Machine-readable evidence is in
`artifacts/fx_cointegration_fleet_hard_cpu_stop_20260828T060051Z_board_advisor.json`.

## Continuation condition

Run a fresh five-sample capacity preflight on the next paced wake. Proceed only
when both average and maximum CPU are strictly below `97%`; then revalidate
`QM5_20255`'s exact pending Q04 successor and advance it once. Mechanize a new
pair only if a new OWNER-approved reputable-source record changes the governed
frontier.
