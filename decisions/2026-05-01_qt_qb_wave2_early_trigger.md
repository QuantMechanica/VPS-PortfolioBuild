---
name: DL-045 — Wave 2 Early-Trigger Hires (Quality-Tech + Quality-Business)
description: Backfill audit-trail DL for the Wave-2 hires of Quality-Tech (`c1f90ba8-...`, 2026-04-28) and Quality-Business 2 (`0ab3d743-...`, 2026-04-28). Records that the role-specific design-intent triggers in `2026-04-27_v5_org_proposal.md` § "Wave 2 — Quality-Tech, then Development, then Quality-Business" had not formally fired at hire moment (QT trigger "first Backtest Baseline emits report.csv"; QB trigger "first Quality-Tech PASS candidate"); the hires were authorised under the unified DL-029 trigger ("first Strategy Card written under the new `_TEMPLATE.md` schema") + OWNER directive layered on top. Snap-back rule: no further Wave 2 hires until the role-specific trigger fires for that role. Pure backfill — no charter / org-chart / hire decisions are revisited.
type: decision-log
---

# DL-045 — Wave 2 Early-Trigger Hires (Quality-Tech + Quality-Business)

Date: 2026-05-01
Source directive: [QUA-639](/QUA/issues/QUA-639) Deliverable D4 — "Doc-KM authors backfill DL for QT and QB early-trigger hires (Wave 2 triggers per org_chart had not technically fired; net effect of QT hire is positive — unblocks D1 today)."
Recording issue: [QUA-645](/QUA/issues/QUA-645) (Doc-KM lane).
Owner: CEO (`7795b4b0-8ecd-46da-ab22-06def7c8fa2d`).
Recorder: Documentation-KM (`8c85f83f-db7e-4414-8b85-aa558987a13e`).
Status: Active. Pure backfill — additive to DL-029 (collective Wave 2 trigger), DL-039 (QB 9th-agent override), and DL-044 (Research pause). Does not modify Wave 3+ hire policy.

> **Recorder's note (Doc-KM scope per BASIS).** This file canonicalises the audit-trail completion already requested in QUA-639 D4. The hires themselves stand and are not revisited; this DL only formalises the gap between role-specific design-intent triggers and the operational hire moment, names the override reason for each role, and records the snap-back rule. No `paperclip-prompts/*.md` or `processes/*` changes are required: live roster surface (`docs/ops/AGENT_SKILL_MATRIX.md` § "Hiring Reality") already shows both agents as Live.

## Decision

**Quality-Tech (`c1f90ba8-...`) and Quality-Business 2 (`0ab3d743-...`) were both hired on 2026-04-28 ahead of their role-specific design-intent triggers firing.** The hires were authorised by the unified DL-029 trigger ("first Strategy Card written under the new `_TEMPLATE.md` schema", which fired with SRC02 card extraction on 2026-04-28) plus OWNER directive (DL-039 records the QB-side 8-cap waiver). This DL backfills the override audit trail; it does not change the hires.

### Trigger inventory (design-intent vs operational reality)

| Role | Agent ID | Hired | Design-intent trigger (per `2026-04-27_v5_org_proposal.md` § Wave 2 hire order) | Trigger state at hire | Override authority |
|---|---|---|---|---|---|
| Quality-Tech | `c1f90ba8-...` | 2026-04-28 | "first Backtest Baseline emits `report.csv`" (post-DL-038 phrasing) — i.e., V5 framework Implementation Order steps 1–25 compiled and the first Phase 2 / Phase 3 backtest produces the canonical `report.csv`. | **Not fired.** Step 25 (full framework review) had not yet been commissioned (QUA-643 still unblocked). No baseline `report.csv` had been produced by V5 EAs. | DL-029 (collective Wave 2 trigger via Strategy Card schema) + CEO operational call: independent EA review gate needed to unblock Step 25 itself. |
| Quality-Business 2 | `0ab3d743-...` | 2026-04-28 | "first Quality-Tech PASS candidate" — i.e., QT must already have rendered a PASS verdict on at least one EA before QB seats. | **Not fired.** QT was hired on the same day; no QT PASS verdict existed at QB-hire time. | DL-029 (collective trigger) + DL-039 (OWNER 2026-04-28 12:30 directive — one-time 9th-agent override of V5 Org Proposal § 6 8-cap). |

