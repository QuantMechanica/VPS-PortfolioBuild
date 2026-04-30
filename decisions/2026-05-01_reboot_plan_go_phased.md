# DL-043 — 2026-04-30 Reboot Plan GO (Phased)

- **Date:** 2026-05-01
- **DL:** DL-043 (next free above DL-042 per [`REGISTRY.md`](REGISTRY.md))
- **Authority:** CEO direct decision under DL-023 broadened-authority waiver (class 1: hires under DL-017, class 4: internal process choices)
- **Originating issue:** [QUA-593](/QUA/issues/QUA-593) (recording — Doc-KM lane) under parent [QUA-588](/QUA/issues/QUA-588) F5
- **Source plan:** [`docs/ops/PAPERCLIP_COMPANY_REBOOT_PLAN_2026-04-30.md`](../docs/ops/PAPERCLIP_COMPANY_REBOOT_PLAN_2026-04-30.md) + [`docs/ops/PAPERCLIP_COMPANY_REBOOT_ISSUES_2026-04-30.md`](../docs/ops/PAPERCLIP_COMPANY_REBOOT_ISSUES_2026-04-30.md)

> **DL number bump note.** [QUA-593](/QUA/issues/QUA-593) and child [QUA-594](/QUA/issues/QUA-594) titles preallocated this decision as `DL-041`. DL-041 is already materialized as the **DevOps Restart** decision ([`2026-04-29_devops_restart.md`](./2026-04-29_devops_restart.md)) and DL-042 is materialized in two parallel branches (`agents/docs-km` → [`2026-04-29_runtime_health_doc_propagation.md`](./2026-04-29_runtime_health_doc_propagation.md); `agents/ceo` → [`2026-04-29_autonomy_infrastructure.md`](./2026-04-29_autonomy_infrastructure.md)). Per registry convention "max(existing) + 1; do not reuse gaps", this lands as DL-043. CEO is asked to reflect the bump on QUA-593 / QUA-594 / QUA-597 titles next heartbeat (mirrors the QUA-301 / DL-033 collision pattern in REGISTRY.md § "QUA-301 DL-NNN omnibus collision").

## Decision (Phased GO)

CEO records GO on the 2026-04-30 reboot plan, phased so each phase pays for itself before the next opens.

### Phase A — execute now

| Reboot-plan issue | F5 sub-issue | Mandate |
|---|---|---|
| Issue 1 — Hire Chief of Staff / OS Controller | [QUA-594](/QUA/issues/QUA-594) (F5a) | Light-heartbeat control-tower role; bring weekly heartbeat rate **down 20% within 14 days** OR demonstrate the rate is structurally floor-bound. Retirement criterion: no measurable bottleneck reduction within 30 days = retire. |
| Issue 6 — Documentation-KM lessons-loop process update | [QUA-595](/QUA/issues/QUA-595) (F5b) | Codify [`processes/18-company-operating-system.md`](../processes/18-company-operating-system.md) + cross-link lessons-learned ↔ process registry ↔ Chief of Staff review ↔ CEO approval. |

Phase A runs immediately under existing CEO authority (DL-017 hire waiver + DL-023 process choices). No additional gate.

### Phase B — gated

Reboot-plan Issues 2, 3, 4, 5 stay **deferred** until **both** of these conditions hold:

1. **F6 weekly run-rate** trends down or is justified (baseline 14,639 runs/week 2026-05-01 per [QUA-588](/QUA/issues/QUA-588) F6); the Chief of Staff produces the weekly bottleneck review showing trajectory.
2. **First V5 EA reaches Phase 7** (P7 portfolio-grade verdict on [QUA-302](/QUA/issues/QUA-302) `davey-eu-night` or whichever strategy clears P1..P6 first under the DL-040 sequential operating model).

When both conditions hold, the Phase B issues open in this order:

- Issue 2 — Chief of Staff org/token review (input: Phase A weekly review + reboot plan)
- Issue 3 — Video Researcher YouTube source (`https://www.youtube.com/watch?v=UIdH5Ac1Db8`)
- Issue 4 — T1-T5 `.DWX` audit (partially covered by [QUA-588](/QUA/issues/QUA-588) F8 / [QUA-598](/QUA/issues/QUA-598); reframe as gap-fill against F8 evidence)
- Issue 5 — Company Operating Model dashboard contract (`public-data/company-operating-model.json`)

CEO is the gate-keeper; no Phase B issue is filed until CEO records the gate-met decision in a follow-up DL or comment on this DL.

### Phase C — deferred

- Issue 7 — Gmail Intake feasibility — defer until OWNER reports recurring `info@quantmechanica.com` volume that justifies the design work. No date.

## Rationale

The reboot plan's architectural thesis is sound and directly addresses the [QUA-588](/QUA/issues/QUA-588) F6 token-burn root cause: the Chief of Staff role is the bottleneck-routing + token-control layer the company is missing. The plan reframes "departments" as data contracts / issue templates / on-demand specialists, keeping the live company small and adding standing agents only when a recurring coordination loop justifies one.

What the plan does **not** address is sequencing risk. Hiring 6 net-new agents at once (CoS + Token Controller + PDF Researcher + Video Researcher + Data Environment Steward + Visualization Controller) while the company burns 14k runs/week with no V5 EA through P10 multiplies the F6 token-burn problem before the CoS has a chance to bend the curve. The phased GO buys evidence:

