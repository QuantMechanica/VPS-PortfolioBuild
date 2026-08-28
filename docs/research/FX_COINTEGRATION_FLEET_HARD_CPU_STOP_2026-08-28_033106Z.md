# FX cointegration fleet — hard CPU ceiling stop

Date: 2026-08-28 UTC (`2026-08-28T03:31:06.7499677Z`); 2026-08-28
05:31 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `4ca5c1eb346762b611bfaf4a0fe5d67b28486448`

Status: stopped at the explicit backtest CPU ceiling before claim, card, build,
compile, backtest, dispatch, or queue mutation.

## FX frontier disposition

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published v3
threshold selected only two relationships from the 66-pair scan: `QM5_12532`
AUDUSD/NZDUSD and `QM5_12533` EURJPY/GBPJPY. Both are built. The committed
sign-aware coverage audit cited by
`artifacts/fx_cointegration_fleet_cpu_stop_20260828T003105Z_board_advisor.json`
accounts for all 66 relationships. There is no new unbuilt scan-qualified pair
without weakening the published source criterion or duplicating governed work.

Durable evidence records both anchors as Q02 `PASS`, not blocked by `ONINIT` or
`NO_HISTORY`; their later outcomes are respectively Q04 `PASS` / Q05 `FAIL`
and Q04 `FAIL`. The existing FX fallback `QM5_20255` USDCHF/EURJPY retains a
known exact pending Q04 successor. None of these states was mutated after the
capacity stop bound.

## Binding capacity result

Five one-second whole-host CPU samples were all `100.000000%`. Average and
maximum CPU were therefore both `100.000000%`. The governed tester-admission
ceiling binds when either measure reaches `97%`; both measures triggered the
stop.

The supported process snapshot at `2026-08-28T03:31:01Z` found five factory
testers running on `T1`, `T2`, `T4`, `T6`, and `T10`, with five active
reservations, all ten terminal-worker daemons alive, and no orphaned factory
terminal. The visible work comprised one Q03 and four Q10_NEWS runs. `T_Live`
and an unrelated FTMO terminal were observed only to exclude them; neither was
controlled.

The supported active-work query succeeded and returned nine active rows: two
OPT_CENSUS, one Q03, two Q09, and four Q10_NEWS. Four claimed rows (`T3`, `T5`,
`T7`, and `T9`) had no matching tester process in this point-in-time snapshot.
Those mismatches were observed only; they do not establish stale work or
authorize reclaim, restamp, priority change, or duplicate enqueue.

## Non-duplicate delta

Relative to the preceding branch receipt at `2026-08-28T02:46:47Z`, the active
database view recovered from `database is locked` and exposed nine coordinated
rows. The running-terminal set remains five, but `T4` rotated from
`QM5_10513` Q09 to `QM5_13054` Q10_NEWS. The fresh load window also strengthened
from `99.902617%` average / `100%` maximum to `100%` for both measures. This
changed coordination and process state is the material evidence in this
commit; it is not a repeated strategy or queue action.

## Scope and safety boundary

No card, EA, registry row, magic row, resolver, binary, setfile, basket
manifest, build result, smoke run, backtest, Q02 or later work item, queue
priority, verdict, reservation, terminal, or worker was created or changed.
The portfolio gate, `portfolio_admission`, `_kpi`, `_q08_contribution`,
`T_Live`, AutoTrading, and live/deploy manifests were untouched. Existing
unrelated shared-worktree changes were preserved and excluded from this
evidence commit.

Machine-readable evidence is in
`artifacts/fx_cointegration_fleet_hard_cpu_stop_20260828T033106Z_board_advisor.json`.

## Continuation condition

Run a fresh five-sample capacity preflight on the next paced wake. Proceed only
when both average and maximum CPU are strictly below `97%`; then revalidate the
exact existing FX successor and dispatch one non-duplicate non-live work item,
or mechanize a new pair only if a new OWNER-approved reputable-source record
changes the governed frontier.