### Override reasons (per role)

1. **Quality-Tech early hire — CEO operational call under DL-029.** The CEO judged that an independent EA-code-review reviewer separate from CTO was needed to unblock the Phase 2 framework close itself (QUA-639 D1: Step 25 = QT review of the as-shipped framework). Hiring QT after Step 25 PASS would have been circular: CTO cannot author and review the same framework, and Step 25 is precisely the gate the design-intent QT trigger ("first `report.csv`") sits behind. Hiring QT early to break this circularity is a net-positive operational choice. Authority basis: DL-029 (Strategy Card schema trigger satisfied by SRC02) + DL-017 (CEO unilateral hire authority within Wave 2 cap) + the CEO's framework-acceptance gate directive captured in [QUA-639](/QUA/issues/QUA-639) D1.

2. **Quality-Business early hire — OWNER directive under DL-039.** The QB-side override is already recorded in DL-039: OWNER 2026-04-28 12:30 directive seated QB as the 9th active agent (one-time waiver of the V5 Org Proposal § 6 8-cap). The QB design-intent trigger ("first QT PASS candidate") was not yet satisfied at hire time, but DL-039's OWNER directive operates as the explicit override. DL-045 records the *trigger-side* dimension that DL-039 left implicit: the QB hire was both a *cap waiver* (DL-039) AND a *trigger override* (this DL).

### Why this matters

- **Audit trail completeness.** Without a DL recording the trigger override, the Wave 2 trigger language in `2026-04-27_v5_org_proposal.md` § "Wave 2 — Quality-Tech, then Development, then Quality-Business" reads as if QT/QB hires were sequenced after their role-specific triggers. They were not. Future readers (new agents at onboarding; a six-month-from-now CEO doing a structural-floor review) need a single place that says "design-intent trigger ≠ operational trigger; here is the override".
- **Specification Density Principle (CLAUDE.md).** A spec that omits the gap between *design-intent* and *operational* triggers fails the "every relevant case is named" test. DL-045 closes the named-case gap.
- **Net-effect framing.** QT's early hire is not just safe — it is *load-bearing* for Phase 2 close. Without QT, Step 25 has no reviewer that is simultaneously (a) independent of CTO and (b) the V5 framework's spec-side reviewer. The "early hire" framing should not read as a debt; it reads as an unblocking move that QUA-639 D1 explicitly relies on.

## Snap-back rule

**No further Wave 2 hires until the role-specific design-intent trigger fires for that role.** The Wave 2 cohort is closed at 3 (QT, Development, QB2) per DL-039's one-time 9th-agent waiver. Any Wave 3+ hire (Controlling, Observability-SRE, LiveOps, R-and-D, Chief of Staff, Board Advisor) requires either:

1. The wave-specific trigger to fire as written in the V5 Org Proposal § 6 hire-order plan, **AND** CEO authority via DL-017 (within wave plan); OR
2. A successor DL-NNN that explicitly revises the trigger or wave plan; OR
3. A fresh OWNER directive (per DL-023 v2 broadened scope class 4).

DL-045 does **not** generalise the early-hire pattern. It is a backfill record of two specific hires under the Phase 2 close pressure described in QUA-639. Future hires must default to the design-intent trigger; any future override needs its own DL.

## What does NOT change

- **DL-029.** The unified Wave 2 collective trigger (Strategy Card written under new `_TEMPLATE.md` schema) is unchanged. DL-045 explicitly cites DL-029 as the underlying authority that authorised the hires; it does not modify the trigger language.
- **DL-039.** The 9th-agent OWNER override scope and its forward boundary (8-cap remains in force for Wave 3+) are unchanged. DL-045 layers the trigger-side audit trail onto the cap-side record DL-039 already established.
- **DL-030.** Class 2 (CEO + QB2) and Class 3 (CTO interim → QT) reviewer participants are unchanged. The reviewer flips already happened with the hires; DL-045 does not introduce new flips.
- **`paperclip-prompts/*.md`.** Per DL-027, BASIS files are OWNER-managed and Git-canonical. DL-045 does not touch any prompt.
- **`docs/ops/AGENT_SKILL_MATRIX.md`.** The matrix already shows QT and QB2 as Live with a hire-reality note (refresh date 2026-04-28). DL-045 does not require a matrix update; the matrix's "Hiring Reality" framing already implicitly covers the early-trigger gap.
- **`processes/process_registry.md`.** Active-agent count and reviewer assignments are already reconciled (commits `8d79be93`, `f2ed6046`, `1e660ad7` per DL-039 § "Recorder's note"). No process-doc churn from this DL.

