---
name: DL-033 — No Strategy-Level Prioritization + Canonical Lifecycle
description: OWNER addendum 2026-04-27 ~20:00 local — Research extracts every distinct mechanical strategy in a source (no tiering, no quality-pre-judgment); the pipeline gates are the filter. Every passing-G0 card walks the canonical lifecycle Research → Strategy Built → Pipeline Backtest → Ready for Portfolio (or not). Source-level tiering and V5 hard-rule extraction filters still apply.
type: decision-log
---

# DL-033 — No Strategy-Level Prioritization + Canonical Lifecycle

Date: 2026-04-27
Source directive: OWNER conversation, 2026-04-27 ~20:00 local (relayed by Board Advisor on QUA-236, comment `95ea3bde-1e15-40dd-b05c-d7f09411383f`).
Ratifying issue: [QUA-236](/QUA/issues/QUA-236)
Recording issue (this entry): [QUA-272](/QUA/issues/QUA-272)
Owner: CEO (`7795b4b0-8ecd-46da-ab22-06def7c8fa2d`)
Recorder: Documentation-KM (`8c85f83f-db7e-4414-8b85-aa558987a13e`)
Supersedes: any V4-era prioritization language that ranked strategies pre-pipeline based on Research's prior beliefs about which ideas "feel promising".
Status: Active. Additive to DL-029 (research workflow), DL-025 (T6 boundary), DL-030 (execution policies).

> **Recorder's note (Doc-KM scope per BASIS).** This DL canonicalizes the binding rule statement appended to `processes/13-strategy-research.md`, `processes/14-ea-enhancement-loop.md`, and `processes/01-ea-lifecycle.md` under QUA-272. Doc-KM is recording, not interpreting. Process files are the operational source of record; this DL is the at-a-glance ADR for cross-reference and CEO sign-off trail.

> **DL-NNN-collision note.** QUA-272's title preallocates this entry as **DL-032**. While QUA-272 was in the queue, a parallel CEO workflow committed `decisions/2026-04-27_ceo_autonomy_waiver_v3.md` to `main` as **DL-032** (commit `a3e0390`, recording task QUA-273). Per the registry convention "skipped numbers are intentional gaps; do not reuse" and the "max(existing) + 1" allocation rule, this DL therefore lands as **DL-033**. CEO is asked to update QUA-272's title to reflect the new number on next heartbeat; the work product itself is unchanged.

## Decision

OWNER directive 2026-04-27 ~20:00 local, verbatim:

1. *"there also has to be no priorization, in the end every strategy has to be tested!"*
2. *"Research → Strategy Built → Pipeline Backtest → Ready for Portfolio (or not)."*

These are codified as two binding rules over the V5 research-to-portfolio arc, additive to the workflow ratified under DL-029.

### Rule statement

1. **No strategy-level prioritization within a source.** Within a source, Research extracts **every distinct mechanical strategy that passes V5 hard rules**. No tiering, no quality-pre-judgment, no "skip the weaker ones to save tokens". The pipeline gates are the filter. If a source contains 12 distinct mechanical strategies that pass V5 hard rules, Research produces 12 Strategy Cards. Period. The pipeline kills the weak ones at G0 (mechanical-only check), at P2 (PF / DD / trade-count gate), at P3.5 (cross-sectional robustness), at P7 (PBO < 5% hard gate), or wherever they fail.

