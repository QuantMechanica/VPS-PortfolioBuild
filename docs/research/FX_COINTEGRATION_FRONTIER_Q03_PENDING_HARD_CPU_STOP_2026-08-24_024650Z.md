# FX cointegration frontier: current Q03 continuation / hard CPU stop

**Date:** 2026-08-24 UTC (`2026-08-24T02:46:50Z`), Europe/Berlin

**Branch:** `agents/board-advisor`

**Base commit:** `21abacee2d03cb514a4f98e619e3bb54b87972f7`

**Status:** no non-duplicate unbuilt scan pair; existing FX continuation remains
pending exactly once at Q03; stopped at the explicit backtest CPU ceiling

## Outcome

No new Strategy Card or EA was created. The durable sign-aware relationship
audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships produced by the governed scan: 66 covered
and zero uncovered. A fresh repository reconciliation also found zero approved
card files whose names contain `cointegration` or `coint` without a matching
EA directory. Creating another scan-derived identity would therefore duplicate
governed work.

The preferred anchors do not need Q02 infrastructure repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has canonical Q02 PASS and later reached
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has canonical Q02 PASS and later
  reached Q04 FAIL.

Neither anchor has a current Q02 ONINIT or NO_HISTORY blocker.

## Concrete existing-pair continuation

The exact nonterminal scan continuation remains rank 40,
`USDJPY.DWX` / `NZDUSD.DWX`, implemented as `QM5_20219_usdjpy-nzdusd`.
The supported work-item view reconfirmed this lineage:

- Q02 `5eb61981-472e-4f08-82c0-53fbec77d6c8`: DONE/PASS.
- Q03 `4514a6c7-0a2e-4523-a756-b63a232dd8aa`: PENDING, unclaimed,
  `attempt_count=0`.
- Legacy Q04 `b721ce82-2d53-46db-b2d0-f20b561a1513`: PENDING, unclaimed,
  `attempt_count=0`.

The Q03 successor is already present exactly once. Enqueueing, requeueing,
reprioritising, or dispatching a second row would be duplicate work. The
`qm-run-pipeline-phase` skill does not authorize Q03 through its later-phase
runner; Q03 remains with the canonical farm queue.

## Binding capacity stop

Five fresh one-second whole-host CPU readings were `100%`, `100%`, `100%`,
`99%`, and `100%`. Their average was `99.8%` and their maximum was `100%`.
The explicit ceiling binds when either value is at least `97%`, so the mission
stopped before any build, queue mutation, dispatch, or tester action. The paced
launch maximum remains `1`.

At the sample, the host had 34.248 GiB free of 63.120 GiB physical memory and
135.640 GiB free on `D:`. The farm reported 43 pending builds, 33 pending P2
items, 146 pending Q03 items, and 62 pending Q04 items. Backlog size does not
override the CPU ceiling.

This is a non-duplicate update to the preceding FX receipt at `01:49:16Z`:
the current CPU average increased from `93.4676%` to `99.8%`, while the exact
QM5_20219 Q03 lineage remained pending once, and the fresh approved-card/EA
reconciliation found no unbuilt cointegration card.

Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_q03_pending_hard_cpu_stop_20260824T024650Z_board_advisor.json`.

## Safety

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No card, EA, EX5, setfile, basket manifest, registry row, or magic row
  changed.
- Concurrent unrelated worktree changes were left unstaged and untouched.
