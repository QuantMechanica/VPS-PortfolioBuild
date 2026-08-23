# FX cointegration frontier: hard CPU stop

**Date:** 2026-08-23 UTC (`2026-08-23T22:31:26Z`), 2026-08-24 Europe/Berlin

**Branch:** `agents/board-advisor`

**Status:** frozen 66-pair frontier remains fully mechanized; stopped at the
explicit backtest CPU ceiling before any build or queue mutation

## Outcome

No new Strategy Card or EA was created. The durable sign-aware relationship
audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships produced by
`analyze_cross_asset_v3.py --include-negative-hedges`: 66 covered and zero
uncovered. Creating another scan-derived identity would duplicate governed
work.

The preferred anchors still have durable Q02 PASS evidence and no durable
ONINIT or NO_HISTORY blocker: QM5_12532 later reached Q05 FAIL, and QM5_12533
later reached Q04 FAIL.

The last exact, non-duplicate existing-pair continuation remains rank 40
`USDJPY.DWX` / `NZDUSD.DWX`, implemented as
`QM5_20219_usdjpy-nzdusd`. The immediately preceding durable receipt records
Q02 PASS and the hash-bound v4 Q03 work item
`4514a6c7-0a2e-4523-a756-b63a232dd8aa` pending exactly once. No second enqueue
is valid. This run did not query past that durable queue receipt after the CPU
ceiling bound.

## Binding capacity stop

Five fresh whole-host CPU samples were `98.1462%`, `95.9071%`, `93.3658%`,
`89.1661%`, and `99.4154%`. Their average was `95.2001%`, and their maximum
was `99.4154%`. The explicit ceiling binds when either the average or maximum
is at least `97%`; the maximum therefore triggered the required stop. The
paced launch gate remains `1`.

At the sample, the host had 21.35 GiB free of 63.12 GiB physical memory and
137.84 GiB free on `D:`. `farmctl` was not available on this shell's PATH, so
no fresh terminal roster is asserted in this receipt.

Per the mission stop condition, no compile, build check, card or EA creation,
queue mutation, dispatch tick, tester launch, terminal reservation, terminal
control, or backtest followed. Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_cpu_stop_20260823T223126Z_board_advisor.json`.

## Safety

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry row, or magic row
  changed.
- Concurrent unrelated worktree changes were left unstaged and untouched.
