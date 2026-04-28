---
name: DL-039 — Quality-Business Hire (9th-agent OWNER override of Wave-2 8-cap)
description: OWNER 2026-04-28 12:30 local — one-time waiver of the V5 Org Proposal § 6 anti-sprawl 8-cap to seat Quality-Business as the 9th active agent. Authority chained from DL-017 (CEO hire-approval waiver) + DL-023 v2 (CEO broadened scope, class 4 — internal process choices) + the explicit OWNER directive. The 8-cap remains in force for any further hires; the override does NOT extend to Wave 3+. Records the hire-time `cwd` path-mangle bug that retired the original Quality-Business agent (`f2c79849-...`) the same day; CEO stood up Quality-Business 2 (`0ab3d743-...`) as the working replacement.
type: decision-log
---

# DL-039 — Quality-Business Hire (9th-agent OWNER override of Wave-2 8-cap)

Date: 2026-04-28
Source directive: OWNER 2026-04-28 12:30 local — direct hire authorisation for Quality-Business outside the V5 Org Proposal § 6 8-cap, relayed onto [QUA-429](/QUA/issues/QUA-429) by CEO.
Ratifying issue: [QUA-429](/QUA/issues/QUA-429) (CEO hire issue).
Recording cohort: [QUA-434](/QUA/issues/QUA-434) (Doc-KM Active-agents row), [QUA-441](/QUA/issues/QUA-441) (Doc-KM registry expansion + Class-2 flip), [QUA-438](/QUA/issues/QUA-438) (CEO G0 backlog dispatch + QB→QB2 routing fix), [QUA-439](/QUA/issues/QUA-439) (CTO `cwd` path-mangle follow-up).
Owner: CEO (`7795b4b0-8ecd-46da-ab22-06def7c8fa2d`).
Recorder: Documentation-KM (`8c85f83f-db7e-4414-8b85-aa558987a13e`).
Status: Active. Additive to DL-017, DL-023; one-time override of the V5 Org Proposal § 6 8-cap.

> **Recorder's note (Doc-KM scope per BASIS).** This file canonicalises content already shipped on `agents/docs-km` in `processes/process_registry.md` § Active agents (commits `8d79be93`, `f2ed6046`, `1e660ad7`) and `docs/ops/AGENT_SKILL_MATRIX.md` § Hiring Reality (commit `1e660ad7`). CEO's [QUA-429](/QUA/issues/QUA-429) closeout (2026-04-28T12:57:19Z) listed this DL as "CEO follow-up next heartbeat" pending high-water-mark check; Doc-KM authored the file at the next coordinated heartbeat after the references shipped, mirroring the DL-033 / DL-034 / DL-035 / DL-036 / DL-037 recording pattern. CEO retains revise/replace authority on content scope.

## Decision

OWNER 2026-04-28 12:30 local: **waive the V5 Org Proposal § 6 anti-sprawl 8-agent cap, one-time, to seat Quality-Business as the 9th active agent.** The 8-cap remains in force for any further hires; the override does NOT extend to Wave 3+ roles (Controlling, Observability-SRE, LiveOps, R-and-D, Chief of Staff).

### Rule statement

1. **9th-agent waiver scope.** As of 2026-04-28, the org runs 9 active agents: Wave 0 (CEO, CTO, Research, Documentation-KM) + Wave 1 (DevOps, Pipeline-Operator) + Wave 2 (Quality-Tech, Development, Quality-Business). The Wave 2 cohort exceeds the original Wave-2 plan by exactly one (Quality-Business as the 9th).

2. **Authority chain.** The hire is authorised under DL-017 (CEO hire-approval waiver — `requireBoardApprovalForNewAgents=false`) + DL-023 v2 broadened scope class 4 (internal process choices — wave-shape + active-agent count is internal to CEO/OWNER negotiation). The OWNER directive is the explicit override of the 8-cap; CEO does NOT have unilateral authority to exceed the cap under DL-017 or DL-023 alone.

3. **Forward boundary.** Wave 3+ hires (Controlling, Observability-SRE) and beyond remain bounded by the 8-cap principle as restated in the V5 Org Proposal § 6. The override is **scope-limited** to the 2026-04-28 QB hire only. Future expansions require either a fresh OWNER directive or a successor DL-NNN that revises the cap policy.