2. **Canonical lifecycle (every G0-passing card walks this path).**

   ```
   Research → Strategy Built → Pipeline Backtest → Ready for Portfolio (or not)
   ```

   In V5 terms:

   | OWNER label | V5 phase set | Owner |
   |---|---|---|
   | **Research** | G0 Research Intake — Strategy Card authored, source-cited, V5-hard-rule-passing | Research → CEO + Quality-Business approval (CEO interim) |
   | **Strategy Built** | P1 Build Validation — Development copies `EA_Skeleton.mq5`, fills in 4 modules, compiles strict | Development *(Wave 2)* → CTO review (CTO interim) |
   | **Pipeline Backtest** | P2 → P3 → P3.5 → P4 → P5 → P5b → P5c (optional) → P6 → P7 → P8 | Pipeline-Operator runs, Quality-Tech reviews verdicts (CTO interim) |
   | **Ready for Portfolio (or not)** | P9 Portfolio Construction + P9b Operational Readiness | OWNER (manual phases per `PIPELINE_PHASE_SPEC.md`) |
   | *(Live)* | P10 Live Burn-In on T6 (DXZ) — minimum lot, KS-test kill-switch | OWNER manifest approval per `LIVE_T6_AUTOMATION_RUNBOOK.md` |

   Every Strategy Card that passes G0 walks all the way through P9 / P9b. The portfolio decision is made AT THE END based on backtest evidence + portfolio constraints, NOT pre-filtered at Research's desk.

3. **Zero-trades = `_v2` enhancement loop is part of the canonical lifecycle, not a deviation from it.** Reaffirming for completeness (already ratified under DL-029 / QUA-245). Pipeline failure that points to the EA implementation rather than the strategy concept (zero-trades, input-rule change, parameter-set change beyond sweep, news-mode change) returns to Development as `_v<n>`. Same Strategy Card lineage; new row in § 13 Pipeline History; full P1 → P8 from scratch on the new build. See [`processes/14-ea-enhancement-loop.md`](../processes/14-ea-enhancement-loop.md) § Trigger.

### What still applies (not changed)

- **Source-level tiering.** A/B/C/D source quality + which source CEO picks NEXT remain CEO's call (per QUA-188 v3 waiver and `strategy-seeds/SOURCE_QUEUE.md`). Source-level prioritization is about *order of extraction* across sources, not *which strategies* inside a chosen source get extracted.
- **V5 hard-rule extraction filters.** Not prioritization — these are V5 boundary constraints. Research enforces hard rules at extraction (no ML, no discretionary, no martingale without 1%-cap fallback, no scalping without acknowledged P5b stress requirement, no paywall bypass). Hard-rule failures are not "deprioritized strategies"; they are out-of-V5-scope concepts and produce no card.
- **Author-claim quoting verbatim** per `paperclip-prompts/research.md` § ANTI-PATTERNS.
- **Citation precision** per the multi-citation `source_citations[]` schema in [`strategy-seeds/cards/_TEMPLATE.md`](../strategy-seeds/cards/_TEMPLATE.md).
- **Sub-issue blocking convention** per DL-029: ONE source actively worked at a time, ONE strategy from that source actively worked at a time. No parallel-source extraction. The "every strategy → pipeline" rule does not authorise parallelism — it expands the *count* of cards Research produces, not the *concurrency* of pipeline runs.
- **DL-030 Execution Policies.** Strategy Card review remains Review-only (CEO interim → QB Wave 2); `_v[0-9]+` EA enhancement remains Review-only (CTO interim → QT Wave 2); T6 deploy remains OWNER Approval-only.

### Scope

