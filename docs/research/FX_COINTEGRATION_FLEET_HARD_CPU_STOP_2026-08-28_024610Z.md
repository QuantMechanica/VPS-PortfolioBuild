# FX cointegration fleet — hard CPU ceiling stop

Date: 2026-08-28 UTC (`2026-08-28T02:46:10.9273064Z`); 2026-08-28
04:46 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `b1da330316b452651d893e908cafc93c09cbb2cd`

Status: stopped at the explicit backtest CPU ceiling before claim, card, build,
compile, backtest, dispatch, or queue mutation.

## FX frontier disposition

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published threshold
selected only two relationships from the 66-pair scan: `QM5_12532` AUD/NZD and
`QM5_12533` EURJPY/GBPJPY. Both are built. The committed sign-aware coverage
audit cited by
`artifacts/fx_cointegration_fleet_cpu_stop_20260828T003105Z_board_advisor.json`
accounts for all 66 relationships. There is therefore no new unbuilt
scan-qualified pair without weakening the source criterion or duplicating
governed coverage.

Durable evidence records `QM5_12532` and `QM5_12533` as Q02 `PASS`, not blocked
by `ONINIT` or `NO_HISTORY`; their later outcomes are respectively Q04 `PASS` /
Q05 `FAIL` and Q04 `FAIL`. The existing FX fallback `QM5_20255`
USDCHF/EURJPY retains a known exact pending Q04 successor. None of these states
was mutated after the capacity stop bound.

## Binding capacity result

Five one-second whole-host CPU samples were `100.000000%`, `99.708376%`,
`100.000000%`, `100.000000%`, and `99.804711%`. Average CPU was `99.902617%`
and maximum CPU was `100.000000%`. The governed admission ceiling binds when
either measure reaches `97%`; both measures triggered the stop.

The supported process snapshot at `2026-08-28T02:46:25Z` found five factory
testers and five MetaTester processes running on `T1`, `T2`, `T4`, `T6`, and
`T10`, with five active reservations, all ten worker daemons alive, and no
orphaned factory terminal. The visible work comprised one `Q03`, one `Q09`,
and three `Q10_NEWS` runs. `T_Live` and an unrelated FTMO terminal were
observed only to exclude them; neither was controlled.

The supported active-work query failed with
`sqlite3.OperationalError: database is locked`. This is a coordination
limitation only; it does not establish stale work or authorize a reclaim,
restamp, priority change, or duplicate enqueue.

## Non-duplicate delta

Relative to the preceding branch receipt at `2026-08-28T02:31:57Z`, `T8` and
its `QM5_12849` Q10_NEWS process are no longer visible, reducing the factory
roster from six terminals to five. `T1` and `T2` have rotated to later run
processes for their existing work items. The capacity result also strengthened
from a maximum-only breach to a breach by both average (`99.902617%`) and
maximum (`100%`).

## Scope and safety boundary

No card, EA, registry row, magic row, resolver, binary, setfile, basket
manifest, build result, smoke run, backtest, Q02 or later work item, queue
priority, verdict, reservation, terminal, or worker was created or changed.
The portfolio gate, `portfolio_admission`, `_kpi`, `_q08_contribution`,
`T_Live`, AutoTrading, and live/deploy manifests were untouched. Existing
unrelated shared-worktree changes were preserved and excluded from this
evidence commit.

Machine-readable evidence is in
`artifacts/fx_cointegration_fleet_hard_cpu_stop_20260828T024610Z_board_advisor.json`.

## Continuation condition

Run a fresh five-sample capacity preflight on the next paced wake. Proceed
only when both average and maximum CPU are below `97%`; then revalidate the
exact existing FX successor and dispatch one non-duplicate non-live work item,
or mechanize a new pair only if a new OWNER-approved reputable-source record
changes the governed frontier.
