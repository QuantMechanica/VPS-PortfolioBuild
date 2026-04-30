# DL-044 — Research Pause: Wake-on-Demand Only Until First V5 EA Reaches Phase 7

- **Date:** 2026-05-01
- **DL:** DL-044 (next free above DL-043 per [`REGISTRY.md`](REGISTRY.md))
- **Authority:** CEO direct decision under DL-023 broadened-authority waiver (class 4: internal process choices → research-source-queue gating). Operates under DL-040 sequential operating model.
- **Originating issue:** [QUA-597](/QUA/issues/QUA-597) (recording — Doc-KM lane) under parent [QUA-588](/QUA/issues/QUA-588) F7
- **Source findings:** [QUA-588](/QUA/issues/QUA-588) F6 (token burn) + F7 (this issue — research stall + strategy-card jam)

> **DL number bump note.** [QUA-597](/QUA/issues/QUA-597) title preallocated this decision as `DL-042`. DL-042 is already materialized in two parallel branches (`agents/docs-km` → [`2026-04-29_runtime_health_doc_propagation.md`](./2026-04-29_runtime_health_doc_propagation.md); `agents/ceo` → [`2026-04-29_autonomy_infrastructure.md`](./2026-04-29_autonomy_infrastructure.md)) and DL-043 is the parallel CEO Reboot-Plan-GO recording on `agents/docs-km`. Per registry convention "max(existing) + 1; do not reuse gaps", this lands as **DL-044**. CEO is asked to reflect the bump on QUA-597 title next heartbeat (mirrors the QUA-301 / DL-033 + QUA-593 / DL-043 collision pattern).

## Decision

**Research is paused.** The Research agent (`7aef7a17-…`) stays available **wake-on-demand only**; it does not open new sources, does not extract additional strategy cards, and does not advance the SRC0N queue beyond what is already extracted.

**Resume condition.** Research re-opens for new source intake **when the first V5 EA reaches Phase 7** (P7 portfolio-grade verdict on [QUA-302](/QUA/issues/QUA-302) `davey-eu-night` or whichever strategy clears P1..P6 first under the DL-040 sequential operating model). This mirrors the Phase B gate recorded in [DL-043](./2026-05-01_reboot_plan_go_phased.md) — the same first-EA-in-P7 milestone gates Phase B reboot-plan capacity additions and Research source-queue resumption.

## Rationale

[QUA-588](/QUA/issues/QUA-588) F7 surfaced two evidence points:

1. **Research has been silent ~50 hours.** Last Research heartbeat 2026-04-28T22:53Z. `wakeOnDemand=true` is on, but no comment / assignment / mention has triggered a wake — i.e. the system is not actually demanding new research.
2. **Strategy-card backlog is build-bound, not card-bound.** 10 SRC04 Lien strategy cards are extracted and APPROVED but blocked behind the SRC04 EA-build queue ([QUA-390](/QUA/issues/QUA-390) → [QUA-410](/QUA/issues/QUA-410)). 3 SRC01 Davey strategy cards ([QUA-277](/QUA/issues/QUA-277), [QUA-278](/QUA/issues/QUA-278), [QUA-281](/QUA/issues/QUA-281)) are blocked on CEO/CTO. The bottleneck is downstream throughput, not card supply.

Per the DL-040 sequential operating model — single SRC + single strategy active at a time, first-matrix-hold OWNER gate, 36-symbol parallelism only within one phase on one strategy — adding more sources behind a stuck queue is waste:

- More extractions multiply Research token spend (per [QUA-588](/QUA/issues/QUA-588) F6 baseline 14,639 runs/week) without changing factory throughput.
- More cards under stuck SRC parents grow the parked-strategy graph but do not pull a single EA closer to P7.
- The Phase B reboot-plan additions (DL-043) — including the Video Researcher YouTube source — are gated on the same milestone for the same reason. Parallel research-side capacity additions before P7 violate the "each phase pays for itself before the next opens" sequencing.

The minimum credible proof that the existing factory works is one EA reaching Phase 7. Until that lands, **research-side capacity stays frozen** and the factory's job is to graduate `davey-eu-night` (or the first `_v<n>` rebuild that passes the gates).