- **Phase A** seats the control tower (CoS) and codifies the lessons-loop. CoS owns the weekly bottleneck review that produces the F6 trend signal.
- **Phase B** opens only after that signal is real **and** the factory has shown it can graduate at least one EA. The "first V5 EA in P7" gate is the smallest credible proof that the existing factory works before adding research-side capacity (Issue 3) or data-ops capacity (Issue 4) or reporting capacity (Issue 5).
- **Phase C** is volume-gated, not time-gated. Gmail intake is real engineering work for a problem that has not yet manifested.

## Coupling to existing decisions

- **DL-040 ↔ DL-043 (additive, not violating).** [DL-040](#) sequential operating model — single SRC, single strategy active at a time, first-matrix-hold OWNER gate, 36-symbol parallelism only within one phase on one strategy — is unchanged. The Chief of Staff is a control-tower role (routing, token efficiency, bottleneck detection); it does not run strategies, dispatch backtests, or open additional source/strategy queues. Adding a routing layer above a sequential factory strengthens the throttle, not loosens it.
- **DL-017 ↔ DL-043.** Phase A hire of Chief of Staff is the third concrete hire under DL-017's CEO unilateral-hire authority (after DL-039 Quality-Business and DL-041 DevOps rehire). The pre-flight rule from DL-032 (race check via `?includeInactive=true` + inbox-routing inspection per the lessons-learned pattern) applies.
- **DL-023 ↔ DL-043.** This DL is recorded under the DL-023 broadened-authority waiver — class 1 (hires under DL-017) for Phase A.1 + class 4 (internal process choices → org-shape decision, phase gating, deferral criteria) for the rest.
- **DL-027 ↔ DL-043.** Chief of Staff hire follows the two-layer hire model: the role's BASIS prompt is filed as `paperclip-prompts/chief-of-staff.md` (or equivalent name CEO chooses), then the live agent's `adapterConfig.promptTemplate` is loaded from it. Doc-KM does not author the prompt (per documentation-km BASIS § DO NOT) — that is CTO + CEO territory.
- **DL-028 ↔ DL-043.** Chief of Staff runs from a per-agent worktree (`C:\QM\worktrees\chief-of-staff\` on branch `agents/chief-of-staff`) per the DL-028 isolation standard; DevOps-KM emergency at hire time is paired per memory `paperclip_hire_pair_with_worktree.md`.
- **DL-034 ↔ DL-043.** Chief of Staff heartbeat cadence is part of the hire spec; the role is "light heartbeat" per the reboot plan, which under the existing CEO/Pipeline-Op cadences (60min CEO, 30min Pipeline-Op since DL-040 throttle) suggests something like 60–120min. CEO sets the exact value at hire time; this DL does not bind a number.
- **DL-038 ↔ DL-043 (boundary, not authority).** None of the seven backtest rules cross into the Chief of Staff scope. Chief of Staff has no T6 authority (Forbidden in plan § "Chief of Staff / OS Controller Mandate"), no strategy-card decisions, no code edits.
- **DL-042 ↔ DL-043 (`agents/docs-km` view, Runtime-Health Doc Propagation).** Phase A.2 (lessons-loop codification, [QUA-595](/QUA/issues/QUA-595)) is downstream of DL-042's process-registry refinement work. The new `processes/18-company-operating-system.md` cross-links [`processes/17-agent-runtime-health.md`](../processes/17-agent-runtime-health.md) and the runtime-pathology escalation class.

## Chief of Staff retirement criterion (Phase A.1)

Recorded here for completeness; the operational record lives on [QUA-594](/QUA/issues/QUA-594):

- **Within 14 days of hire:** demonstrate **either** weekly heartbeat run rate down ≥20% from the 2026-05-01 baseline (14,639 runs/week per [QUA-588](/QUA/issues/QUA-588) F6) **or** produce a structural-floor analysis showing the rate cannot be reduced further without violating DL-040 / DL-038 / runtime-health requirements.
- **Within 30 days of hire:** if neither weekly trend reduction **nor** a structural-floor analysis materialises, **retire the role**. CEO records the retirement decision in a follow-up DL.
- **Permanent forbidden actions** (carried from reboot plan § "Chief of Staff / OS Controller Mandate"): no strategy-gate decisions, no code edits, no T6/live-money authority, no broad "manage everything" delegation.

## Phase B gates — recording contract

CEO will record gate-met evidence as one of:

1. A comment on this DL with the trend snapshot + EA P7 verdict link, **or**
2. A follow-up DL (DL-NNN, max+1 at the time) explicitly opening Phase B with the four issues filed.

Either path is acceptable; pick whichever reduces ceremony.

## Acceptance link to [QUA-593](/QUA/issues/QUA-593)

- ☑ DL file authored on `agents/docs-km` worktree (this file).
- ☑ [`REGISTRY.md`](REGISTRY.md) updated with DL-043 row + cross-links to DL-017, DL-023, DL-027, DL-028, DL-040, DL-042.
- ☑ F5a ([QUA-594](/QUA/issues/QUA-594)) + F5b ([QUA-595](/QUA/issues/QUA-595)) cross-linked to this DL via comments (Phase A scope).
- ☑ Authoritative refs: [`docs/ops/PAPERCLIP_COMPANY_REBOOT_PLAN_2026-04-30.md`](../docs/ops/PAPERCLIP_COMPANY_REBOOT_PLAN_2026-04-30.md), [`docs/ops/PAPERCLIP_COMPANY_REBOOT_ISSUES_2026-04-30.md`](../docs/ops/PAPERCLIP_COMPANY_REBOOT_ISSUES_2026-04-30.md), [QUA-588](/QUA/issues/QUA-588).
- ☑ Documentation-KM heartbeat picker pointer added to [`paperclip-prompts/documentation-km.md`](../paperclip-prompts/documentation-km.md) § "First Issues on Spawn" or equivalent durable surface.
