# Codex brief — Tranche 7 G0 review + hooks (20118/20119/20120)

Same two-part protocol as tranches 2-6.

## Part A — G0 review (reciprocal; builder=claude)

Cards (D:\QM\strategy_farm\artifacts\cards_review\):
- QM5_20118_dtrt-cci-h1_card.md          (STR-049)
- QM5_20119_macd50-ukgrid-gbpusd_card.md (STR-051)
- QM5_20120_simple-daily-3rise_card.md   (STR-058)

Verify vs 00_source.md + 03_reconciliation.md + 04_spec_final.md. YOUR
blind-spec resolutions won the decisive conflicts (STR-058 no-indicator
relative-candle baseline; STR-051 UK-grid custom bars) — confirm the final
mechanizations, especially the in-EA UK-DST calendar helper patterned on
QM_DSTAware and the fixed-seed custom-bar MACD recursion. Verdicts:
APPROVE (edit frontmatter) or REJECT. Deliver G0_REVIEW_T7.md.

## Part B — Hooks (approved only)

hooks_QM5_20118/20119/20120.mq5.txt per 04_spec_final. Binding conventions
as before (no QM_IsNewBar in hooks; ZeroMemory+symbol_slot; closed-bar
reads; perf-allowed markers inline ON the flagged CopyRates/CopyBuffer
line; registered events; fleet hook placement; netted half-close via
QM_TM_PartialClose with initial-volume tracking + per-bar retry latch —
see QM5_20101 Manage for the reference pattern, readable in this phase).
20119: custom UK 4h aggregation from closed M15 CopyRates, London-offset
helper (last-Sunday-March/October, 01:00 UTC transitions; cite
QM_DSTAware's US pattern), manual EMA(5)/EMA(13) recursion with 240-bar
fixed seed, per-M15-bar cache. Read-only repo; deliverables only.