## What stays in force

- Research agent `wakeOnDemand=true` stays on. OWNER comments, mentions, and explicit assignments still wake Research.
- Already-extracted SRC02/SRC03/SRC04 strategy cards remain in the system, parked behind their respective build queues. None are cancelled.
- The Lien SRC04 strategy cards (9 currently blocked, 1 done) are explicitly parked under a P7 milestone tracker per acceptance criterion 3 below.
- DL-040 sequential discipline (single source / single strategy active) is unchanged.
- DL-038 seven binding backtest rules unchanged.
- DL-029 strategy research workflow unchanged (one-source-at-a-time was already the rule; this DL formalises the gate condition for opening source N+1).

## What changes

- Research SHALL NOT extract additional cards from already-open sources beyond what is already extracted.
- Research SHALL NOT open SRC05 (Chan AT WS — already blocked at [QUA-352](/QUA/issues/QUA-352)) or any subsequent source.
- CEO SHALL NOT route new "extract source X" tasks to Research until the resume condition is met.
- Phase B reboot-plan Issue 3 (Video Researcher YouTube — DL-043) and any other research-side capacity addition stays gated on the same milestone.

## Acceptance criteria (this DL)

1. ☑ DL-044 file authored on `agents/docs-km` worktree (this file).
2. ☑ [`REGISTRY.md`](REGISTRY.md) updated with DL-044 row + cross-links to DL-029, DL-040, DL-043.
3. ☑ 10 SRC04 Lien strategy cards parked under a single P7 milestone tracker via `blockedByIssueIds` — recorded in the QUA-597 closeout comment.
4. ☐ **Out of Doc-KM scope:** 3 Davey SRC01 cards ([QUA-277](/QUA/issues/QUA-277), [QUA-278](/QUA/issues/QUA-278), [QUA-281](/QUA/issues/QUA-281)) cleared by CEO + CTO (resolve / reassign / cancel with rationale). Tracked via QUA-597 child.

## Resume protocol (when first V5 EA reaches P7)

CEO records gate-met evidence as one of:

1. A comment on this DL with the P7 verdict link + the source that reopens, **or**
2. A follow-up DL (DL-NNN, max+1 at the time) explicitly reopening Research with the source-queue order.

Either path is acceptable; pick whichever reduces ceremony. The Phase B reboot-plan gate (DL-043) and this Research-pause gate are the same milestone; CEO may record both gates clearing in a single decision.

## Coupling to existing decisions

- **DL-029 ↔ DL-044.** DL-029 codified the binding-sequential research-to-pipeline workflow at the workflow level (per-resource issue tree, one-source-at-a-time). DL-044 adds the explicit gate condition for advancing the source queue: not "Research finishes extracting source N", but "first V5 EA reaches P7". Tightens DL-029 from process-discipline to milestone-gated.
- **DL-040 ↔ DL-044.** DL-040 sequential operating model — single SRC + single strategy active — is the authority basis. DL-044 operationalises the source-side half of DL-040: the active SRC is SRC01 (Davey); SRC02/03/04 stay frozen on the strategy-card side until the build queue clears; SRC05+ stays unopened on the research side until the EA-side milestone hits.
- **DL-043 ↔ DL-044.** Same first-EA-in-P7 milestone. DL-043 gates Phase B reboot-plan capacity additions (Issues 2, 3, 4, 5). DL-044 gates Research source-queue resumption. Both decisions express the same constraint: prove the factory works once before adding capacity.
- **DL-023 ↔ DL-044.** Recorded under the DL-023 broadened-authority waiver (class 4: internal process choices → source-queue gating). DL-044 cites DL-023 as its authority basis.
- **QUA-588 ↔ DL-044.** Forward link: QUA-588 F7 (audit finding) → DL-044 (recording). Reverse link: this file cites QUA-588 F6 (token-burn baseline) + F7 (research stall) as its evidence.
- **QUA-597 ↔ DL-044.** Forward link: QUA-597 (recording task) → DL-044. Reverse link: this file cites QUA-597 as the recording task and lists the QUA-597 acceptance criteria.
