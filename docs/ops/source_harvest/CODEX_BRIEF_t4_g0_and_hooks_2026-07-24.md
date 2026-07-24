# Codex brief — Tranche 4 G0 review + hook implementation (20107/20108/20109)

Same two-part protocol as tranches 2/3.

## Part A — G0 review (reciprocal; builder=claude)

Cards (D:\QM\strategy_farm\artifacts\cards_review\):
- QM5_20107_asian-range-straddle-m15_card.md   (STR-016)
- QM5_20108_ema144-displaced-breach-m5_card.md (STR-024)
- QM5_20109_vr-gap-fade-d1_card.md             (STR-027)

Verify against 00_source.md + 03_reconciliation.md + 04_spec_final.md.
Reconciliation outcomes to accept/contest: broker-clock over your fixed-UTC
(20107; seasonal-server argument); your cohort (20108) and your provisional
defaults (20109) ADOPTED; at-entry-SL house deviation (20109); your
no-one-sided-straddle rule ADOPTED (20107). Verdict per card: APPROVE (edit
g0_status + reasoning) or REJECT. Deliver G0_REVIEW_T4.md.

## Part B — Hooks (approved only)

Deliver hooks_QM5_20107/20108/20109.mq5.txt per 04_spec_final. Binding
conventions as before (no QM_IsNewBar in hooks; ZeroMemory+symbol_slot;
closed-bar discipline; perf-allowed markers; registered events; fleet hook
placement). 20107 two-phase straddle placement via EntrySignal state
machine (one request per call); pending expiration_seconds to the cancel
clock. 20109 Manage = deferred-TP attach with attained-target close +
per-bar retry latch (QM5_20098 pattern; see its Manage hook for reference —
reading QM5_20098 source IS allowed in this phase).
Constraints: read-only repo; deliverables only.
