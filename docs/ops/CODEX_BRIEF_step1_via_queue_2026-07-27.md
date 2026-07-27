# Codex brief — run multisym step 1 THROUGH the queue, plus two follow-ups

Date: 2026-07-27 (evening)
Priority: highest.

## Why the path changes

Four measurement attempts have now died the same way: an ad-hoc tester run on a
terminal that a persistent worker reclaimed mid-run (latest: 19% progress, then
"some error after pass finished", T2 reclaimed within ~3 minutes —
`2026-07-27_evidence_vintage_check.md:54-58`). Reservation blocks NEW claims but does
not stop a worker's already-claimed work or its respawn behaviour, and ad-hoc runs
have no owner to defend them.

The progress-aware reaper has now LANDED (commit 850784f97, task 371a7dc0 approved).
That removes the reason these runs were ever ad hoc: the 45-minute kill is gone, a
full 90-100 minute run survives in the governed queue, and inside the queue the
WORKER owns the terminal, so nothing reclaims it. **Run the measurement through the
queue like any other work item.** That is the fix for the recurring failure.

## Task 1 — step 1 of the multisym measurement, as governed work items

The repaired QM5_20181 (task eabfd168, approved: runner invariant, 10145 satellite
wired, comparator extended) and a same-vintage standalone 9936 need one run each,
full window, Model 4, USDJPY.DWX host, per the tester.ini template in
`2026-07-27_joint_backtest_run_results.md` §3.

1. Recompile BOTH in one session on the current tree (same include tree), record both
   SHA256. The pinned pair from earlier today may be stale after the repair - do not
   assume it.
2. Enqueue both runs as governed work items at high priority (the queue is ~2,800
   deep; these are two items and OWNER has prioritised the measurement all day).
   Use the ad-hoc/pipeline harness that already exists for this rather than inventing
   one - find how QM5_20180's sanctioned run was enqueued.
3. When both complete, diff three ways with the EXTENDED comparator:
   (a) joint-runner-only vs same-vintage standalone -> fidelity, gate 1.0;
   (b) standalone vs archived 9936_USDJPY_DWX.jsonl -> the vintage question;
   (c) joint vs archived.
   Report all three with the new mismatch categories.
4. Write docs/ops/evidence/2026-07-27_multisym_step1_EXECUTED.md - the doc three
   agents have now failed to produce.

## Task 2 — fix the reclassifier's log_bomb rule and restamp

The family diagnosis (2026-07-27_logbomb_family_diagnosis.md) proved the log_bomb
subclass is a false positive: 0 of 4,236 rows carry any genuine log-bomb artifact.
The reclassifier stamped log_bomb purely on attempt_count>=99, catching the
history-lock re-sync transport storm (terminal_worker.py:95-104) where the EA is
innocent. Fix the subclass rule to require an actual log-bomb artifact
(verdict_reason=LOG_BOMB, log_bomb_journal_gb, or LOG_BOMB in reason_classes), then
restamp the 4,236 rows with the corrected subclass (payload-only, snapshot for
revert, exactly like today's classifier runs). Also record QM5_10923 - the one
genuine latent per-tick emitter found, which holds real verdicts and therefore needs
a VARIANT, not an in-place edit - as a backlog note, not a fix here.

## Task 3 — age escalation, now safe to do

The reaper has landed, so the claim path is no longer contended. Implement the age
escalation per docs/ops/CODEX_BRIEF (the blocked workflow agent's spec, reproduced):
effective priority rises with age at claim time, computed from created_at, simple
inspectable form with a documented crossover, FAIL OPEN on malformed dates, no new
hot-path I/O, no DB mass-updates, extend chk_pending_tail_age for visibility, plus a
regression test. This is OWNER-decided; the earlier attempt was blocked only because
it would have collided with your reaper edit, which is now merged.

## Constraints

- Do NOT run Factory_OFF/Factory_ON; never T5, never T_Live; no .DWX re-imports.
- Serial builds; explicit pathspecs; NOT ESTABLISHED over inference.
- Tasks in this order: 1 enqueued first (runs take hours), then 2, then 3 while the
  runs execute.

## Deliverables

step1 EXECUTED doc, docs/ops/evidence/2026-07-27_logbomb_subclass_restamp.md,
docs/ops/evidence/2026-07-27_age_escalation.md.