## Cross-links

- **DL-014 ↔ DL-045.** The two-layer prompt pattern (BASIS + Paperclip operating contract) is unchanged. DL-045 does not modify any prompt; it only records which trigger authorised the hires that already loaded prompts at hire time.
- **DL-017 ↔ DL-045.** DL-017 gives CEO unilateral hire authority within the V5 Org Proposal wave plan. DL-045 records that the QT hire ran on DL-017 + DL-029 (within the wave-2 cap), and the QB hire ran on DL-017 + DL-029 + the OWNER 8-cap waiver captured in DL-039.
- **DL-023 ↔ DL-045.** DL-023 v2 broadened-authority class 4 (internal process choices) is the authority basis for DL-045's *recording mechanism* — wave-shape and trigger-vs-operational gap are internal to the CEO/OWNER negotiation. DL-045 does not invoke DL-023 for the hires themselves; the hires ran on DL-017 + DL-029 + DL-039.
- **DL-024 ↔ DL-045.** DL-024 closed Wave 0 bootstrap and named the rate (not the model) for cadence; DL-045 records a structurally similar "design-intent vs operational" gap for Wave 2. No rate / model change.
- **DL-029 ↔ DL-045.** DL-029 supersedes the original Wave 2 trigger ("first card on SRC01 Ernest Chan") with "first Strategy Card under new `_TEMPLATE.md` schema". That collective trigger fired on 2026-04-28 with SRC02 extraction; DL-045 records that the *role-specific* design-intent triggers (QT: first `report.csv`; QB: first QT PASS) had not yet fired but the collective trigger was sufficient under CEO + OWNER override.
- **DL-038 ↔ DL-045.** DL-038's Seven Binding Backtest Rules name `report.csv` as the canonical baseline output; the QT design-intent trigger's "first Backtest Baseline emits `report.csv`" phrasing is the post-DL-038 articulation. DL-045 records that this trigger had not fired at hire time.
- **DL-039 ↔ DL-045.** DL-039 covered the QB 8-cap waiver (cap-side). DL-045 covers the QT + QB trigger override (trigger-side). The two records together capture the full audit trail for QB; DL-045 alone covers QT.
- **DL-044 ↔ DL-045.** DL-044 paused Research extraction until first V5 EA reaches Phase 7. DL-045 is unaffected by the pause: DL-029's Wave 2 trigger had already fired with SRC02 cards before DL-044 took effect. The retroactive-trigger-firing audit trail is closed.
- **QUA-639 ↔ DL-045.** Forward link: QUA-639 D4 → DL-045 (this entry). Reverse link: this file cites QUA-639 as the source directive.
- **QUA-643 ↔ DL-045.** Forward link: QUA-643 (Step 25 QT review) is the load-bearing dependency that justifies the QT early hire. Reverse link: this file cites QUA-643 as the proximate operational reason for QT hiring ahead of trigger.
- **CLAUDE.md (Specification Density Principle) ↔ DL-045.** This DL exists to satisfy the "every relevant case is named" rule by closing the design-intent-vs-operational gap on the Wave 2 trigger surface.

## Boundaries

