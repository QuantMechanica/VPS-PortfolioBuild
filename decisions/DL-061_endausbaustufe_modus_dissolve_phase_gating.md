---
name: DL-061 — Endausbaustufe-Modus, dissolve company-level Phase 1/2/3/4/5/6/Final gating
description: OWNER 2026-05-09 directive. The company-level phase model was a conceptual error. Dissolve the Phase Map. The company is in Endausbaustufe-Modus — fully-built operating shape, all workstreams continuous and parallel, no inter-workstream gating. Only the EA-level G0..P10 sub-gate spec survives as a phase sequence (per-card, not per-company). Reframe PHASE_STATE.md, QUA-889/1067/884/1083, and CEO heartbeat policy.
type: decision-log
authority: OWNER directive 2026-05-09 (Paperclip QUA-1085 issue body, German verbatim) — charter-level operating-mode change, ratifies CEO unilateral execution under DL-017 + DL-023 + DL-053.
date: 2026-05-09
supersedes: portion of DL-053 R-053-1 ("phase-driven heartbeat — pick smallest deliverable that advances the phase by one step") — the phase-driven framing is replaced with workstream-driven framing. DL-053's other clauses (R-053-2 .. R-053-6: blocker decomposition, named-role delegation with file-path acceptance + UTC deadline, investigate-before-park, unblock-not-defer, escalate-only-when-chain-exhausted) survive unchanged. The phase Map in `paperclip/governance/PHASE_STATE.md` (rows 0..Final) is replaced with a Workstream Catalog (W1..W9). Foundational phase closures (former Phase 0/1/2) remain CLOSED — they are now baseline infra, not retired-from-gating gates.
related: DL-017 (CEO hire-approval waiver), DL-023 (CEO autonomy waiver v2), DL-024 (heartbeat enabled — predates Endausbaustufe but still binding for cadence), DL-053 (CEO operating contract — partially superseded), DL-026 (commit-hash close-out rule), DL-029 (Strategy Research workflow — still binding per-card), DL-033 (no strategy-level prioritization — still binding), DL-038 (seven binding backtest rules — still binding), DL-046 (anti-theater meta-work purge), DL-054 (anti-theater PASS criteria), QUA-1085 (this rewrite issue), QUA-889 (public dashboard — reframed W4), QUA-1067 (P3 candidate queue — reframed W2 feed), QUA-884 (Mail-Agent MC0 — reframed W8 OWNER-gated), QUA-1083 (multi-EA scheduler — reframed W6 always-on infra), QUA-1062 (Phase 4 plan — superseded; the demo sequence inside it remains a useful proposal but is no longer "Phase 4 closure work").
---

## The directive (verbatim from OWNER, QUA-1085 body)

> "OWNER 2026-05-09 directive: company-level Phase 1/2/3/4/5/6/Final ist Konstrukt-Fehler. Aufloesen. Endausbaustufe-Modus = alle Workstreams continuous parallel. EA-level G0..P10 bleibt. Reframe PHASE_STATE.md, QUA-889/1067/884/1083, backlog re-prio."

Translation:

> "Company-level Phase 1/2/3/4/5/6/Final is a conceptual error. Dissolve. Endausbaustufe-Modus (end-build mode) = all workstreams continuous and parallel. The EA-level G0..P10 sequence remains. Reframe PHASE_STATE.md, QUA-889/1067/884/1083, backlog re-prio."

## The decision (binding for all agents)

**Effective 2026-05-09, the company operates in Endausbaustufe-Modus.**

1. **Company-level phase model dissolved.** No agent declares a "phase complete" or "next phase" or schedules work as "Phase N prep". Phase 1/2/3/4/5/6/Final and any equivalent labels (Phase 4 prep, Phase 5 readiness, Phase 6 enablement, Phase Final / Founder-Comms milestone) are retired from gating semantics. The semantics are not deleted from history — prior DLs, PHASE_STATE entries, issue titles, and commit messages keep the words as-written for audit fidelity — but no new artifact is built around the model.

2. **Continuous parallel workstreams.** The company is now operationally a set of 9 (initially) always-on workstreams that share resources but do not gate each other:

   - **W1** EA Pipeline (G0..P10 per card)
   - **W2** Strategy Research (Source extraction → Strategy Cards → G0)
   - **W3** Live-Sim / T6 Live Promotion (P9b/P10 then T6 deploy)
   - **W4** Public Dashboard (quantmechanica.com)
   - **W5** Token-Burn Governance (Subscription-Guardian)
   - **W6** Cross-Terminal Scheduler (multi-EA MT5 saturation infra)
   - **W7** Pipeline Hardening (DL-054 gates, .hcc audit, dispatch dedup)
   - **W8** Founder-Comms / Mail-Agent (OWNER-gated)
   - **W9** Org Operations (CoS rollups, hires, governance hygiene)

   The catalog is canonical in `paperclip/governance/PHASE_STATE.md` § Workstream Catalog and may grow (e.g. W10 Brand, W11 Compliance) as new always-on capabilities materialize. New workstreams are added by CEO with a one-line entry in the catalog; no separate DL needed.

