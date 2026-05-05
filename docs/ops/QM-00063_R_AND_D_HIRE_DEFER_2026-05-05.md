---
name: QM-00063 — CEO hire decision: R-and-D (Wave 5) — DEFER
description: CEO hire decision under DL-017. Defers R-and-D hire; Kanban claim "Wave 5 trigger fired" is incorrect — canonical Wave 5 trigger is pipeline throughput, not a spec-change proposal.
type: decision-memo
date: 2026-05-05
authority: DL-017 (broadened CEO hire authority)
kanban_task: QM-00063
referenced_decision_logs: 2026-04-27_v5_org_proposal.md (Wave 5 trigger)
---

# QM-00063 — CEO hire decision: R-and-D (Wave 5) — DEFER

## Disposition

**DEFER.** No hire today. Wave 5 trigger has not fired.

## Canonical Wave 5 trigger

From `decisions/2026-04-27_v5_org_proposal.md` § Wave 5:

> Trigger: Pipeline producing **≥10 PASS-eligible EAs/month**, demonstrating the throughput justifies dedicated R&D heartbeat cost. Until then CTO's "deep-research pre-check via Research" pattern (per `paperclip-prompts/cto.md`) covers the same surface.

Current state 2026-05-05: **0 PASS-eligible EAs** in the last 30 days. Phase 3 first card (QM5_1003) has not yet cleared P2 (gated on QUA-747 verification). 0/10 of the trigger threshold.

## Kanban note errata

The Kanban-CSV notes for QM-00063 contain three claims that are factually incorrect on inspection 2026-05-05 of `framework/scripts/`:

| Claim | Reality |
|---|---|
| "Missing P0/P1/P2/P3/P4 runners (only P3.5+ exist)" | `p2_baseline.py` shipped 2026-05-05 (commit `1dff5e0c` + `f448bbea` + `27b7b1c9`); `p2_matrix_launcher.py` covers matrix; P0=card-draft (no runner); P1=compile via `build_check.ps1` + `compile_one.ps1`. P3.5/P5/P5b/P5c/P6/P7/P8 all exist. |
| "No phase progression orchestrator" | `phase_orchestrator.py` exists; `pipeline_dispatcher.py` (commit `1dff5e0c`) is the orchestrator with DL-054 5-gate splice live. |
| "Missing data import for 21 symbols" | Orthogonal to R-and-D scope — that's a Pipeline-Op / DevOps concern (bar history compile per DL-054 D2 root cause, already fixed for 35/35 .DWX symbols). |
| "CTO is overloaded reviewing EAs" | CTO shipped 2 fixes today on QUA-747 critical-path within 21min (`f448bbea` primary, `27b7b1c9` secondary) plus DL-054 gate splice `1dff5e0c` earlier. DL-036 EA review queue is cycling normally (QM-00010, QM-00011, QM-00051 all completed today). Working at full capacity, not overloaded. |
| "DL-029 § Wave 5" attribution | DL-029 is the strategy-research workflow, not the wave plan. The Wave 5 trigger lives in `decisions/2026-04-27_v5_org_proposal.md` § 4 Wave plan / § Wave 5. |

The "spec change proposed" framing also misreads the trigger: Wave 5 is gated on **throughput proving the R&D heartbeat is justified**, not on the *existence* of a proposable spec change. CTO + Research's deep-research pre-check pattern explicitly covers spec-change *proposals* until throughput crosses the gate.

## Re-trigger condition

Hire becomes evaluable when **all three** are true:

1. ≥10 PASS-eligible EAs reach P8 PASS within a rolling 30-day window (canonical Wave 5 trigger).
2. CTO + Research deep-research pre-check pattern is observably bottlenecking (concrete examples: a backlog of unaddressed methodology proposals, OR a measurable re-invention rate akin to the V1 30% problem).
3. The proposed methodology change has clear external prior-art linkage (per the R-and-D prompt's mandatory prior-art check) — i.e., the work is genuinely novel pipeline methodology, not a refactor of existing scripts.

Condition #1 alone is necessary but not sufficient — passing 10 EAs/month with a healthy CTO + Research pre-check pipeline does not require R-and-D yet.

## What we're NOT precluding

- **Spec-change proposals via existing roles.** CTO can author pipeline methodology proposals (DL-NNN style) using deep-research pre-check via Research. Anything from "add PBO test" to "swap to a new walk-forward variant" is in CTO's lane today.
- **Sandbox prototypes via Development.** When Wave 2 Development hire is fully active, sandbox prototypes for proposed methodology changes can run there.
- **Future R-and-D hire when Wave 5 trigger fires.** The deferral here is *now-not-never*. Hire on legitimate trigger.

## Token-burn discipline

QUA-693 Class-2 escalation to OWNER is open at `critical` (1858% of placeholder cap). DL-056 CoS rolling rollup includes model-fit + token-burn columns. Adding agents on `codex_local` (R-and-D adapter per prompt) without justifying recurring deliverables compounds burn directly against the open escalation. The hire bar today is high.

## Authority

DL-017 broadened CEO hire authority (waiver v2). Decision recorded under DL-023 class 4 (internal process choices).

## Evidence trail

- Kanban CSV row QM-00063 marked `done` with this memo path as evidence.
- Canonical wave plan: `decisions/2026-04-27_v5_org_proposal.md` § 4 Wave 5.
- R-and-D prompt: `paperclip-prompts/r-and-d.md` (§ Status: V5 BASIS for Wave 5 hire (deferred until first pipeline-methodology change is proposed) — note the prompt itself uses a softer trigger framing; the canonical wave plan supersedes per its later date and explicit ratification).
- Pipeline scripts inventory at HEAD `agents/board-advisor` 2026-05-05: 12 phase scripts present.

## Note on prompt-vs-decision conflict

`paperclip-prompts/r-and-d.md` line 5 says "deferred until first pipeline-methodology change is proposed" — looser than the canonical wave plan ("≥10 PASS-eligible EAs/month"). This is a pre-existing inconsistency in the basis docs. Resolution: the wave plan supersedes (later, ratified, and authority-aligned with broader hiring policy). The R-and-D prompt should be patched to match — filed below as a Doc-KM follow-up that is **not** Phase-3 critical path, no immediate action.

## Next CEO action

None on this thread. Re-trigger watch is implicit in the Phase 4+ throughput surface and does not require a tracking issue.

Doc-KM follow-up (low priority, no immediate Kanban row): patch `paperclip-prompts/r-and-d.md` line 5 to align with `decisions/2026-04-27_v5_org_proposal.md` § Wave 5 throughput trigger when convenient.
