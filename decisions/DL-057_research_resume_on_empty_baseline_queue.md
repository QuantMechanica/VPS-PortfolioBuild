# DL-057 — Research resume gate amend: empty baseline queue, not first-EA-at-P7

**Date:** 2026-05-01
**Authority:** OWNER directive 2026-05-01 (verbal, via Board Advisor); supersedes DL-044's resume condition; preserves DL-044 sequential-discipline framing.
**Originating evidence:** OWNER message 2026-05-01 ~14:30 UTC: *"Research can only be paused as long as no EA is queued for Baseline test. When we programmed all EAs and run baseline tests and finished, Research starts again. We get a lot of small researches with some EAs (of course we check for not doubling EAs because it is the same strategy or parameters) and then backtest them and see how far it takes us. This is always 1 run!"*

## Decision

The Research-pause resume condition originally set by **DL-044** ("first V5 EA reaches Phase 7") is **AMENDED** to:

> Research resumes when **no EA is queued for baseline test (P0..P2)** AND no EA is currently mid-baseline. Research extracts a small batch of new Strategy Cards, the cards become EAs (Development), the EAs run baseline tests, and on baseline-queue-empty Research wakes again. Iterate.

This is a **much earlier resume** than DL-044's "first V5 EA reaches P7" — the original gate was milestone-gated; the new gate is queue-empty-gated.

## Why amend

DL-044's milestone gate was set when no V5 EA had ever entered the pipeline. The fear was Research would extract too many cards and Phase 3 would jam. Today we know:

1. The V5 framework is built and tested; Phase 3 plumbing is ready.
2. The baseline run takes hours, not days — queue-empty events are frequent.
3. Card-to-EA throughput needs **continuous fuel**, not a 3+ week milestone bottleneck.
4. OWNER's mental model: small research batches → EAs → baseline → see what passes → next batch. Not one giant push to P7.

## Binding rules

**R-057-1 (resume condition).** Research is **paused** while ANY of these is true:

- ≥1 EA is in P0/P1/P2 (build/preflight/baseline) state.
- ≥1 EA matrix is mid-run on T1-T5.
- A Strategy Card is in G0 review and unresolved.

Research **resumes** when ALL three are false.

**R-057-2 (extraction batch size).** When Research wakes, it extracts a **small batch** of cards from the current source — not the entire source. Default: 1 SRC at a time per DL-040 sequential discipline; within that SRC, ≤3 cards per resume cycle. CEO may override per cycle.

**R-057-3 (dedup gate, binding).** Before any new card is APPROVED for ea_id allocation, **Research + Quality-Business check for duplication** against:

- `framework/registry/ea_id_registry.csv` — same `slug` or `strategy_id` already exists.
- `framework/registry/magic_numbers.csv` — same `(ea_id, symbol_slot)` already deployed.
- Existing Strategy Card content — same author + same strategy mechanic + same parameter family is a duplicate, not a new card.

Duplicates do NOT get a new ea_id. They get linked back to the existing EA as `_v<n>` enhancement per DL-029 / DL-033.

**R-057-4 (single-run discipline preserved).** "This is always 1 run" — only ONE baseline matrix runs at a time per DL-040 single-strategy-active rule. Multiple EAs can be **queued** but only one runs at a time on T1-T5. Pipeline-Op processes the queue serially.

**R-057-5 (Research is wake-on-baseline-queue-empty, not heartbeat).** Research's heartbeat stays disabled or low-cadence. CEO (or Pipeline-Op via callback) wakes Research with a comment on Research's rolling tracker when the baseline queue empties. This avoids speculative extraction.

## Operational sequence (binding)

```
Research extracts 1-3 cards from current SRC
  ↓
QB G0 review (DL-030 Class 2) + dedup check (R-057-3)
  ↓
For each APPROVED card: ea_id allocation + magic_numbers row (CEO+CTO)
  ↓
Development builds EA (writes MQL5, gen_setfile, compile)
  ↓
CTO Review per DL-036 EA Review Gate
  ↓
Pipeline-Op P0/P1 preflight, then P2 baseline (single-EA-at-a-time per DL-040)
  ↓
P2 finishes → DL-054 5-gate enforcement → INVALID/PASS/FAIL/ZERO_TRADE
  ↓
If PASS: queue advance to P3 (sweep). If INVALID/FAIL: log, retire or fix-and-retry.
  ↓
Baseline queue empty (R-057-1) → wake Research → next batch
```

## Boundaries (preserved)

- **DL-029 sequential discipline** — workflow shape unchanged (per-resource issue tree, _v<n> enhancement loop).
- **DL-038 Seven Binding Backtest Rules** — `.DWX`-only / 36-symbol matrix / RISK_FIXED / etc. unchanged.
- **DL-040 single-SRC, single-strategy** — preserved by R-057-4.
- **DL-043 Phase B** — gating remains "first V5 EA reaches P7" for capacity additions (Issues 2-5). DL-057 only changes the **Research** resume gate, not the Phase B reboot-plan gate.
- **DL-054 anti-theater pass criteria** — applies to every baseline run.
- **Charter values, hard rules, T6 isolation** — unchanged.

## What this DL does NOT do

- Does NOT advance Phase 3 ignition. The first V5 EA flow proof (`QM5_1003` baseline) is independent of Research resume.
- Does NOT unblock 9 SRC04 Lien strategy cards parked behind their build queues per DL-044 — those still wait their turn through R-057-4 single-run discipline.
- Does NOT allow parallel SRC extraction; one SRC at a time per DL-040.

## Implementation pointers

- Wake mechanism: Pipeline-Op posts a wake comment on Research's rolling tracker (or CEO does) when `(active_p0_p1_p2_count == 0) AND (g0_review_pending == 0)` flips to true.
- The condition above is computable from Paperclip API: list issues with `phase ∈ {P0, P1, P2}` AND `status ∈ {in_progress, todo}`. CTO codifies the query.
- A new lessons-learned cycle update in `processes/01-ea-lifecycle.md` should reflect the queue-empty-resume rule (Doc-KM follow-up, low priority).

## Cross-references

- DL-029 — strategy research workflow (workflow shape preserved)
- DL-030 — execution policies / Strategy Card Review-only (G0 gate preserved)
- DL-033 — no strategy-level prioritization, canonical lifecycle (preserved)
- DL-036 — EA Review Gate (preserved)
- DL-038 — Seven Binding Backtest Rules (preserved)
- DL-040 — sequential operating model (preserved by R-057-4)
- DL-043 — Reboot Plan Phase B gate (different gate, unchanged)
- DL-044 — original Research-pause + first-EA-P7 gate (resume condition AMENDED here)
- DL-054 — anti-theater pass criteria (gates the P2 baseline output)
- QUA-660 D5 — backfill exception for Strategy Cards (already in flight)
- `processes/01-ea-lifecycle.md` — operator-facing process spec (Doc-KM updates next cycle)

— Authored by Board Advisor at OWNER explicit directive, 2026-05-01.
