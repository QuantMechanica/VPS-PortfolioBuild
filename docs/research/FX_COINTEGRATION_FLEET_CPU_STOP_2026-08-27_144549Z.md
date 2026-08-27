# FX cointegration fleet — changed-state CPU ceiling stop

Date: 2026-08-27 UTC (`2026-08-27T14:45:49.4669777Z`); 2026-08-27
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `5eaf5610f38b75657561b9a9502ccf51ddcd2917`

Status: stopped at the explicit backtest CPU ceiling before selecting an
existing forex fallback, claiming work, building, repairing, compiling,
smoking, or enqueueing Q02.

## Frontier and anchor triage

The durable sign-aware scan reconciliation in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
still accounts for all 66 relationships: 66 covered and zero uncovered. A new
scan-derived pair would duplicate governed work.

The preferred anchors do not have a Q02 infrastructure blocker:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS, followed by
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS, followed by Q04
  FAIL.

The mission therefore reached its existing-card fallback, but capacity bound
before backlog ranking. No forex identity was selected or duplicate-enqueued.

## Binding capacity result

The five one-second whole-host CPU readings were `99.804950%`, `100.000000%`,
`100.000000%`, `100.000000%`, and `100.000000%`. Average CPU was
`99.960990%` and maximum CPU was `100.000000%`. Both measures exceed the
governed `CPU_MAX_LOAD_PERCENT = 97.0` tester-admission ceiling in
`tools/strategy_farm/terminal_worker.py`.

The supported read-only `farmctl mt5-slots` snapshot found seven governed
factory terminals actively testing: `T1`, `T2`, `T3`, `T4`, `T6`, `T7`, and
`T8`. Seven reservations were active, all ten terminal-worker daemons were
alive, and no orphaned factory terminal was reported. `T_Live` and the
unrelated FTMO terminal were observed only to exclude them; neither was
controlled.

The farm DB contained nine active rows: two OPT_CENSUS, one Q03, one Q07, one
Q09, and four Q10_NEWS. Claimed rows on `T5` and `T10` had no matching tester
process in this point-in-time snapshot. Those mismatches were observed only;
they do not authorize reclaim, retry, or duplicate enqueue.

## Non-duplicate observation delta

The preceding receipt at `2026-08-27T14:30:37Z` recorded six active rows and
running terminals `T2`, `T3`, `T6`, `T7`, and `T8`. This snapshot recorded
nine active rows and added `T1` and `T4` to the running set. One Q10_NEWS and
two OPT_CENSUS rows entered the active set, while average CPU rose from
`97.951763%` to `99.960990%`. This changed state is the material evidence in
the commit; it is not a repeated queue or strategy action.

Machine-readable evidence is in
`artifacts/fx_cointegration_fleet_cpu_stop_20260827T144549Z_board_advisor.json`.

## Scope and safety boundary

No card, EA, registry row, magic row, resolver, source, binary, setfile,
basket manifest, build result, compile task, smoke run, queue row, priority,
verdict, reservation, tester, terminal, or worker was created or changed. No
portfolio-admission, portfolio-KPI, Q08-contribution, `T_Live`, AutoTrading,
live, or deploy surface was touched.

## Continuation condition

On the next paced wake, rerun the capacity preflight. Only when both the
five-sample CPU average and maximum are below 97% should the fleet rank one
existing, non-terminal forex basket and advance exactly its next governed
phase.
