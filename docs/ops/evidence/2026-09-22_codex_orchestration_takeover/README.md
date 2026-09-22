# Codex orchestration handover — 2026-09-22

Authority: [OWNER handover](../../../../decisions/2026-09-22_owner_codex_orchestration_takeover.md).
OWNER asked Codex to take over from Fable at a reported 90% weekly usage.

## Verified changes

- New autonomous Claude work is paused with an externally owned
  `D:/QM/strategy_farm/CLAUDE_DISABLED.flag`. The quota governor respects it.
  The local 65% telemetry disagrees with OWNER's newer figure; OWNER's pause wins.
  Existing interactive sessions were not killed. Review after Friday's reset;
  resumption is not automatic.
- The previously authorized Codex burn window is refreshed **through
  2026-09-22 23:59:59 Europe/Berlin only**. Hard provider limits remain in force.
- Existing build tasks `67c45a2f` (41486) and `6ae8518a` (41487) were transferred
  from Claude to Codex in place, with original scope, priority and defect verdict
  retained. `codex_handoff_0922.py` first checked exact IDs, TODO state and old
  ownership, then wrote through the canonical router in one transaction.
- The existing 15-minute critic task now uses
  `tools/strategy_farm/config/agent_chain.codex_handoff_20260922.v1.json`.
  It adds Antigravity as a cross-vendor critic of Codex and a formatting fallback.
  All existing gates remain unchanged. The Codex orchestrator must verify cited
  evidence; a critic PASS alone is not permission to change strategy verdicts.
- Three duplicate EDGE-2/4/5 tickets were administratively closed. Their original
  Gemini tasks were already PASSED with artifacts on September 15. No measurement
  or economic verdict was changed. One preselected launcher slot subsequently saw
  the terminal task state and exited without repeating the work.

## Startup incident and recovery

At 09:48–09:50Z the router showed five assigned tasks but no corresponding Codex
executor processes. The scheduled controller was repeatedly trying to create
working copies on C:, with only **0.9 GiB free**. Assignment was not execution.

The existing Codex scheduled task was temporarily stopped/disabled. Its identified
worktree-creation child processes were stopped; both interactive Codex sessions,
the terminal workers, T_Live and FTMO were untouched. After proving controller
PID 20212 dead, its exact owner-token-bound lease was released through the existing
runner API, not by bulk lease deletion.

The task now invokes `session_tools/run_codex_handoff_0922.ps1`, which sets the
runner's already supported `QM_AGENT_WORKTREE_ROOT=D:/QM/agent_worktrees` and runs
the existing governed controller. It is enabled again and created slots 8/9/10.
**Three actual Codex executor processes and fresh logs were observed from 09:57:55Z.**
The controller drains further eligible tasks after a session finishes.

The completed old C: slot 7 (session finished 09:23:55Z) was relocated to
`D:/QM/archived_worktrees/codex-orchestration-7-20260922`. The cross-volume move
stopped on directory links; the remaining files were copied with Robocopy
`/SJ /SL`, zero failed files. The remaining source directory is preserved at
`C:/QM/worktrees/codex-orchestration-7-move-residual-20260922`.
The original slot-7 path is now a junction to the preserved full working copy,
so historical evidence references and its Git pointer keep working.
C: recovered to approximately **3.0 GiB free**, D: approximately **78 GiB free**.
This resolves the immediate startup failure; it is not a claim of ample C: space.
Post-copy inventory matched exactly: 63,754 files and 2,232,736,392 bytes,
excluding directory links in both counts. The residual directory is retained.

## Actual Factory state and remaining work

- Ten terminal workers were alive, with no duplicate worker or orphan test terminal
  found. The apparent queue of 3,835 rows was not 3,835 runnable jobs.
  At idle, the claim logs reached only two unheld QM5_11305 index Q04 candidates;
  each required 44 GiB reservation plus 14 GiB headroom, versus about 39 GiB free.
  These resource checks were not relaxed. Most other pending entries have explicit
  holds or additional admission dependencies.
- At 09:59:59Z the DB showed one real active test: QM5_41488/XTIUSD Q10_NEWS on T2;
  3,834 pending, 99,922 done, 49,462 failed historical work items.
- Six recovered Break & Retest / NNFX builds remain compiled. Their actual Q01
  dispatch/admission repair **32d39ccd** now has an executing Codex worker.
  They are **not all tested or admitted**. The original six build task IDs and
  existing QM5_36008 Q02 row remain authoritative.
- KS re-entry **fa75b45e** also has an executing worker. The FTMO trial monitor's
  ALARM remains meaningful: the running book does not yet expose the expected
  Prague/day-anchor/book-tag telemetry contract. This handover did not deploy
  replacements or alter the live book.
- New intake parent **c90f7bf8** reached REVIEW with 26 child tasks; a real
  Antigravity cross-vendor critique started at 09:56:20Z and completed PASS,
  including the formatting stage. The Codex orchestrator independently checked
  52 published file hashes, all 26 child IDs/types/parent links, and the unchanged
  reviewed README text (CRLF/LF byte difference recorded explicitly), then closed
  the intake parent APPROVED. This approves queue coverage only; it grants no G0,
  build, test, or economic approval. Receipt: `intake_independent_review_adjudication.json`.
- Existing health warnings and the review backlog remain visible. No blanket
  all-green assessment, strategy success or 80% payout probability is claimed.

Follow-through is commissioned as **4878dbfd-dc46-44f5-a6a3-6dd3c38557a5**, priority 87,
Codex: verify current execution, coordinate independent review of the Q01 repair,
continue the original six tasks after real smoke evidence, and preserve the pause.
It must not duplicate an active creator or approve its own code.

## Evidence and rollback

- `runtime_after_handoff.json`: real queue/tasks/exec leases and flag contents.
- `build_task_transfer_{dry_run,applied}.json`: exact before rows and transfer receipts.
- `completed_research_duplicate_disposition.json`: original PASSED rows and artifact hashes.
- `critic_scheduler_handoff.json`, `critic_task_before.xml`: action before/after.
- `codex_task_before_root_change.xml`: original Codex action (captured while disabled).
- `codex_spawn_loop_before_stop.json`, `stopped_controller_lease_before.json`: incident ownership.
- `worktree7_relocation.json`: preserved location and junction; no evidence deletion.
- `followthrough_task.json`: durable next owner and acceptance criteria.

Rollback of the task actions is possible from the saved XML/action fields, but
**do not restore C: worktree creation before checking capacity**. At Claude reset
review, remove only this handover-owned pause flag if resumption is chosen and
restore the default critic config argument. Do not remove unrelated provider flags.
