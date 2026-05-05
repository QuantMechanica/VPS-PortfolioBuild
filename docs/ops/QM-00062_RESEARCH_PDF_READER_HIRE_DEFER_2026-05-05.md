---
name: QM-00062 — CEO hire decision: Research-PDF-Reader sub-agent — DEFER
description: CEO hire decision under DL-017 broadened authority. Defers the Research-PDF-Reader sub-agent hire; defines re-trigger condition.
type: decision-memo
date: 2026-05-05
authority: DL-017 (broadened CEO hire authority) + DL-029 source-queue ordering (waiver v3)
kanban_task: QM-00062
referenced_decision_logs: DL-029, DL-057, DL-056
---

# QM-00062 — CEO hire decision: Research-PDF-Reader sub-agent — DEFER

## Disposition

**DEFER.** No hire today.

## Re-trigger condition

Hire becomes evaluable when **both** are true:

1. CEO opens a new `SRC0N` parent issue under V5 Strategy Research project (`b2adcc7f-...`) per DL-029 + waiver v3 source-queue authority — i.e., a new PDF source enters the queue, not a re-pass on an existing one.
2. Phase 3+ pipeline is downstream-clear enough that a new Card draft would be picked up by Quality-Business G0 within the same week (else the new card just queues in `cards/` with no consumer).

If both fire, re-evaluate via a fresh CEO Kanban hiring task (do not auto-hire on trigger; the act of opening the SRC0N is the cue, not the contract).

## Rationale

**Existing PDF queue is empty.** Sources SRC02 / SRC03 / SRC04 / SRC05 all have `extraction_pass_status` ∈ {complete, extraction_complete, first_pass_complete, closeout_pass_v1_complete} (verified 2026-05-05 via `strategy-seeds/sources/SRC0N/source.md`). 28 cards already drafted in `strategy-seeds/cards/`. No PDF text-extraction work is currently queued for Research.

**DL-029 caps research parallelism at 1 source × 1 strategy.** A dedicated PDF-reader sub-agent gives no throughput gain because the workflow itself only allows one source actively worked at a time. Sub-decomposition under that ceiling is premature.

**Research is paused per DL-057 R-057-1.** The auto-resume pulse fires when the baseline queue empties; right now Phase 3 is upstream-blocked on Pipeline-Op + CTO infra (QUA-747), not on Research. Adding a sub-agent to a paused chain is double-premature.

**Token-burn watch advises against latent agent slots.** QUA-693 Class-2 escalation to OWNER is open on token-burn cap (1858% of placeholder). DL-056 CoS rolling rollup includes model-fit + token-burn columns. Hiring with `enabled=false, wakeOnDemand=true` is *near-zero* ongoing cost but introduces config drift, prompt-maintenance overhead, and roster clutter that compounds over time. Optionality value alone does not clear the bar today.

**"Reports to Research-Lead" in the Kanban notes is incorrect.** Roster has no Research-Lead role; Research itself fills that line (`7aef7a17-...`). Sub-agent decomposition for Research has not been independently designed; doing it ad-hoc now would commit to a structure that may not fit Phase 4 portfolio research patterns.

## What we're NOT precluding

- Future hire of Research-PDF-Reader **with explicit decomposition design** (sub-agent contract, hand-off shape, evidence boundaries) when the trigger fires.
- Inline PDF reading by Research itself for the next 1-2 sources — that is the cheaper path until recurrence proves the case for split.
- Other Research sub-agents (e.g. backtest-evidence-curator, vocabulary-mapper) if a different bottleneck surfaces.

## Authority

DL-017 broadened CEO hire authority (waiver v2). Decision recorded under DL-023 class 4 (internal process choices).

## Evidence trail

- Kanban CSV row QM-00062 marked `done` with this memo path as evidence.
- Roster snapshot 2026-05-05: 10 agents, no Research-Lead role; Research = `7aef7a17-d010-4f6e-a198-4a8dc5deb40d`.
- Source queue snapshot: SRC02..SRC05 all extraction-complete; cards count 28 in `strategy-seeds/cards/`.

## Next CEO action

None on this thread. Re-trigger watch is implicit in the new-SRC0N-parent gate and does not require a tracking issue.
