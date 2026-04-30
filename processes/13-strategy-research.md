---
title: Strategy Research Workflow (source → strategy → pipeline)
owner: Documentation-KM
last-updated: 2026-04-27
authored-by: QUA-242 (Doc-KM)
parent-directive: QUA-236 (OWNER 2026-04-27)
---

# 13 — Strategy Research Workflow

How V5 turns a research resource (book / paper / blog / video / forum) into approved Strategy Cards, each of which feeds the EA Life-Cycle ([01-ea-lifecycle.md](01-ea-lifecycle.md)) at L0/L1.

> **Binding source:** OWNER directive 2026-04-27 ~14:30 local, captured in QUA-236. The flow is opinionated, sequential, and low-parallel by design — to save tokens, keep the company focused, and reuse V4's prior taxonomy work. It supersedes any improvised research flow.

## Trigger

- CEO + Research nominate a new source (Research proposes from `seed_assets/sources/` queue; CEO ratifies).
- OWNER drops a source via comment on a QUA issue or in a Drive seed location.
- A previously-extracted source needs re-mining for a missed strategy (rare; CEO reopens parent).

## Actors

| Step | Owner | Support | Interim (until hired) |
|------|-------|---------|-----------------------|
| Source nomination | [Research](/QUA/agents/research) | [CEO](/QUA/agents/ceo) | — |
| Parent issue open | [CEO](/QUA/agents/ceo) | — | — |
| Strategy extraction | [Research](/QUA/agents/research) | [CEO](/QUA/agents/ceo) | — |
| Card review / approval | [CEO](/QUA/agents/ceo) | Quality-Business *(Wave 2)* | CEO covers Quality-Business until Wave 2 |
| Framework-alignment check | [CTO](/QUA/agents/cto) | [Research](/QUA/agents/research) | — |
| Build (L2 prototype) | Development *(Wave 2)* | [CTO](/QUA/agents/cto) | CTO until Development hired |
| Pipeline backtests (P1..P8) | [Pipeline-Operator](/QUA/agents/pipeline-operator) | Quality-Tech *(Wave 2)* | CTO covers gate review until Wave 2 |
| Gate verdicts | Quality-Tech *(Wave 2)* | [Pipeline-Operator](/QUA/agents/pipeline-operator) | CTO until Wave 2 |
| Issue tree maintenance | [Documentation-KM](/QUA/agents/documentation-km) | [CEO](/QUA/agents/ceo) | — |

## Issue tree shape (binding)

The shape is fixed. Do not improvise a different decomposition.

```
SRC<NN> — <Source citation>            (parent, status: in_progress while any sub is open)
├── SRC<NN>_S1 — <slug>                (sub, status: todo — first strategy actively worked)
├── SRC<NN>_S2 — <slug>                (sub, status: blocked — unblocks when S1 closes)
├── SRC<NN>_S3 — <slug>                (sub, status: blocked)
└── ...
```

Rules:

- **Per resource = ONE parent Issue.** Title pattern: `SRC<NN> — <Source citation>`. CEO opens it.
- **Per strategy found in that resource = ONE sub-Issue under that parent.** Title pattern: `SRC<NN>_S<n> — <strategy-slug>`.
- **All sub-issues are created `blocked` EXCEPT the first.** First is `todo` and gets actively worked.
- **The next sub-issue unblocks only when the prior strategy completes its end-to-end pipeline:** Programmer → P1 Build → P2..P8 backtest gates → Quality-Tech sign-off → ready-or-killed verdict.
- **The parent source-issue closes** when ALL sub-issues under it close.
- **One source actively worked at a time.** One strategy from that source actively worked at a time. No parallel-source extraction (mirrors `paperclip-prompts/research.md` § THE CORE RULE).

### Why sequential (not parallel)

Per OWNER directive 2026-04-27: parallel research mining bleeds tokens, fragments review attention, and produces near-duplicate cards. Sequential keeps the lessons-feedback loop tight — what we learn from S1 in the pipeline can sharpen extraction for S2 before S2 even leaves Research.

## Strategy Card discipline (binding)

One `.md` file per strategy at:

```
strategy-seeds/cards/<slug>_card.md
```

(Renamed from the legacy `QM5_NNNN_<slug>_card.md` pattern. Slug is allocated at extraction time; the EA-ID is allocated later by CEO + CTO at the APPROVED → IN_BUILD transition.)

The card uses `strategy-seeds/cards/_TEMPLATE.md` (V5 schema, updated under QUA-243). Mandatory new fields:

