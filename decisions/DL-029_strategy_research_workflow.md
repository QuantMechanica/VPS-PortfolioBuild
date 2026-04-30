---
name: DL-029 — Strategy Research Workflow (Source → Strategy → Pipeline)
description: V5 binding workflow for taking a research resource (book/paper/blog/video) through extraction → Strategy Cards → end-to-end pipeline. Sequential, low-parallel, per-resource issue tree; one source / one strategy actively worked at a time; same-source enhancement = `_v2`, different-source = new card.
type: decision-log
---

# DL-029 — Strategy Research Workflow (Source → Strategy → Pipeline)

Date: 2026-04-27
Source directive: OWNER conversation, 2026-04-27 ~14:30 local (relayed by Board Advisor on QUA-236, ~14:35 local).
Ratifying issue: [QUA-236](/QUA/issues/QUA-236)
Recording issue (this entry): [QUA-247](/QUA/issues/QUA-247)
Owner: CEO (`7795b4b0-8ecd-46da-ab22-06def7c8fa2d`)
Recorder: Documentation-KM (`8c85f83f-db7e-4414-8b85-aa558987a13e`)
Supersedes: any improvised research flow that CEO + Research had spun up between Wave 0 and 2026-04-27 ~14:30 local.
Status: Active.

> **Recorder's note (Doc-KM scope per BASIS).** This DL canonicalizes the binding rule statement already shipped under QUA-242 (`processes/13-strategy-research.md`, commit `346cb05`) and the schema in QUA-243 (`strategy-seeds/cards/_TEMPLATE.md`, commit `5d2d7a08`). Doc-KM is recording, not interpreting. The process file is the operational source of record; this DL is the at-a-glance ADR for cross-reference and CEO sign-off trail.

## Decision

V5 executes the research-to-live arc through a structured, sequential, low-parallel workflow whose shape, card discipline, enhancement loop, and lineage rules are binding. The pattern is opinionated by design — to save tokens, keep focus on one thing at a time, and reuse V4's prior taxonomy.

### Rule statement

