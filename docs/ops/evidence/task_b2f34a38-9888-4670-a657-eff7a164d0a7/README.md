# Task b2f34a38 — pulse false TECHNICAL_STALL (runnable count ignores data_2026 gate)

Generated: 2026-10-15T23:26Z (Claude orchestration cycle, worktree
`agents/claude-orchestration-2`, branch head `295924bca6`).

## Finding (as routed)

Since 2026-10-14 ~07:05Z the OWNER pulse (`tools/strategy_farm/ftmo_owner_status_pulse.py`)
has been reporting `FACTORY_STATE=EXECUTION_FAILURE` / `TECHNICAL_STALL` on a fleet that is
actually idle-but-correctly-held: the only "runnable" row is gated by `data_2026_skipped`
(the 2026 Track-A holdout gate) and/or `terminal_avoid_skipped`, and every pending
`research_*` row carries an active hold. Workers are behaving correctly; the pulse's
runnable/admissible accounting disagrees with the worker's own claim filter.

**Confirmed still live in production** at the time of this cycle — read live state at
`D:/QM/reports/state/ftmo_owner_status_pulse.json` (sha256
`4be469cfde1c2c81fc8dc17ce03cf7787d5c2702ba8ae6955ddd3b62ac83c414`, 99,698 bytes,
`at_utc=2026-10-15T23:05:02Z`, excerpted read-only into
`live_pulse_excerpt_2026-10-15T2305Z.json` in this directory):

```json
"classification": {"class": "TECHNICAL_STALL", "factory_state": "EXECUTION_FAILURE", ...},
"runnable_now": 1,
"worker_claim_skips": {"data_2026_skipped": 1, "longrun_cap_skipped": 4,
                        "q08_dsr_context_skipped": 5, "ram_class_skipped": 7},
"gate_breakdown": {"ram_class_skipped": 7, "longrun_cap_skipped": 4,
                    "q08_dsr_context_skipped": 5}
```

This is the exact defect signature: `worker_claim.skips` (the worker's own taxonomy) has
four keys including `data_2026_skipped: 1`, but `gate_breakdown` (what the pulse's
`runnable_now` classifier actually sums) is missing that key — so the pulse still counts
the one data_2026-gated row as "runnable" and raises `TECHNICAL_STALL` instead of
recognizing the queue as fully held.

## Root cause and fix (already implemented and verified elsewhere, unlanded)

A prior session fixed this exact defect and left full verification evidence, but on a
**different worktree** (`agents/claude-orchestration-1`), commit
`7f6ed4b2eae2ba308ab02b3e5b7c40db6a7b6dec`:

> `fix(pulse): runnable count uses full worker-claim gate set, add DRAINED_HELD class (task b2f34a38)`
>
> `build_snapshot()` computed `runnable_now` from a stale, hard-coded 4-key subset of the
> worker's skip taxonomy (one key, `commit_headroom_skipped`, was never even real), silently
> dropping `terminal_avoid_skipped`, `history_skipped`/`data_<year>_skipped` (the 2026
> Track-A holdout gate), `q08_dsr_context_skipped` and others... `gated_skip_total()` now
> sums every entry the worker claim path itself reports... `classify()` also gains a
> `DRAINED_HELD` class for "every claimable row gated, every AI lane idle"... Read-only on
> farm rows; no change to admission/claim logic. 46/46 pulse tests pass (5 new); live
> dry-run confirms the false TECHNICAL_STALL is gone.

That commit carries its own test (`pulse_tests_after.txt`: `46 passed in 0.70s`) and dry-run
evidence (`pulse_dryrun_after.txt`) committed alongside the code change at
`docs/ops/evidence/task_b2f34a38-9888-4670-a657-eff7a164d0a7/` on that commit — i.e. this
exact task was already worked, fixed, and tested once (`stale_releases` on the routed
payload confirms: previously assigned to claude, `previous_updated_at
2026-10-14T19:08:12Z`, released `age_expired` at `2026-10-15T01:12:46Z`, ~35 min after that
fix commit, then re-routed back to claude on this lane).

## Why this cannot be closed as a plain fix from this lane

1. **The target file does not exist on this lane at all.** `tools/strategy_farm/ftmo_owner_status_pulse.py`
   has no history on `agents/claude-orchestration-2` (`git log -- <path>` from `HEAD` is
   empty); this lane's branch point with `agents/claude-orchestration-1` is
   `1bea1f58b8f68f506c88cb9d0380d6b95bdd13f9`, and this lane simply never carried that file
   forward. There is nothing in this worktree to re-verify a fix against.
2. **Canonical (`agents/board-advisor`) does not have the fix either**, and its current
   version of the file has moved on since the fix's parent commit (new imports —
   `economic_progress`, `codex_budget_line`, `ftmo_goal_v3_contract`, `track_a_critical_path`
   — and a goal-v3.1 rework), so cherry-picking `7f6ed4b2eae2` there is not a clean
   fast-forward; it needs a real merge/rebase against the current file, not a bare
   `cherry-pick`.
3. **This session's standing orders forbid exactly that action**: "Do NOT cherry-pick,
   merge, commit, reset, or otherwise advance main or the `cto_main` worktree. Main
   integration is performed exclusively by Claude+OWNER close-outs." The same landing
   discipline applies to `agents/board-advisor` as the canonical integration lane.

This is the same landing-gate blocker class documented for task `af1e6342` in this cycle
(and in memory under `feedback_review_closure_lane_head_verification_2026-10-05`): the fix
is real, tested, and already evidenced — it is unlanded, not unfound.

## Verification performed this cycle (read-only)

- Confirmed `7f6ed4b2eae2ba308ab02b3e5b7c40db6a7b6dec` is reachable from this worktree
  (shared object store) and inspected its diff and commit message directly.
- Confirmed `git merge-base --is-ancestor 7f6ed4b2eae2... agents/board-advisor` is **false**
  (not landed on canonical).
- Confirmed `tools/strategy_farm/ftmo_owner_status_pulse.py` is absent from this lane's
  working tree and from this lane's commit history for that path.
- Confirmed via `git diff 7f6ed4b2eae2...^:<path> agents/board-advisor:<path>` that
  board-advisor's file has diverged structurally from the fix's parent, so a bare
  cherry-pick would need manual conflict resolution.
- Pulled a fresh, hashed, read-only excerpt of the live pulse state file (above) showing the
  exact bug signature (`gate_breakdown` missing `data_2026_skipped` that `worker_claim.skips`
  reports) is still active in production right now, ~29 h after the unlanded fix was
  written.
- No writes to farm rows, no changes to admission/claim logic, no edits to
  `C:/QM/repo` (canonical checkout).

## Recommended next step

Claude+OWNER close-out should land `7f6ed4b2eae2ba308ab02b3e5b7c40db6a7b6dec` (or a rebase
of its 26-line `ftmo_owner_status_pulse.py` diff + its new pulse test cases) onto
`agents/board-advisor` against the current (goal-v3.1-era) file, re-run the full pulse test
suite there, and re-confirm with a fresh dry-run that `gate_breakdown`/`runnable_now` now
matches `worker_claim.skips` and that an all-gated queue classifies as `DRAINED_HELD`. Until
that lands, every hourly pulse will keep raising a false `TECHNICAL_STALL`/
`EXECUTION_FAILURE` on a correctly-idle, correctly-held fleet.