- **`source_citations: []`** — one or more entries. A strategy that combines insights from two papers cites BOTH. Each entry mirrors the parent source's `## 4. Citation header` block.
- **`strategy_type_flags: []`** — multi-select from the controlled vocabulary at `strategy-seeds/strategy_type_flags.md` (mined from V4 archives under QUA-244). Examples: `mean-reversion`, `breakout`, `momentum`, `news-pause`, `seasonality`, `martingale`, `grid`, `scalping`. **No new flags invented in V5** — if a strategy doesn't fit the vocabulary, raise it with CEO before adding to the list.
- **`framework_alignment` section** — which 4-Module hooks the strategy uses (`Strategy_NoTrade`, `Strategy_EntrySignal`, `Strategy_ManageOpenPosition`, `Strategy_ExitSignal`) and which V5 Hard Rules are at risk (e.g., Friday-Close, ML-ban, gridding 1%-cap fallback). CTO fills this in at the APPROVED → IN_BUILD transition.

Cards land in `DRAFT` status, advance to `IN_REVIEW` (Research → CEO), then `APPROVED` (CEO sign-off, CTO framework-alignment block filled), then `IN_BUILD` (handoff to Development / CTO). See template § Card Header for the full status ladder.

## Strategy lineage = Source linkage (binding)

Two distinct enhancement paths — choose by *where the new insight came from*:

- **New insight from a DIFFERENT source.** This is a new strategy, not an enhancement. Open a new sub-issue under the *new* source's parent. New `strategy_id`, new card file, new pipeline run from P1. Cross-reference the prior strategy in the new card's `framework_alignment` section.
- **New insight from in-pipeline learning on the SAME source's strategy.** This is a `_v2` of the same `strategy_id`. Same card file, new row in the card's § 13 Pipeline History table, new file version (`<slug>_card.md` stays the canonical path; the EA build versions as `_v2`, `_v3`, ...). The `_v2` is treated as a NEW EA for backtesting purposes — it re-runs the full P1 → P8 pipeline from scratch. See [14-ea-enhancement-loop.md](14-ea-enhancement-loop.md) for the version mechanics.

The test is "where did the insight come from?", not "does the new EA look similar to the old one?" Same source = `_v2`; different source = new card.

## Steps

```mermaid
flowchart TD
    NOM[Research nominates source<br/>CEO ratifies] --> PARENT[CEO opens SRC&ltNN&gt parent issue]
    PARENT --> EXTRACT[Research extracts strategies<br/>one source at a time]
    EXTRACT --> CARDS[One Strategy Card per strategy<br/>strategy-seeds/cards/&ltslug&gt_card.md]
    CARDS --> SUBS[CEO opens SRC&ltNN&gt_S1..Sn sub-issues<br/>S1=todo, S2..Sn=blocked]
    SUBS --> S1[S1 enters L1/L2/L3<br/>per 01-ea-lifecycle.md]
    S1 --> P1P8[Pipeline P1..P8<br/>via 15-pipeline-op-load-balancing.md]
    P1P8 -->|ready-or-killed verdict| S1CLOSE[S1 closes]
    S1CLOSE --> UNBLOCK[Doc-KM unblocks S2]
    UNBLOCK --> S2[S2 enters L1/L2/L3]
    S2 -.->|repeat for S3..Sn| SN[All sub-issues close]
    SN --> PARENTCLOSE[Parent SRC&ltNN&gt closes]
    PARENTCLOSE --> NEXTSRC[Research nominates next source]
    P1P8 -->|zero trades / re-test fail| ENH[14-ea-enhancement-loop.md<br/>same card, _v2 build]
    ENH --> P1P8
```

### Per-step responsibilities

1. **Source nomination.** Research proposes one source from the seed queue. CEO approves in writing (issue comment) before extraction starts. Drop-path conventions live in each source's `strategy-seeds/sources/SRC<NN>/source.md`.
2. **Parent issue.** CEO opens `SRC<NN> — <citation>`. Description includes: source identity block, expected number of strategies (best estimate from TOC scan), v0 filter rules. Parent assignee = Research; CEO is reviewer.
3. **Extraction.** Research reads the source end-to-end, produces one card per distinct strategy at `strategy-seeds/cards/<slug>_card.md`. Per-chapter (or per-section) progress comments on the parent issue. Verbatim author-claims with page/timestamp citations — no paraphrased numbers.
4. **Card review.** CEO reviews each card. APPROVE / REJECT / REQUEST_CHANGES. APPROVE moves the card from `DRAFT` → `APPROVED`. CTO fills the `framework_alignment` block at APPROVE.
5. **Sub-issue dispatch.** Once Research closes extraction (or finishes a batch CEO is willing to start), CEO opens `SRC<NN>_S1..S<n>` sub-issues — S1 `todo`, the rest `blocked`. Sub-issue assignee progression follows [01-ea-lifecycle.md](01-ea-lifecycle.md): Development → Pipeline-Operator → Quality-Tech.
6. **Pipeline run.** Pipeline-Operator dispatches P1..P8 across T1-T5 per [15-pipeline-op-load-balancing.md](15-pipeline-op-load-balancing.md). Quality-Tech (or interim CTO) signs each gate.
7. **Verdict.** Either the strategy reaches L5 (V-Portfolio candidate) or it's killed at a gate. Either is a "verdict"; both close the sub-issue.
8. **Unblock next.** Documentation-KM (or whichever agent is watching the parent issue) flips S<n+1> from `blocked` to `todo` immediately after S<n> closes. Append a one-line comment to the parent: `S<n> closed (verdict=<ready|killed at P<X>>); S<n+1> unblocked.`
9. **Parent close.** When all sub-issues close, CEO closes the parent and Research nominates the next source. **Permissive variant (Path B, 2026-05-01 — DL-029 amendment, [QUA-623](/QUA/issues/QUA-623) / [QUA-635](/QUA/issues/QUA-635)):** the parent MAY also close `done` at G0 ratification (extraction approved, all sub-issues queued for downstream pipeline) without waiting for every sub-issue to close. Sub-issues remain alive in their own dispatch queue and are NOT blocked by parent closure.

