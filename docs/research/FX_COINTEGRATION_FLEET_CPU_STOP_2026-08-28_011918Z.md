# FX cointegration fleet — changed-roster CPU ceiling stop

Date: 2026-08-28 UTC (`2026-08-28T01:19:18.0108072Z`); 2026-08-28
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `20edea4ff4f02ca54e5d8229b4eadba8700f94fb`

Status: stopped at the explicit backtest CPU ceiling before claim, card, build,
compile, backtest, dispatch, or queue mutation.

## FX frontier disposition

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published threshold
selected only two relationships from the 66-pair scan: `QM5_12532` AUD/NZD and
`QM5_12533` EURJPY/GBPJPY. Both are built. The committed sign-aware coverage
audit cited by
`artifacts/fx_cointegration_fleet_cpu_stop_20260828T003105Z_board_advisor.json`
accounts for all 66 relationships, so no new unbuilt scan-qualified pair is
eligible without duplicating governed coverage or weakening the reputable-
source criterion.

The same durable evidence records `QM5_12532` and `QM5_12533` as Q02 `PASS`,
not blocked by `ONINIT` or `NO_HISTORY`; their later outcomes are respectively
Q04 `PASS` / Q05 `FAIL` and Q04 `FAIL`. The existing fallback
`QM5_20255` USDCHF/EURJPY still has a known exact pending Q04 successor in that
receipt. None of those states was mutated. Once the ceiling bound, no fresh
database or backtest query was used to revise strategy state.

## Binding capacity result

Five one-second whole-host CPU samples were `97.270017%`, `97.860832%`,
`97.757533%`, `75.359996%`, and `89.167029%`. Average CPU was `91.483081%`
and maximum CPU was `97.860832%`. The governed admission ceiling binds when
either measure reaches `97%`; the maximum triggered the stop.

The supported process snapshot at `2026-08-28T01:19:25Z` found five factory
testers already running on `T1`, `T2`, `T6`, `T8`, and `T10`, with five active
reservations, all ten worker daemons alive, and no orphaned factory terminal.
The visible work comprised one `OPT_CENSUS`, one `Q03`, and three `Q10_NEWS`
runs. `T_Live` and an unrelated FTMO terminal were observed only to exclude
them; neither was controlled.

The supported active-work query failed twice with
`sqlite3.OperationalError: database is locked`. That is recorded as a
coordination limitation only; it does not establish stale work or authorize a
reclaim, restamp, priority change, or duplicate enqueue.

## Non-duplicate delta

Relative to the preceding FX receipt at `2026-08-28T00:31:05Z`, visible
factory testers increased from two (`T1`, `T6`) to five (`T1`, `T2`, `T6`,
`T8`, `T10`). Relative to the latest branch-wide receipt at
`2026-08-28T01:03:42Z`, `T4` and `T9` are no longer visible and the tester
count fell from seven to five. This changed roster makes the receipt
non-duplicate, while the fresh maximum confirms that admission remains
blocked.

## Scope and safety boundary

No card, EA, registry row, magic row, resolver, binary, setfile, build result,
smoke run, backtest, Q02 or later work item, queue priority, verdict,
reservation, terminal, or worker was created or changed. The portfolio gate,
`portfolio_admission`, `_kpi`, `_q08_contribution`, `T_Live`, AutoTrading, and
live/deploy manifests were untouched. Existing unrelated shared-worktree
changes were preserved and excluded from this evidence commit.

Machine-readable evidence is in
`artifacts/fx_cointegration_fleet_cpu_stop_20260828T011918Z_board_advisor.json`.

## Continuation condition

Run a fresh five-sample capacity preflight on the next paced wake. Proceed
only when both average and maximum CPU are below `97%`; then revalidate the
existing FX successor and dispatch exactly one non-duplicate non-live work
item, or mechanize a newly OWNER-approved reputable-source pair if the
governed frontier changes.
