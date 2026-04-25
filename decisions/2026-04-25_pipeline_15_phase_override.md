# Decision: Override Notion 10-phase pipeline with laptop 15-phase canonical model

- Date: 2026-04-25
- Status: accepted
- Owner: OWNER (board) + Claude Board Advisor
- Affected docs: `docs/ops/PIPELINE_AUTONOMY_MODEL.md`, `docs/ops/PIPELINE_PHASE_SPEC.md`

## Context

Two competing pipeline specs existed:

1. **Notion `V5 Pipeline Design` (Codex final pass, 2026-04-22)** — 10 phases:
   `Strategy Card → P1 Smoke → P2 Baseline → P3 Optimization → P4 Selection → P5 Walk-Forward → P6 Robustness → P7 Live Candidate → P8 DarwinexZero Demo (30-day) → P9 Live → P10 Portfolio Monitor`.
   This page was signed off by Codex as the V5 final spec.
2. **Laptop `doc/pipeline-v2-1-detailed.md`** — 15 phases:
   `G0, P1, P2, P3, P3.5, P4, P5, P5b, P5c, P6, P7, P8 News Impact, P9 Portfolio Construction, P9b Operational Readiness, P10 Shadow Deploy → Live`.
   Reflects V2.1 additive gates (P3.5, P5b) and the actual deploy / shadow / live promotion path.

The Notion 10-phase page omits the V2.1 additive gates, collapses the entire Davey/Prado robustness stack into a single one-liner, mislabels P8 as a 30-day demo holding pen, and treats P10 as continuous monitoring rather than a 2-week shadow deploy with a kill-switch.

OWNER confirmed on 2026-04-25 that the laptop spec is the real intended pipeline and that the Notion page was a stale simplification. The `Canonical Laptop State Reconstruction — 2026-04-25` page (laptop, mirrored to `docs/ops/CANONICAL_LAPTOP_STATE_2026-04-25.md`) explicitly documents the same correction.

## Decision

The 15-phase laptop spine (G0..P10) is the canonical V5 pipeline. The Notion 10-phase page is superseded.

`docs/ops/PIPELINE_PHASE_SPEC.md` is created as the VPS-side authoritative spec, sourced from the laptop `doc/pipeline-v2-1-detailed.md`. `docs/ops/PIPELINE_AUTONOMY_MODEL.md` is rewritten to reference the new spec and to drop the obsolete 10-phase outline.

## Alternatives Considered

- **Keep Notion as canonical, drop laptop.** Rejected. The Notion page is materially less complete and contradicts the actual artifacts in `Company/Results/` (P5b, P6, P8, V5 composition lock, risk review).
- **Merge: keep 10-phase outline, fold V2.1 gates as sub-gates.** Rejected. The V2.1 gates are designed as standalone phases with their own evidence; collapsing them again would lose the audit boundary that the artifacts already use.
- **Hybrid: keep P8 = 30-day demo, add news as a separate phase.** Rejected. There is no canonical 30-day demo phase on the laptop. The actual deploy model is shadow-then-live, not demo-as-permanent-state.

## Consequences

- The Notion `V5 Pipeline Design` page must be updated or marked superseded. Documentation-KM owns that follow-up.
- All references in `docs/ops/*.md` that listed the 10-phase outline have been updated.
- Phase 0 Execution Board needs new workstreams to migrate the process registry and tools that the richer pipeline depends on (P0-21..P0-25, see `docs/ops/PHASE0_EXECUTION_BOARD.md`).
- Locked V5 composition (`SM_124, SM_221, SM_345, SM_157, SM_640`) is at the P9 / P9b boundary with documented open waivers; this is captured in `strategy-seeds/v5_locked_basket_2026-04-18.md`.
- News-rule-set compliance variants (FTMO / The5ers / no-news / news-only) are **not** in the canonical P8 spec. Tracked separately as `decisions/2026-04-25_news_compliance_variants_TBD.md`.

## Sources

- `docs/ops/CANONICAL_LAPTOP_STATE_2026-04-25.md`
- `docs/ops/PIPELINE_PHASE_SPEC.md`
- Laptop: `G:\My Drive\QuantMechanica\doc\pipeline-v2-1-detailed.md`
- Notion: `V5 Pipeline Design` (id `34947da5-8f4a-8192-bbeb-c65eaacb0949`)
- Notion: `Canonical Laptop State Reconstruction — 2026-04-25` (id `34d47da5-8f4a-812b-8d21-de4f57e63c5c`)
