# Codex brief — Tranche 5 G0 review + hook implementation (20111/20112/20113)

Same two-part protocol as tranches 2-4.

## Part A — G0 review (reciprocal; builder=claude)

Cards (D:\QM\strategy_farm\artifacts\cards_review\):
- QM5_20111_london-box-fib-straddle_card.md  (STR-035)
- QM5_20112_ema9-pullback-m15_card.md        (STR-036)
- QM5_20113_ema369-cross-m5_card.md          (STR-038)

Verify vs 00_source.md + 03_reconciliation.md + 04_spec_final.md.
Adopted from your blind specs: option A + cap 40 + 0.326 midpoint (20111);
rolling-candidate machine (20112); 10-pip TP + no-same-evaluation-reversal
(20113). Verdict per card: APPROVE (edit frontmatter) or REJECT. Deliver
G0_REVIEW_T5.md.

## Part B — Hooks (approved only)

hooks_QM5_20111/20112/20113.mq5.txt per 04_spec_final. Binding conventions
as before. 20111: two-phase straddle placement (20107 pattern; that source
IS readable in this phase), UTC via QM_BrokerToUTC, opposite-pending delete
on fill, box-reset flatten. 20112: rolling-candidate state machine with
replay-based restart. 20113: ExitSignal opposite-cross level condition,
bar-gated. Read-only repo; deliverables only.
