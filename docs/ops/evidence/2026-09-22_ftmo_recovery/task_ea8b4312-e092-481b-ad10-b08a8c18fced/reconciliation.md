# Task ea8b4312 — six-EA recovery reconciliation + Q01 dispatch infrastructure gap (2026-09-22)

Parent tasks: N-RECOVERY `cd3b761c-54d4-4b71-ba7e-f60018df57d3`, R-RECOVERY
`df1cae9b-76c7-4020-b732-9c2be501584d`. Recovery branch
`agents/codex-ftmo-recovery-20260922`, commit `87b5e693be` (README + six
authenticated compiles). This report re-derives current state from live
`agent_tasks` / `work_items` rows in `D:\QM\strategy_farm\state\farm_state.sqlite`
(read-only queries) rather than re-stating the commit's claims, per the
evidence-over-claims rule.

## 1. Build-task reconciliation (no duplicates created)

| Task ID | EA | State | Priority | Verdict on row (truncated) |
|---|---|---|---:|---|
| `d00d7571-74f4-45ea-b652-57fa439f7bd9` | QM5_9241 | TODO | 30 | Authenticated COMPILE_OK + build_check PASS; source review 52728403 APPROVED; resume this task for actual Q01 smoke |
| `751d8eb5-d9de-4cfe-85c6-27468c409078` | QM5_20078 (POC) | BLOCKED | 30 | Real COMPILE_OK 17501e85 + build_check PASS, 7 presets; awaiting independent implementation review bb697211 |
| `3c1da904-b03a-40d5-a1b3-c23e9ffad4b8` | QM5_36001 | TODO | 30 | Authenticated COMPILE_OK + build_check PASS; review 52728403 APPROVED |
| `019d50ff-a716-46a4-b097-c5c650dea63b` | QM5_36003 | TODO | 30 | Same |
| `22225e01-3ed6-4a1f-8fca-b55655117d01` | QM5_36004 | TODO | 30 | Same |
| `bab6e8bf-435d-4da2-a25f-1e651cb33960` | QM5_36008 | TODO | 30 | Same |

No new build_ea or Q02 `agent_tasks` rows were created this cycle. All six
`work_items` COMPILE_EA rows show terminal `done` / `COMPILE_OK` (9241:
`b3482782`, 20078: `17501e85`, 36001: `00c3153c`, 36003: `1c80b184`, 36004:
`467f5ea4`, 36008: `34293ad6`) — matching `compile_success_summary.json`'s "6
COMPILE_OK". None of the six has a `Q01`/`q01_smoke` work item yet.

**Dependency update since the recovery commit:** task `bb697211` (independent
QM5_20078 implementation review) is no longer IN_PROGRESS — it moved to
`REVIEW` at 2026-09-22T08:36:44Z with a verdict beginning "ACCEPTED: hard 2ATR
broker TP ... confirmed as the risk-safer, card-consistent reading". That
task is not `ea8b4312` and its assignee is `claude` at priority 79; closing it
is out of this cycle's exclusive-task scope (the launcher pins me to
`ea8b4312` only) and is left for the orchestrator's normal review-closure
loop. Once closed APPROVED, task `751d8eb5` can be un-blocked through the same
gap identified in §2 below — it needs a Q01 smoke row exactly as the other
five do.

**36008 Q02 preserved:** work item `18865d7c-baba-43d3-8327-2ffc2896a1f3`
(phase Q02, symbol XAUUSD.DWX) is still `pending` with no verdict — untouched,
per the recovery README's explicit instruction not to create a second canary.

## 2. Infrastructure gap: no general governed Q01 smoke dispatch route

Objective per this task's payload: "actual authenticated worker-bound Q01
smoke/current build artifacts ... Resident Custom-history policy blocks
direct run_smoke on T1-T10; use existing governed worker dispatch." I
searched `tools/strategy_farm/farmctl.py` and the whole `tools/strategy_farm`
tree for the mechanism that appends a governed `q01_smoke` work item (the
only kind the fail-closed admission check
(`_q01_smoke_admission`/`_authenticate_q01_smoke_successor`,
contract `qm.q01.worker_bound_basket_smoke.v1`) recognizes as a real smoke
PASS) for an arbitrary EA.