- **Not authority to revisit Wave 2 hire decisions or retire QT/QB.** The hires stand. DL-045 only completes the audit trail.
- **Not a generalised early-hire pattern.** Future Wave 3+ hires default to the design-intent trigger; any override needs its own DL.
- **No `paperclip-prompts/*.md` patches.** BASIS files are OWNER-managed.
- **No org-chart edits.** `paperclip/governance/org_chart.md` (cited in QUA-639's wake comment) does not exist on `agents/docs-km` or any other branch as of recording — see § "Cited-authority drift" below; DL-045 does not author or modify any org-chart file.
- **No process-doc churn per DL-034 / QUA-639 D2 throttle.** The 72-hour throttle window (CTO + Development biased to framework + 1003/1004; Doc-KM in lessons-learned + ADR authoring mode) is respected. This DL is the authoring mode itself.
- **No Notion mirror-back.** Per DL-027 + the established `infra/notion-sync` direction (Notion → Git only), DL-045 does not push back to Notion. The nightly `infra/notion-sync` routine on this surface is import-only; if a Notion-side reflection is desired, that's a separate write-side child outside DL-045's scope.

## Cited-authority drift (transparency note)

QUA-645's wake comment cited "Authority: DL-034 (`decisions/2026-05-01_phase2_heartbeat_rebalance.md`) — Doc-KM in lessons-learned + ADR authoring mode for the throttle window." Recorder verified before authoring:

- **DL-034 in REGISTRY.md** is `2026-04-28_ceo_heartbeat_30min.md` (CEO heartbeat 3600s → 1800s, recorded under QUA-301). It is **not** the cited 2026-05-01 phase2 heartbeat rebalance file.
- **`decisions/2026-05-01_phase2_heartbeat_rebalance.md`** does not exist on `agents/docs-km`, `agents/ceo`, `origin/main`, or any other tracked branch as of recording (verified via `git ls-tree -r <ref>` across branches).
- **`paperclip/governance/org_chart.md`** and **`docs/ops/PHASE2_FRAMEWORK_CLOSEOUT_AUDIT_2026-05-01.md`** also do not exist on any branch as of recording — both are referenced in QUA-639 / QUA-645 wake content but have not yet landed.

Per memory `paperclip_drift_edit_authority_check.md`, the recorder verified the cited DL before accepting the directive. Conclusion: the cited DL number and file path are not current; the directive's *intent* (backfill the QT + QB early-trigger record) is fully captured in QUA-639 D4 + the wake comment's inline trigger description, both of which are sufficient and consistent. DL-045 proceeds on:

1. QUA-639 D4 directive content (the Wave 2 trigger table fragment quoted in the wake comment).
2. DL-029 (collective Wave 2 trigger).
3. DL-039 (QB 9th-agent OWNER override — already recorded).
4. `2026-04-27_v5_org_proposal.md` § Wave 2 hire order (the role-specific design-intent triggers).

The directive's "throttle window" instruction (Doc-KM in lessons-learned + ADR authoring mode) is honoured even though its cited authority (DL-034 = phase2 heartbeat rebalance) does not yet have a canonical file: this DL itself sits squarely in lessons-learned + ADR authoring mode and produces no process-doc churn.

## DL-NNN allocation note

Current `max(existing) = DL-044` (Research Pause, recorded 2026-05-01 by Doc-KM under QUA-597). Per the registry's "max(existing) + 1" rule, this entry lands as **DL-045**. QUA-645's wake comment advised "coordinate with REGISTRY.md so DL-035/DL-036 used by CEO for D3/D5 are not collided"; recorder reads that as informal advice (DL-035 + DL-036 are already taken since 2026-04-28 by `2026-04-28_pipeline_loadbalance_convention.md` and `2026-04-28_ea_review_gate.md`, so the cited reservation is stale). CEO's downstream D3 (CoS triage), D5 (metadata), and D2 (heartbeat rebalance / "DL-034" in the wake comment) entries follow `max(existing) + 1` from DL-045 onward (next available: DL-046, DL-047, DL-048 in CEO's order). Recorder will not collide with CEO's D1 (Step 25 acceptance ADR) since that DL records under a different recording-cohort once Step 25 closes.

## Versioning

| Version | Date | Author | Notes |
|---|---|---|---|
| v1.0 | 2026-05-01 | Documentation-KM ([QUA-645](/QUA/issues/QUA-645) Doc-KM lane under [QUA-639](/QUA/issues/QUA-639) parent directive D4) | Initial entry. Pure backfill of the trigger-side audit trail for the QT (`c1f90ba8-...`) + QB2 (`0ab3d743-...`) Wave-2 hires; QT cap-side authority chain is DL-017 + DL-029 + CEO operational call (Step 25 unblock); QB cap-side authority chain is DL-017 + DL-029 + DL-039 (OWNER 8-cap waiver). Snap-back rule: no further Wave 2 hires until role-specific design-intent trigger fires. CEO retains revise/replace authority on content scope per BASIS. |
