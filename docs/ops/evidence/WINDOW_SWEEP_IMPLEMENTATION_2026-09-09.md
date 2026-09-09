# WINSWEEP implementation — REVIEW, runtime rollout pending

Task 49af4f08-0d72-460d-959e-7c9a32db4650. Canonical board-advisor only.
Stage-A plan contains 60 windows and 420 deterministic annual cells; production
insertions, claims and measurements are **zero**. This is a partial delivery,
not acceptance of S5 or evidence of a winning window.

`tools/strategy_farm/window_sweep.py` seals the committed authority, verbatim
sections 3–5, baseline inputs, source and binary. The declaration is installed at
`D:/QM/strategy_farm/artifacts/opt_census/WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025/declaration.json`.
The planner changes only range start/end and exit. The existing 36-bar scan and
day-key filter cover the longest eight-hour window. The EA also requires three
range bars: the declared two-hour grid points can produce zero trades and remain
in the grid, subject to the declared frequency exclusion.

Queue identity includes exact symbol, period, expert, annual date bounds and
source/binary/setfile hashes. Native report ingestion verifies run_smoke/v2
identity, then reconciles deal counts and net profit before measuring. All 420
missing cells are explicit in `2026-09-09_window_sweep_surface.csv` and `.json`;
no selection is made. Costing follows the sealed literal rule: summary net minus
$5 per entry lot, with native commission exposed separately. This is an additional
charge against native net under this plan; it must not be described as commission
replacement. Stage-A full surface includes admissibility and stage scores.

Worker changes are limited to terminal_worker.py:

- 9808–9811: route the new schema through authentication, including malformed rows.
- 9982: distinguish the sealed window program.
- 10004: DL-089 pattern pruning applies only to its own program.
- 10019–10028: authenticate the window declaration/grid/artifacts; preserve the
  existing DL-089 amendment branch.

Shared lane ordering, predecessor proof, transaction-bound claim token, capacity
and CAS remain in the existing path. Neither opt_census.py nor
dl089_scheduling.py changed. The DL-089 1,085-cell plan before/after is identical:
`2026-09-09_window_sweep_verification.json` records both hashes. Focused tests:
71 passed, including temporary-DB 420 insertions then zero on repeat, setfile and
date/identity tampering, no selection from incomplete evidence, native identity
refusal, and existing dispatch/derived-lane regressions.

Production dry-run saw the required pending DL-089 frontier priority. Apply
refused before any insertion because all ten live worker processes predate the
adapter. They would execute old in-memory code and could use the legacy path.
`2026-09-09_window_sweep_apply_block.json` records PIDs and refusal. The canonical
start_terminal_workers.py `_stop_pid` explicitly fails closed until an
identity-bound stop exists. No daemon or backtest was interrupted.

Remaining executable sequence: operator performs identity-verified idle worker
rollout preserving machine environment; then run canonical window_sweep.py
`enqueue --stage A --apply` twice, verify 420 then 0, inspect first factory claim,
and `report` after the first native MEASURED result. The enqueue command checks
all discovered worker process start times against the adapter source mtime and
canonical command path. Missing/stale workers fail closed. No override is exposed.
Stage-B `plan` requires a complete matching Stage-A report; its production enqueue
and exit-axis reporting remain unimplemented pending separate adjudication.
No new pipeline verdict, strategy change, live action or main integration occurred.
