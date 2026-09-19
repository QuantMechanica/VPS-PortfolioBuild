# Drain window: immediate abandon + need-band plateau memory + watch visibility (ticket c9cff1f2)

Task: `agent_tasks` id `c9cff1f2-7ca7-4fc0-aeed-a3405f3625ec` (source: fable-hourly-watch-2026-09-18).

## Incident

`QM5_20260` (24 GB class) armed a bounded drain 2026-09-18 09:05:58Z
(`D:/QM/strategy_farm/state/drain_window.json` entry `e2622f78`) beside an
already-running Q03 long run (12.6 GB). Need = 24 + `DRAIN_ARMED_ROW_FLOOR_GB`(4)
+ `DRAIN_WINNABLE_MARGIN_GB`(3) = 31 GB; free RAM was 28 GB and
`releasable_short_ram_gb` was 0 (no active short row could ever finish and
free RAM while the drain refused new short claims). The drain nonetheless held
for the full `DRAIN_WINDOW_MAX_MIN` (30 min) window, blocking 38 short rows
(`T2`/`T7` worker logs, `drain_window_skipped` 09:21Z) while 83 other rows sat
unblocked, idling the fleet for roughly two hours before the window expired
naturally.

## Root causes fixed (claim-selection only, no verdict logic)

`tools/strategy_farm/terminal_worker.py`:

1. **New explicit `no_releasable_ram` reason** in `_drain_candidate_is_winnable`:
   when `releasable_short_ram_gb <= 0` and `free < need`, the candidate is
   refused before the generic `insufficient_releasable_ram` check. This case is
   structurally different from a transient measurement dip: with nothing
   running that could ever finish and free RAM while the drain blocks new
   short claims, waiting inside the bounded window cannot help.
2. **Immediate abandon for that reason** in `_drain_run_postprocess`'s
   continuous-reeval branch: `no_releasable_ram` bypasses
   `DRAIN_REEVAL_GRACE_SECONDS` entirely and abandons on the very first
   postprocess pass after the drain goes unwinnable this way (previously every
   not-winnable reason shared the same 120 s dip-tolerance grace, introduced
   2026-09-04 for a *different*, genuinely transient case). Reasons where
   `releasable_short_ram_gb > 0` (a real, if insufficient, releasable pool)
   keep the existing grace-based tolerance unchanged.
3. **Plateau memory re-keyed by observed capacity, not the original need**:
   `plateau_memory` now blocks a new arm attempt whenever the candidate's need
   exceeds the previously observed `free_gb + releasable_short_ram_gb`
   ceiling, instead of only refusing candidates whose need was `>=` the
   original blocked row's `need_gb`. A 51 GB memory (e.g. a 44 GB class row)
   that plateaued at a 31 GB ceiling now also refuses a lighter 24 GB-class
   candidate (need 31) at that same ceiling; a candidate whose need genuinely
   fits under the observed ceiling is still let through.

`tools/strategy_farm/session_tools/hourly_watch_0909.py`:

4. **New `drain_unwinnable_alert`**, wired into `main()` alongside the
   existing `census_stall_alert`. The pre-existing check only reads
   `pre_drain`/`tracker`, both of which are empty once an ordinary bounded
   drain has armed (`tracker` is consumed at open; a non-exclusive arm never
   sets `pre_drain`) — so the watch stayed silent for the entire incident. The
   new check reads `active.not_winnable_since_epoch` /
   `not_winnable_reason` (written by the continuous reeval) and emits a
   distinct `DRAIN_UNWINNABLE` alert naming the row, reservation, reason and
   idle-terminal count, so an armed-and-stuck drain is never indistinguishable
   from a healthy `OK`.

## Verification

```
cd C:/QM/repo/tools/strategy_farm
python -m pytest tests/test_terminal_worker_drain_window.py \
  tests/test_terminal_worker_drain_exclusive_lane.py \
  tests/test_hourly_watch_census_stall.py -q
# 97 passed, 1 pre-existing unrelated failure
```

The one failure, `test_terminal_worker_drain_exclusive_lane.py::
test_lighter_index_rows_are_not_exclusive`, reproduces identically on the
unmodified `terminal_worker.py` (verified by stashing this diff and
re-running) — a stale NDX RAM-reservation-table assumption unrelated to the
drain window, out of scope for this ticket.

Three pre-existing tests
(`test_postprocess_not_armed_beside_long_runs_when_arithmetic_short`,
`test_postprocess_not_armed_when_releasable_ram_insufficient`,
`test_postprocess_does_not_abandon_on_preexisting_long_run`) asserted a
generic `insufficient_releasable_ram` reason / open-drain outcome for
fixtures whose synthetic worker PIDs were never backed by a mocked process
snapshot, so `_drain_active_ram_facts` always measured
`releasable_short_ram_gb=0` for them regardless of the "N testers release X GB"
comments — a latent test gap that only became externally visible once
`no_releasable_ram` was split out as its own reason. Updated the first two to
mock `_process_private_snapshot` (matching the `_q_rows_snapshot` helper
already used elsewhere in the file) so they exercise genuine partial-but-
insufficient releasable RAM as their comments describe; updated the third to
add real releasable RAM so it isolates its original "pre-existing vs new long
run" concern from the new immediate-abandon path. Added
`test_postprocess_abandons_immediately_when_nothing_releasable` to cover the
exact incident shape (armed row + pre-existing long run + zero releasable
$\Rightarrow$ single-pass abandon), plus direct predicate tests for the new
`no_releasable_ram` reason and the capacity-keyed plateau memory, and watch
tests for `drain_unwinnable_alert` (fires on an active unwinnable drain;
silent when under-idle, unmarked, or no active drain) confirming
`census_stall_alert` stays silent for the same window (the gap being closed).

No reservation constant, RAM latch, census floor, tester ledger, or pipeline
verdict logic was touched — this is claim-selection/coordination and
read-only ops-watch code only.

## Risk / blockers

None identified; changes are additive/behavior-narrowing (a strict subset of
previously-open drains now closes sooner) and fully covered by tests. Left in
REVIEW per standing instruction (Codex review mandatory before PIPELINE/
APPROVED; Claude does not self-approve).