3. **The EA-level G0..P10 sub-gate spec survives unchanged** (`docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md`). Each EA card still walks G0 → P0 → P1 → P2 → P3 → … → P10 sequentially. This is a per-card phase sequence, not a company phase sequence. It remains the unit of pipeline progress.

4. **Resource arbitration replaces phase gating.** Three shared resources arbitrate workstream tempo:
   - **Token-burn budget** (W5 owns the meter; CEO + CoS arbitrate when `>80%` of monthly cap → Class-2 escalation per DL-055).
   - **5 MT5 terminals T1..T5** (W6 owns saturation; W1 + W7 are the consumers).
   - **Agent-assignee capacity** (CEO + CoS arbitrate via Kanban CSV / Paperclip queue + DL-060 task surface).

   No workstream blocks another by design. If two workstreams contend for the same resource, the one with the higher heartbeat-attention-weight (default: W1 until first end-to-end card lands, then rotates) wins.

5. **OWNER-gated items are not "phases".** Founder-Comms (W8) and T6 first-AutoTrading-toggle (W3) require explicit OWNER unlock signals, not phase progression. They live in the workstream catalog as "OWNER-gated, deferred" rows. CEO may not pull them forward; CEO must surface them when the unlock conditions are met.

6. **CEO heartbeat policy update.** DL-053 R-053-1 ("pick smallest deliverable that advances the phase by one step") is replaced with: **"Pick the smallest deliverable that advances the highest-attention-weight workstream by one step."** Default attention = W1 (EA pipeline) until first end-to-end card lands; thereafter rotates by resource contention and ETA pressure.

7. **Reframe of named issues:**
   - **QUA-889** (public dashboard build, "Phase 6 parallel-eligible" framing) → reframed as W4 row. Continues in flight.
   - **QUA-1067** (Phase 4 prep Lane B — P3 candidate queue) → close `done`. Deliverable shipped at commit `d3a7c80a` (`tools/ops/p3_next_candidates_queue.json`); reframed as continuous W2 feed (forward-eligibility queue), not "Phase 4 prep".
   - **QUA-884** (Mail-Agent MC0 capability spec) → stays deferred. Reframed as W8 OWNER-gated workstream item, not "Final phase milestone". 6 preconditions per `docs/ops/PHASE_FINAL_FOUNDER_COMMS.md` still binding for OWNER unlock.
   - **QUA-1083** (Multi-EA Cross-Terminal Scheduler, "Phase 4 prerequisite" framing) → reframed as W6 always-on infra. Spec drafted (`docs/ops/QUA-1083_MULTI_EA_CROSS_TERMINAL_SCHEDULER_PHASE4_SPEC_2026-05-09.md`); implementation continues without phase gating.
   - **QUA-1062** (Phase 4 plan, in_review for OWNER acceptance) → not in OWNER's named-issue list, but inherits the same reframe by adjacency. The demo sequence proposal (D0..D3 24h/72h/7d/7d) inside QUA-1062 is a useful resource-contention plan for W1+W3 saturation, but it is no longer "Phase 4 closure work". CEO will note this in a follow-up comment on QUA-1062 without re-opening it.

8. **Backlog re-prioritization.** The Kanban CSV `phase` column already uses EA-level (G0, P0..P10) plus process tags (ops, MC0..2 for founder-comms, closeout). No mass column rewrite is required. CEO will:
   - Tag MC0/MC1/MC2 rows with "OWNER-gated W8" note in their `notes` column at next CSV touch.
   - Continue using the column as-is (it already reflects the EA-level model + process tags, never carried Phase 1..Final values).
   - Reject any future PR that reintroduces "Phase N" semantics into kanban or new artifacts.

## Why this and not the alternative

OWNER framed this as a *conceptual* error, not a tactical one. The phase model imposed an artificial sequence — Phase 4 cannot start until Phase 3 closes; Phase 6 is "parallel-eligible from Phase 3 onward" — that mapped poorly onto reality:

- **Reality on the ground**: every observation in the PHASE_STATE audit log shows workstreams already running in parallel. Public Dashboard work (W4) ran during Phase 3; Token-Burn governance (W5) ran during Phase 3; Strategy Research (W2) ran throughout; Pipeline Hardening (W7) was the dominant heartbeat consumer for 4+ days. The phase model was being routinely violated by the company's actual operating shape.
- **Phase closure became a forcing function for theater**: the audit log shows multiple cycles where CEO declared "Phase 3 closure ETA" only to slip — because there is no single deliverable that closes Phase 3, just continuous workstream advancement. The "first V5 EA through pipeline" closure criterion was repeatedly redefined (ETA 2026-05-05 → 2026-05-06 → 2026-05-07 → 2026-05-13..15) as evidence shifted.
- **Cross-workstream gating was always wrong**: there is no operational reason W4 (dashboard) should wait for W1 (EA pipeline) to close, no reason W6 (scheduler) should wait for "Phase 4 prep", no reason W8 (founder-comms) is structurally "after" anything other than its 6 OWNER preconditions.
- **The EA-level G0..P10 sequence is *real***: each card actually does need G0 review before P0 dispatch, P0 before P1, etc. — because evidence accumulates per card. That's the only sequence where "phase" maps to a binding gate.
- **Endausbaustufe is also a strategic statement**: the company is no longer in build-out mode. Hires are done (Wave 0 complete; Wave 1 minus a few). Framework is shipped. Toolchain works end-to-end. What remains is steady-state operation of workstreams, plus EA throughput per W1.