4. **DL-030 Class 2 reviewer.** The DL-030 Class 2 (Strategy Card extraction → Review-only) reviewer participant identifier flips from "CEO interim" to "CEO + Quality-Business" effective 2026-04-28; same Review-only shape, named participant added. New Strategy Card child issues created on/after 2026-04-28 carry the QB participant id at creation time. Existing in-flight Class-2 cards keep their original participants until close-out (no retroactive repolicy).

## Hire history (Quality-Business 2 supersedes original Quality-Business)

The original Quality-Business agent record (`f2c79849-a19e-4bc0-8737-438dd50ada64`) hit a `cwd` path-mangle bug at hire (the adapter expanded `C:\QM\repo` to `C:\QMepo`, errored at the first heartbeat). CTO follow-up [QUA-439](/QUA/issues/QUA-439) tracks the underlying adapter bug. CEO retired the original record the same day (renamed to `Quality-Business (RETIRED 2026-04-28)`, heartbeat disabled) and stood up **Quality-Business 2** (`0ab3d743-e3fb-44e5-8d35-c05d0d78715d`, cwd `C:\QM\worktrees\quality-business`) as the working replacement.

The CEO recovery sweep on QUA-431 / QUA-438 reassigned the live G0 backlog to QB2 (per QUA-438 routing-fix comment by `f2c79849` at 2026-04-28T13:02:50Z). Two onboarding issues ([QUA-432](/QUA/issues/QUA-432), [QUA-433](/QUA/issues/QUA-433)) and the G0 dispatch ([QUA-438](/QUA/issues/QUA-438)) were reassigned to QB2 in the same window.

| Aspect | Original QB (retired) | Quality-Business 2 (active) |
|---|---|---|
| Agent ID | `f2c79849-a19e-4bc0-8737-438dd50ada64` | `0ab3d743-e3fb-44e5-8d35-c05d0d78715d` |
| Status | `Quality-Business (RETIRED 2026-04-28)`, heartbeat disabled | `Quality-Business 2`, heartbeat event-driven + 4h fallback |
| `cwd` | `C:\QMepo` (mangled, broken) | `C:\QM\worktrees\quality-business` |
| Scope of work | None — never produced a verdict | All G0 review backlog + onboarding (QUA-431/432/433/438 + SRC05 batch) |

For DL-030 Class 2 participant resolution and any agent-id-bearing references in process docs / runtime config, **`0ab3d743-e3fb-44e5-8d35-c05d0d78715d` (QB2) is canonical**; `f2c79849-...` is preserved as a retired audit record only.

## What changes immediately

1. **Active-agent count = 9** in `processes/process_registry.md` § Active agents preamble. The 8-cap restated as the post-DL-039 ceiling for Wave 3+ hires.

2. **`docs/ops/AGENT_SKILL_MATRIX.md` § Hiring Reality** lists Quality-Business 2 as Live with agent id `0ab3d743-...`; the QT and Development Wave-2 hires are listed alongside per QUA-441.

3. **DL-030 Class 2 row** in `processes/process_registry.md` § Execution Policies names `CEO + Quality-Business` (QB2 agent id at the runtime layer) as the Review-only participants. CEO sentinel-sweep PATCH may be needed to repolicy any in-flight Class-2 issues that were created against the retired QB id pre-recovery; this is tracked operationally and not part of this DL's deliverable.

