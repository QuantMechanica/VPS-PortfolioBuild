# FX cointegration fleet — hard CPU ceiling stop

Date: 2026-08-28 UTC (`2026-08-28T05:18:33.9436311Z`); 2026-08-28
07:18 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `0c7559d743db32bee2b7dadd0d1eb24d26f0ed2d`

Status: stopped at the explicit backtest CPU ceiling before claim, card, build,
compile, backtest, dispatch, or queue mutation.

## FX frontier disposition

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, backed by the
OWNER-ratified SRC02 intake and its complete bounded Chan cointegration
extract. The published v3 threshold selected only two relationships from the
66-pair scan: `QM5_12532` AUDUSD/NZDUSD and `QM5_12533` EURJPY/GBPJPY. Both are
built. The committed sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships. There is no new unbuilt scan-qualified pair
without weakening the published source criterion or duplicating governed work.

Durable evidence records both anchors as Q02 `PASS`, not blocked by `ONINIT` or
`NO_HISTORY`; their later outcomes are respectively Q04 `PASS` / Q05 `FAIL`
and Q04 `FAIL`. The existing FX fallback `QM5_20255` USDCHF/EURJPY retains a
known exact pending Q04 successor. None of these states was mutated after the
capacity stop bound.

The V5 extraction skill therefore kept the new-card gate closed, and the build
skill preflight did not open because there is no new approved, registry-ready,
non-duplicate identity.

## Binding capacity result

Five one-second whole-host CPU samples were `100.000000%`, `100.000000%`,
`99.902605%`, `89.700438%`, and `99.609413%`. Average CPU was `97.842491%`
and maximum CPU was `100.000000%`. The governed tester-admission ceiling binds
when either measure reaches `97%`; both measures triggered the stop.

The supported process snapshot at `2026-08-28T05:18:29Z` found four factory
testers running on `T2`, `T4`, `T6`, and `T10`, with four active reservations,
all ten terminal-worker daemons alive, and no orphaned factory terminal. The
visible work comprised one Q03 and three Q10_NEWS runs. `T_Live` and an
unrelated FTMO terminal were observed only to exclude them; neither was
controlled.

The supported active-work query returned ten active rows: two OPT_CENSUS, one
Q03, three Q09, and four Q10_NEWS. Six claimed rows (`T1`, `T3`, `T5`, `T7`,
`T8`, and `T9`) had no matching tester process in this point-in-time snapshot.
Those mismatches were observed only; they do not establish stale work or
authorize reclaim, restamp, priority change, or duplicate enqueue.

## Non-duplicate delta

Relative to the preceding FX receipt at `2026-08-28T03:31:06Z`, the active
ledger grew from nine to ten rows and the Q09 cohort from two to three. The
running-terminal set contracted from five to four as `T1` released its process,
while an active `QM5_11422` Q10_NEWS row was visible for T1. `T2` rotated from
`QM5_1537` to `QM5_12855` Q10_NEWS. Average load eased from `100%` to
`97.842491%`, but remained above the ceiling and the maximum stayed `100%`.
This changed coordination, roster, and load state is the material evidence in
this commit; it is not a repeated strategy or queue action.

## Scope and safety boundary

No card, EA, registry row, magic row, resolver, binary, setfile, basket
manifest, build result, smoke run, backtest, Q02 or later work item, queue
priority, verdict, reservation, terminal, or worker was created or changed.
The portfolio gate, `portfolio_admission`, `_kpi`, `_q08_contribution`,
`T_Live`, AutoTrading, and live/deploy manifests were untouched. Existing
unrelated shared-worktree changes were preserved and excluded from this
evidence commit.

Machine-readable evidence is in
`artifacts/fx_cointegration_fleet_hard_cpu_stop_20260828T051833Z_board_advisor.json`.

## Continuation condition

Run a fresh five-sample capacity preflight on the next paced wake. Proceed only
when both average and maximum CPU are strictly below `97%`; then revalidate the
exact existing FX successor and dispatch one non-duplicate non-live work item,
or mechanize a new pair only if a new OWNER-approved reputable-source record
changes the governed frontier.