Finding: **no such general route exists.** The only code that appends a
pending `q01_smoke` work item is `tools/strategy_farm/q01_basket_smoke_recovery.py`,
and it is hard-scoped by a literal `TARGETS` tuple to three unrelated basket
EAs (`QM5_12512`, `QM5_10050`, `QM5_12507`) under router task `0666e8f0`, each
with its own fixed `review_task_id`, symbol and setfile name baked in. Per
this task's explicit instruction, I have not monkeypatched `TARGETS` or
reused that script's authority for the six FTMO EAs — doing so would borrow
an approval chain (`_review_is_approved` against those three review task IDs)
that was never evaluated against QM5_9241/20078/36001/36003/36004/36008.

`farmctl.py` exposes `record-q01-smoke-successor`, but it only *authenticates
an already-terminal* `q01_smoke` work item (`status=done`, `verdict=PASS`,
contract-matched, bound to the build task); it cannot create the pending row
that a T1-T10 worker would claim and execute. There is also a saturation
waiver path (`_q01_smoke_admission` / `Q01_SMOKE_CAPACITY_EVIDENCE_MARKERS`)
that lets Q02 admission proceed without a smoke PASS under durable fleet-
saturation evidence — I have not invoked it: no saturation evidence was
gathered this cycle and the task explicitly forbids fabricating
"capacity-waiver evidence."

**Net effect:** the five TODO builds (9241/36001/36003/36004/36008) and the
blocked POC (20078, once bb697211 closes) have no eligible path to an actual
worker-bound Q01 smoke row today other than a bespoke, per-EA script written
and independently reviewed the same way `q01_basket_smoke_recovery.py` was
for its three targets. That is a real, load-bearing gap, not a missing
convenience command — it blocks all six candidates identically regardless of
priority.

## 3. Priority reconciliation

The payload asks to prefer 9241/20078 (intraday speed hypotheses) over the
four D1 NNFX builds for marginal book contribution, "using authorized
management operations, not duplicate high-priority builds." I checked
`agent_router.py update-task` (state/artifact/verdict only, no priority flag)
and `farmctl.py mark-priority-track` (operates on `work_items.payload_json`,
GRÜN-zone queue-order marker — not applicable to `agent_tasks` rows, and none
of the six EAs has a queued `work_items` row yet to mark). No authorized
tool exists to reorder `agent_tasks.priority`; a raw SQL UPDATE against
`farm_state.sqlite` would be an unauthorized direct mutation outside governed
tooling, which I have not performed. Net observation: all five TODO builds
already sit at the same priority (30) — there is no existing mis-ordering to
correct with today's tooling; 9241 and 20078 are already flagged as the
preferred intraday hypotheses in their own task verdicts/payload text, which
is the extent of "preference" the current tooling can durably record without
a new authorized priority-write path.

## 4. Recommendation (not self-executed)

Commission a bounded, independently-reviewed `farmctl` subcommand (e.g.
`append-q01-smoke-work-item --ea-id <id> --build-task-id <id> --compile-evidence-path <hash-bound path>`)
that generalizes `q01_basket_smoke_recovery.py`'s pattern: verify an exact
COMPILE_OK compile_evidence hash, verify build-task binding, append exactly
one `q01_smoke` work item under the existing `qm.q01.worker_bound_basket_smoke.v1`
contract for the resident T1-T10 worker to claim — with no TARGETS
hard-coding and no reuse of the three basket review approvals. This is filed
as a follow-up `ops_issue` task rather than written ad hoc in this cycle,
because it changes governed dispatch surface and needs its own cross-vendor
review before any EA source/binary is touched by it.

## Economic status

Unchanged: zero admitted economic survivors among the six recovered
candidates. This task's scope was reconciliation and gap exposure, not a new
backtest result.