1. **Per-resource issue tree.** One parent Issue per resource (`SRC<NN> — <citation>`). One sub-Issue per strategy found in that resource (`SRC<NN>_S<n> — <slug>`). All sub-issues created `blocked` except the first (`todo`). The next sub-issue unblocks only when the prior strategy completes its end-to-end pipeline (Programmer → P1 Build → P2..P8 backtest gates → Quality-Tech sign-off → ready-or-killed verdict). Parent source-issue closes when ALL sub-issues close — **see § Path B clarification (2026-05-01) for the permissive G0-ratification close path that supersedes this default for SRC parents.** ONE source actively worked at a time. ONE strategy from that source actively worked at a time.
2. **Strategy Card discipline.** One `.md` per strategy at `strategy-seeds/cards/<slug>_card.md` (slug allocated at extraction; ea_id allocated at APPROVED → IN_BUILD; not in filename). Mandatory new fields per QUA-243 schema: `source_citations: []` (multi, list-of-objects with `role: primary | supplement`), `strategy_type_flags: []` (multi, controlled vocabulary at `strategy-seeds/strategy_type_flags.md`), `framework_alignment` section (`modules_used` map of 4 hooks + `hard_rules_at_risk` controlled list of 13 V5 hard rules + `at_risk_explanation`).
3. **Strategy lineage = source linkage.** Same source + in-pipeline learning = `_v2` of same `strategy_id` (same card, new row in § 14 Pipeline History). Different source = new sub-issue under the new source's parent (different `strategy_id`, different card). Test: *where did the insight come from?*, not *does the new EA look similar to the old one?*
4. **Enhancement loop.** Backtest with zero trades = automatic send-back to programmer. Each enhancement = new file version `_v2`, `_v3`, ... A `_v2` is treated as a NEW EA: re-runs the full P1 → P8 pipeline from scratch. Same Strategy Card lineage is preserved — only the Pipeline History block grows. Same logic for any "must re-test from P1" failure (input-rule change, parameter-set change beyond sweep, news-mode change).
5. **Pipeline-Operator load balancing across T1-T5.** Pipeline-Op distributes backtest runs across the five factory terminals to maximize throughput; T6 OFF LIMITS. No double-work: dedup tuple `(ea_id, version, symbol, phase, sub_gate_config)` is enforced by the registry at `D:\QM\reports\state\factory_run_dedup_v1.csv`. Allocation policy is least-loaded round-robin with symbol-affinity tie-break (Pipeline-Op's choice, codified in process 15).
6. **V4 prior taxonomy reuse.** Strategy-type flag controlled vocabulary is **mined from V4 archives**, not invented in V5. New flags can only be added via Research issue + V4 source citation + CEO/CTO ratification. The vocabulary is at `strategy-seeds/strategy_type_flags.md` (QUA-244 first cut, 23 flags across 5 sections).

### Scope

- **In scope:** any research-to-live arc starting from a book / paper / blog / video / forum-post source. Applies to V5 from 2026-04-27 forward.
- **Out of scope:** T6 live operations (separate boundary per DL-025); V4 archive mining as a research output (the V4 archives are a *source* for taxonomy, not a target for new extraction).
- **No parallel-source extraction.** Mirrors `paperclip-prompts/research.md` § THE CORE RULE.

## Authority basis

DL-023 § Broadened CEO authority class 4 (internal process choices → research workflow rules). OWNER ratified the directive directly on 2026-04-27 ~14:30 local; CEO records under DL-023 authority.

## Operational artifacts (committed)

- `processes/13-strategy-research.md` — workflow shape + card discipline + lineage rules (QUA-242, commit `346cb05`).
- `strategy-seeds/cards/_TEMPLATE.md` — V5 card schema with new mandatory fields (QUA-243, commit `5d2d7a08`).
- `strategy-seeds/strategy_type_flags.md` — controlled vocabulary mined from V4 archives (QUA-244, commit `d5efef3a`; CEO + CTO ratification pending).
- `processes/15-pipeline-op-load-balancing.md` — T1-T5 allocation + dedup + queue + evidence path (QUA-246, Pipeline-Op commit `09f0792` + canonical mirror `55b9243` on `agents/docs-km`; canonical-prompt addendum `7b7ca3a9` on `paperclip-prompts/pipeline-operator.md`).
- `processes/14-ea-enhancement-loop.md` — `_v<n>` versioning + zero-trades → programmer + Pipeline History row mechanics (QUA-245, in flight).

## Cross-links

- **DL-023 ↔ DL-029.** DL-029 is the fifth concrete operational change recorded under the DL-023 broadened-authority waiver (class 4: internal process choices → research workflow rules). DL-029 cites DL-023 as its authority basis.
- **DL-025 ↔ DL-029.** DL-029 explicitly carries forward DL-025's T6 boundary — strategy research and pipeline-op load balancing are factory-only (T1-T5).
- **DL-026 ↔ DL-029.** DL-029's child issues all closed with commit-hash-in-close-out per DL-026 — verified for QUA-242, QUA-243, QUA-244, QUA-246.
- **DL-027 ↔ DL-029.** Pipeline-Op's `paperclip-prompts/pipeline-operator.md` addendum (commit `7b7ca3a9`) is a BASIS revision; DL-027's diff side-artifact is the in-progress Doc-KM follow-up.
- **DL-028 ↔ DL-029.** All DL-029 child issue commits land via per-agent worktrees per DL-028 isolation; CEO authored this DL content but Doc-KM committed on `agents/docs-km` per the established pattern.
- **QUA-236 ↔ DL-029.** Forward link: QUA-236 → DL-029 (recorded via QUA-247). Reverse link: this file cites QUA-236 as the parent ratifying directive. Children QUA-242 / 243 / 244 / 245 / 246 / 247 are the operationalization cohort.

## Wave 2 hire trigger update

Pre-DL-029, the Wave 2 hire trigger (Quality-Tech / Development / Quality-Business) required Research to land "first card" on SRC01 Ernest Chan. DL-029 supersedes that with: **first card written under the new `_TEMPLATE.md` schema** (i.e., includes populated `source_citations`, `strategy_type_flags`, `framework_alignment`). Cards written before QUA-243's commit `5d2d7a08` do not satisfy the trigger.

## Path B clarification (2026-05-01) — Parent lifecycle is permissive

Date: 2026-05-01
Authority: CEO sign-off on [QUA-623](/QUA/issues/QUA-623) (sequencing-decision close-out), recorded under [QUA-635](/QUA/issues/QUA-635).
Owner: CEO (`7795b4b0-8ecd-46da-ab22-06def7c8fa2d`)
Recorder: Documentation-KM (`8c85f83f-db7e-4414-8b85-aa558987a13e`)

Doc-KM's SRC03 audit ([QUA-625](/QUA/issues/QUA-625)) surfaced a divergence between Rule 1's literal text ("parent source-issue closes when ALL sub-issues close") and CEO practice (closing SRC parents at G0 ratification while sub-issues continue downstream). CEO chose **Path B (Permissive)** over Path A (Strict re-open) and Path C (Split parents); the binding rule is therefore amended as follows:

> A parent SRC issue MAY close `done` at G0 ratification when all sub-issues are queued for downstream pipeline. Sub-issues remain alive in their own dispatch queue and are NOT blocked by parent closure. Empty `blockedByIssueIds` on `blocked` strategy sub-issues is the expected state — Process-13 sequences sub-issues by **status** (first `todo`, rest `blocked`), not by edge.

Why Path B (not A or C):

- **Matches CEO's stated intent on QUA-298 closeout** ("Sub-issue chain: no PATCH required... Pipeline-Op picks up QUA-314 in next dispatch cycle") — the practice has been intentional, not accidental.
- **Avoids re-opening 4+ closed parents** (SRC03 / SRC04 today + future SRCs) — Path A would impose plumbing churn on settled history.
- **Aligns with DL-040 sequential-ops + token throttle** — fewer edges and fewer mid-flight re-opens is the cheaper coordination posture.

Operational consequences:

- **Audits** that flag empty `blockedByIssueIds` on `blocked` SRC0N strategy sub-issues as a defect are tripping on a non-violation. The expected steady state is empty edges + status-driven sequencing.
- **Pipeline-Operator** continues promoting next-in-line sub-issues from `blocked` → `todo` when the prior one completes (per process-13 step 8); no edge-graph dependency is required.
- **Existing closed SRC parents are NOT being re-opened.** This amendment ratifies current practice; it does not retroactively rewrite history.

The `processes/13-strategy-research.md` clarifying note (Per-step responsibilities § Note on `blockedByIssueIds`) is the operational mirror of this amendment.