The alternative — keeping the phase model and just patching the coupling — was rejected because OWNER named it a *Konstrukt-Fehler* (construct error), not a tuning problem. Patching would re-create the same violations next month.

## What survives unchanged

- **EA-level G0..P10** (PIPELINE_V5_SUB_GATE_SPEC) — still the canonical per-card progression.
- **DL-053 clauses R-053-2 through R-053-6** — blocker decomposition, named-role delegation with file-path acceptance + UTC deadline, investigate-before-park, unblock-not-defer, escalate-only-when-chain-exhausted.
- **DL-029 Strategy Research workflow** — Source → Strategy Card → G0 review → ea_id alloc → Development → CTO Review (DL-036) → Pipeline-Op P0..P10. Per-card, still binding.
- **DL-030 Execution Policies** — Class-1 (T6 OWNER-approval), Class-2 (Strategy Card review), Class-3 (`_v[0-9]+` EA review), Class-4 (default).
- **DL-031 Issue Routing** — projectId required at creation; 4 V5 projects unchanged.
- **DL-038 Seven Binding Backtest Rules** — `.DWX`-only, 36-symbol matrix per phase, T1..T5 parallel discipline, etc.
- **DL-054 Anti-Theater PASS Criteria** — five binding gates G1..G5 per `(ea_id, phase, symbol)` run. Still binding.
- **DL-060 Paperclip canonical task queue** — Paperclip API is the canonical task queue; CSV deprecated as task source.
- **All foundational closures** — V5 Framework (former Phase 2) closed 2026-05-01, Paperclip Bootstrap (former Phase 1) closed 2026-04-27, Foundation (former Phase 0) baseline. These remain CLOSED; they are just no longer framed as gates.
- **Audit history in PHASE_STATE.md** — preserved verbatim. Doc-KM owns retention; CEO does not rewrite past entries.
- **DL-057 Research resume gate** — Research is paused when W1 has work, resumes on baseline-queue-empty event. The pause/resume condition is per-resource-contention (W1 demand), not per-phase.

## What this changes operationally

- **CEO heartbeat top-of-loop**: read PHASE_STATE.md → confirm Operating mode = Endausbaustufe → identify highest-attention-weight workstream → pick smallest deliverable for it → delegate via Kanban + Paperclip → close current task. No "what closes the current phase?" question.
- **Issue creation**: new issues do not carry "Phase N" titles. Use workstream tags (W1..W9) where helpful, EA card ids (`QM5_NNNN`) for W1 work, project ids (per DL-031) for routing.
- **Status reporting**: dashboards (`dashboards/current.md`, `current.html`) drop the "Current Phase" header; replace with "Operating Mode: Endausbaustufe" + per-workstream live state. Doc-KM tracks this as a follow-up under W7-equivalent process hygiene.
- **OWNER asks**: when CEO surfaces an item to OWNER, the framing is "this workstream needs unlock signal X" not "Phase N is blocked on you". Founder-Comms preconditions stay verbatim; T6 first-toggle stays verbatim.
- **Pre-flight rule for prompt patches**: agent prompts (`paperclip-prompts/*.md`) that reference "Phase N" semantics get a pre-flight check on next touch — replace phase framing with workstream framing where load-bearing, leave verbatim where purely historical (e.g., "Phase 1 closeout").

## What CEO did this heartbeat to materialize the dissolution

1. Rewrote `paperclip/governance/PHASE_STATE.md` head section: Operating mode banner, Workstream Catalog replacing Phase Map, audit history preserved.
2. Filed this DL (`decisions/DL-061_endausbaustufe_modus_dissolve_phase_gating.md`).
3. Reframed the four named issues per § 7.
4. Closed QUA-1085 done with full evidence chain (commit hash + DL link + reframe summary) per DL-026.
5. Did NOT rewrite past PHASE_STATE entries (audit fidelity).
6. Did NOT mass-rewrite kanban CSV `phase` column (already EA-level + process tags; no Phase 1..Final values present).
7. Did NOT update `processes/20-phase-state-maintenance.md` in this heartbeat — Doc-KM-owned, surfaced to Doc-KM via QUA-1085 close-out comment for follow-up.
8. Did NOT update `dashboards/current.md` / `current.html` in this heartbeat — DevOps + Doc-KM-owned, surfaced for follow-up.

REGISTRY entry added in same commit.
