# FX cointegration frontier: zero-terminal hard CPU stop

**Date:** 2026-08-24 UTC (`2026-08-24T13:12:23Z`), Europe/Berlin

**Branch:** `agents/board-advisor`

**Observation base:** `49794040ae7a667ae0f060a4c1ee2a3d2a8d8b2c`

**Status:** no non-duplicate unbuilt scan pair; the exact existing FX
continuation remains pending once at Q03; stopped at the explicit backtest CPU
ceiling despite no MT5 child process being visible

## Outcome

No new Strategy Card or EA was created. The durable sign-aware relationship
audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships produced by the governed scan: 66 covered
and zero uncovered. Creating another scan-derived identity would duplicate
governed work.

The preferred anchors do not need Q02 infrastructure repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has canonical Q02 PASS and later reached
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has canonical Q02 PASS and later
  reached Q04 FAIL.

Neither anchor has a current Q02 ONINIT or NO_HISTORY blocker.

## Concrete existing-pair continuation

The latest durable lineage still identifies frozen-scan rank 40,
`USDJPY.DWX` / `NZDUSD.DWX`, implemented as `QM5_20219_usdjpy-nzdusd`, as the
exact nonterminal FX continuation. Its approved package is structural
fixed-beta D1, low-frequency, contains `basket_manifest.json`, and keeps the
logical backtest contract at `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

The last completed lineage view records Q02
`5eb61981-472e-4f08-82c0-53fbec77d6c8` as DONE/PASS and Q03
`4514a6c7-0a2e-4523-a756-b63a232dd8aa` as PENDING, unclaimed, with zero
attempts. That Q03 successor already exists exactly once. The current run hit
the CPU ceiling before a new lineage query, and therefore made no duplicate
enqueue, requeue, reprioritisation, dispatch, or legacy-row mutation.

## Binding capacity stop

Five fresh one-second whole-host CPU readings were all `100%`. Their average
and maximum were both `100%`, above the explicit `97%` hard ceiling. The paced
launch maximum remains `1`.

The supported `farmctl mt5-slots` scan at `2026-08-24T13:04:51Z` found zero
running MT5 terminals, zero terminal workers, and zero orphaned terminal
processes. It separately reported active factory reservations for T1, T4, and
T5, all owned by custom-history smoke work. The absence of an MT5 child does
not override the measured whole-host CPU ceiling or authorize using reserved
slots.

Per the mission stop condition, no compile, build check, queue mutation,
dispatch, tester action, terminal reservation, terminal control, or backtest
followed. Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_q03_pending_hard_cpu_stop_20260824T131223Z_board_advisor.json`.

## Non-duplicate operational delta

The preceding `06:46:24Z` receipt observed nine governed factory terminals
and average CPU of `98.8%`. The current supported census instead sees zero MT5
children, three live factory reservations, and average CPU of `100%`. This is
a materially changed resource-topology receipt, not another card, EA, or
pipeline-row identity.

## Safety and worktree hygiene

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry row, or magic row
  changed.
- Concurrent unrelated staged and unstaged worktree changes were preserved;
  this run commits only the two evidence files named above.