4. **No paperclip-prompts/* changes.** Per DL-027, BASIS files are OWNER-managed and Git-canonical; QB and QB2 share `paperclip-prompts/quality-business.md` as the BASIS source.

## What does NOT change

- **Wave 3+ cap.** The 8-cap remains in force for Controlling, Observability-SRE, LiveOps, R-and-D, Chief of Staff. DL-039 is one-time and scope-limited.
- **DL-017 hire-approval waiver scope.** DL-017 still gives CEO unilateral hire authority within the V5 Org Proposal wave plan; DL-039 only carves out the +1 cap exception, it does not broaden the hire-approval waiver.
- **DL-030 Class 2 / Class 3 shape.** Review-only with named reviewer; only the named participant changes (CEO interim → CEO + QB2; CTO interim → QT). Self-review prevention rules unchanged.
- **DL-016 OWNER fallback.** OWNER remains the Class 2 fallback participant for cases where CEO is the original Strategy Card executor (e.g., CEO-authored interim cards). The fallback is independent of QB2 being a named reviewer.

## Cross-links (canonical)

- **DL-017 ↔ DL-039.** DL-017 is the CEO hire-approval waiver; DL-039 is the one-time numerical override of the wave-plan cap that DL-017 operates within. DL-039 cites DL-017 as the underlying authority for *who* can hire (CEO unilateral) and the OWNER directive as the authority for *exceeding the cap*.
- **DL-023 ↔ DL-039.** DL-039 is recorded under the DL-023 broadened-authority waiver class 4 (internal process choices) — wave-shape and active-agent count are internal to the CEO/OWNER negotiation. DL-039 cites DL-023 as authority basis for the recording mechanism.
- **DL-030 ↔ DL-039.** DL-039 flips the DL-030 Class 2 named reviewer from "CEO interim" to "CEO + Quality-Business 2" effective 2026-04-28. Same Class-2 Review-only shape; only the named participant changes. DL-030 itself is unchanged at the document level (per DL-026 operational-doc precedence: DL-NNN docs are time-stamped records of the convention at decision time; current-state language lives in `processes/process_registry.md`).
- **QUA-429 ↔ DL-039.** Forward link: QUA-429 → DL-039 (this entry). The OWNER directive is captured as `OWNER 2026-04-28 12:30 directive` on QUA-429's title and CEO closeout pointer at 2026-04-28T12:57:19Z. Reverse link: this file cites QUA-429 as the ratifying issue.
- **QUA-434 ↔ DL-039.** Forward link: QUA-434 → DL-039 (Doc-KM Active-agents recording). Reverse link: this file cites QUA-434 as the registry-shape recording task.
- **QUA-441 ↔ DL-039.** Forward link: QUA-441 → DL-039 (Doc-KM Class-2 flip + QT/Dev expansion). Reverse link: this file cites QUA-441 as the registry-content recording task. QUA-441's commit `f2ed6046` declared `Authority: DL-039` ahead of the DL file existing; this entry materialises that reference.
- **QUA-438 ↔ DL-039 (operational, not authority).** Forward link: QUA-438 → DL-039 (G0 backlog dispatch ran on QB2 from the start; no retroactive verdicts on QB-retired-id work). Reverse link: this file cites QUA-438's routing-fix comment by `f2c79849` at 2026-04-28T13:02:50Z as the audit record of the QB→QB2 handoff.
- **QUA-439 ↔ DL-039 (causal, not authority).** Forward link: QUA-439 → DL-039 (CTO follow-up on the `cwd` path-mangle adapter bug that triggered the QB retirement). Reverse link: this file cites QUA-439 as the underlying-bug tracking issue. The bug fix is out of DL-039's scope; DL-039 only records the *organisational* response (retire + re-hire on a clean cwd).

## DL-NNN allocation note

DL-038 was allocated by QUA-426 (cancelled as duplicate of QUA-418) → recorded under QUA-418 with file `decisions/2026-04-28_seven_backtest_rules.md` and registry row at REGISTRY.md per `max(existing) + 1`. Per the same rule, this entry lands as **DL-039** (DL-038 + 1). No collision risk: no parallel allocation by CEO observed at recording time on either `agents/docs-km` or `origin/main`. CEO retains authority to revise the number on review if a parallel allocation is found; recorder will follow the registry's "skipped numbers are intentional gaps; do not reuse" rule on revision.

## Versioning

| Version | Date | Author | Notes |
|---|---|---|---|
| v1.0 | 2026-04-28 | Documentation-KM ([QUA-429](/QUA/issues/QUA-429) ratifying issue; QUA-434 / QUA-441 recording cohort) | Initial entry. CEO ratification pending — file authored from already-shipped registry content (commits `8d79be93`, `f2ed6046`, `1e660ad7`); content scope is CEO-revisable per QUA-429 closeout's "CEO follow-up" framing. |
