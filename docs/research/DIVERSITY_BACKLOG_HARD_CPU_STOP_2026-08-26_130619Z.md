# Diversity backlog mission — hard CPU stop

Date: 2026-08-26 UTC (`2026-08-26T13:06:19.5952269Z`)

Branch: `agents/board-advisor`

Observation base: `0c877694733e9d370c20ae6c43764afebb231704`

Status: stopped at the explicit backtest CPU ceiling before claiming an EA,
compiling, reviewing, enqueueing, dispatching, or running a tester.

## Binding capacity result

The mandatory five-sample whole-host capacity check returned `100.0%` on every
sample. Average and maximum CPU were therefore both `100.0%`, above the binding
`97%` ceiling. Eight `metatester64` processes were present on the final read.

This is a materially different saturation snapshot from the immediately prior
commodity receipt: the governed host moved from five MetaTester processes and
`98.46%` average CPU at `2026-08-26T12:32:44Z` to eight processes and `100.0%`
average CPU at `2026-08-26T13:06:19Z`.

## Read-only backlog and duplicate check

A WAL-safe, read-only query of the shared farm database found 43 pending
`build_ea` tasks. Filesystem reconciliation showed:

- 39 already have both `.mq5` and `.ex5` artifacts;
- two have `.mq5` but no `.ex5` (`QM5_1457`, `QM5_1459`);
- two malformed recovery rows have neither a slug nor an EA directory
  (`QM5_20104`, `QM5_20123`).

The diverse-looking pending rows were not blindly rebuilt:

- `QM5_32007_london-fix-wm-reuters-currency-drift` is already committed
  (`65f06eab9`), has Q02 PASS on both EURUSD.DWX and GBPUSD.DWX, and has terminal
  Q04 FAIL on both symbols. Its pending build task is stale bookkeeping, not an
  unbuilt sleeve.
- `QM5_10012_rw-fx-intraday-seas` already has Q02 PASS evidence across its four
  FX symbols, Q03 PASS on AUDUSD.DWX, and Q04 strategy failures or pending Q04
  rows. It is not blocked at Q02-Q03 by current ONINIT, NO_HISTORY, or stale-EX5
  infrastructure.
- `QM5_1457_as-predict-bonds` is the rates-shaped source-only row, but its card
  explicitly carries `r3_data_available: FAIL` because the Treasury, cash,
  commodity, and yield inputs are absent from the approved DWX universe. It is
  ineligible for the governed build workflow.

No EA was claimed in the farm DB because the hard capacity stop bound first.
This leaves no false in-flight marker and avoids colliding with another paced
agent when capacity clears.

## Scope boundary

No Strategy Card, EA source, binary, setfile, registry row, magic row, build
task, review task, or work item was changed. No queue priority, dispatch tick,
terminal reservation, terminal process, portfolio gate, `T_Live` manifest, or
AutoTrading state was touched. Concurrent unrelated worktree changes were
preserved and excluded from this receipt.

Machine-readable evidence is in
`artifacts/diversity_backlog_hard_cpu_stop_20260826T130619Z_board_advisor.json`.