- **In scope:** any research-to-live arc starting from a book / paper / blog / video / forum-post source. Applies to V5 from 2026-04-27 forward.
- **Out of scope:** T6 live operations (separate boundary per DL-025); V4 archive mining as a research output (V4 archives are a *source* for taxonomy, not a target for new extraction).
- **Out of scope:** any "shadow extraction" of a strategy variant Research deems weak — if it passes V5 hard rules, it gets a card and walks the canonical lifecycle. If it fails V5 hard rules, it produces no card (and is not "deprioritized" — it's out of V5 scope entirely).

## Implication for Research's current heartbeat

When SRC01 (currently scaffolded for Adam Grimes blog per QUA-191 pivot, with Davey *Building Winning Algorithmic Trading Systems* queued behind) opens via CEO autonomous dispatch:

- Research extracts **every** distinct mechanical strategy in the source that passes V5 hard rules.
- Each becomes one card under `strategy-seeds/cards/<slug>_card.md`.
- No "this one's weak, skip it" judgment calls — the pipeline is the judge.
- Submit ALL extracted cards to CEO + Quality-Business (CEO interim) for G0 ratification.

If the source contains 8 mechanical strategies passing V5 hard rules, that's 8 Strategy Cards, 8 sub-issues under the parent `SRC<NN>` per DL-029, all `blocked` except the first per the sub-issue blocking convention, all walking the canonical lifecycle.

## Authority basis

DL-023 § Broadened CEO authority class 4 (internal process choices → research workflow rules). OWNER ratified the directive directly on 2026-04-27 ~20:00 local; CEO records under DL-023 authority. Additive to DL-029 (does not modify the workflow shape — only the extraction-discipline rule and the canonical-lifecycle phrasing).

## Operational artifacts (committed under QUA-272)

- `processes/13-strategy-research.md` — § Extraction Discipline appended with Rule 1 (no strategy-level prioritization) + Rule 2 (canonical lifecycle table).
- `processes/14-ea-enhancement-loop.md` — § References / § Trigger cross-link added: zero-trades / `_v<n>` flow is part of the canonical lifecycle, not a deviation.
- `processes/01-ea-lifecycle.md` — V4-era prioritization language replaced; canonical-lifecycle mapping table added; explicit statement that L0..L5 funnel selection happens at pipeline gates, not at Research extraction.
- `decisions/REGISTRY.md` — DL-033 row + cross-links to DL-023, DL-025, DL-029, DL-030.

## Cross-links

- **DL-023 ↔ DL-033.** DL-033 is the next concrete process change recorded under the DL-023 broadened-authority waiver (class 4: internal process choices → research extraction discipline + canonical-lifecycle phrasing). DL-033 cites DL-023 as its authority basis.
- **DL-025 ↔ DL-033.** DL-033 explicitly carries forward DL-025's T6 boundary — the canonical lifecycle's "Live" leg (P10) remains DXZ-only and OWNER-gated; the "Ready for Portfolio (or not)" verdict in DL-033 does not authorise live deploy on its own.
- **DL-029 ↔ DL-033.** DL-033 is additive to DL-029. DL-029 fixes the *workflow shape* (issue tree, card discipline, lineage, T1-T5 load balancing); DL-033 fixes the *extraction discipline* within that shape (every strategy → pipeline) and the *canonical lifecycle phrasing* (Research → Built → Backtest → Ready). Read together they describe the full V5 research-to-portfolio arc.
- **DL-030 ↔ DL-033.** DL-030's execution-policy interceptions (Strategy Card Review-only, `_v[0-9]+` Review-only, T6 Approval-only) implement the runtime gates that DL-033's canonical lifecycle relies on — Research cannot self-close G0; Pipeline-Op cannot self-close enhancement loops; nobody can self-close T6. DL-033 names *what every card walks through*; DL-030 names *what stops self-closure at each step*.
- **QUA-236 ↔ DL-033.** Forward link: QUA-236 → DL-033 (recorded via QUA-272). Reverse link: this file cites QUA-236 as the parent ratifying directive. The OWNER comment is `95ea3bde-1e15-40dd-b05c-d7f09411383f` on the QUA-236 thread.
- **QUA-272 ↔ DL-033.** Forward link: QUA-272 → DL-033 (this file is the recording artifact). Reverse link: QUA-272 cites this DL as its deliverable.

## Wave 2 hire trigger (no change)

DL-029's trigger remains in force: **first Strategy Card written under the new `_TEMPLATE.md` schema** (i.e., populated `source_citations`, `strategy_type_flags`, `framework_alignment`) is the gate to Quality-Tech / Development / Quality-Business hires. DL-033 does not add or remove a trigger — it only changes Research's *extraction discipline* and the *canonical-lifecycle phrasing* used in process docs.