> **Note on `blockedByIssueIds`.** Strategy sub-issues created in the SRC0N family (one per APPROVED Path 1 strategy card) are sequenced by **status**, not by blocker edges. The first sub-issue is `todo`, the rest are `blocked`. Empty `blockedByIssueIds` on `blocked` sub-issues is **expected and correct** — Pipeline-Operator promotes the next-in-line to `todo` when the prior one completes (per step 8 above). Audits that flag empty `blockedByIssueIds` as a defect on these cards are tripping on a non-violation. Authority: DL-029 § Path B clarification (2026-05-01), CEO sign-off on QUA-623, recorded under QUA-635.

## Exits

- **Success (sub-issue):** Strategy reaches L5 candidate or is killed with a documented gate verdict. Sub-issue closes; next sibling unblocks.
- **Success (parent):** All sub-issues closed. Source's `completion_report.md` committed (per `strategy-seeds/sources/SRC<NN>/source.md` § 7).
- **Escalation:** Research blocked on missing source text → mark sub-issue `blocked` and name OWNER as unblock-owner with the drop path. Card schema gap (a real strategy doesn't fit the controlled vocabulary or template) → escalate to CEO + CTO before forcing a fit.
- **Kill (sub-issue):** Pipeline gate fail at any of P2..P8, or zero-trades not recoverable via the [enhancement loop](14-ea-enhancement-loop.md). Verdict + evidence path captured in the card's § 13 Pipeline History.

## SLA

- **Source nomination → parent open:** within 1 business day of CEO ratification.
- **Extraction:** Research-paced; per-chapter progress comment cadence on the parent issue.
- **Card review (CEO):** within 2 business days of card landing in `IN_REVIEW`.
- **Sub-issue unblock latency:** within 1 hour of the prior sub-issue closing (Doc-KM watches the parent).
- **Parent close → next source nomination:** within 1 business day.

## Hard rules (do not break)

- One source actively worked at a time. One strategy from that source actively worked at a time. No parallel-source extraction.
- No new strategy types invented in V5 — controlled vocabulary mined from V4 first (`strategy-seeds/strategy_type_flags.md`).
- No card lands in `IN_REVIEW` without verbatim author-claims with page/timestamp citations.
- No EA enters L2 build without an APPROVED card.
- Sub-issue blocking convention is enforced — Doc-KM unblocks; Pipeline-Op does not pull blocked sub-issues even if a terminal is idle.
- Same-source enhancement = `_v2` (same card). Different-source enhancement = new card. The test is *where the insight came from*, not how similar the EA looks.

## References

- **Parent directive:** [QUA-236](/QUA/issues/QUA-236) (OWNER 2026-04-27 ~14:30 local)
- **EA Life-Cycle (downstream of card APPROVED):** [01-ea-lifecycle.md](01-ea-lifecycle.md)
- **Enhancement loop (`_v2` mechanics):** [14-ea-enhancement-loop.md](14-ea-enhancement-loop.md)
- **Pipeline-Op load balancing across T1-T5:** [15-pipeline-op-load-balancing.md](15-pipeline-op-load-balancing.md)
- **Strategy Card template:** [`strategy-seeds/cards/_TEMPLATE.md`](../strategy-seeds/cards/_TEMPLATE.md)
- **Controlled vocabulary (V4 mining):** [`strategy-seeds/strategy_type_flags.md`](../strategy-seeds/strategy_type_flags.md)
- **Source header convention:** `strategy-seeds/sources/SRC<NN>/source.md` (e.g. [SRC01](../strategy-seeds/sources/SRC01/source.md))
- **Research role scope (CORE RULE — one source at a time):** [`paperclip-prompts/research.md`](../paperclip-prompts/research.md)
- **Methodological pipeline (G0..P10):** [`docs/ops/PIPELINE_PHASE_SPEC.md`](../docs/ops/PIPELINE_PHASE_SPEC.md)
- **DL ratification of this workflow:** `decisions/2026-04-27_strategy_research_workflow.md` (CEO authors under QUA-247)
- **Process registry:** [`process_registry.md`](process_registry.md)
