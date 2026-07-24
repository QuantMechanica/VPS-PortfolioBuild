# Codex brief — Tranche 6 G0 review + hooks (20114/20116; 20115 CANCELLED)

NOTE: STR-042/QM5_20115 was resolved as a rule-identical duplicate of
QM5_9999 in the 2026-07-24 bulk duplicate audit
(docs/ops/evidence/2026-07-24_harvest_ledger_duplicate_bulk_audit.md);
ea_id 20115 retired unused. This tranche builds TWO EAs.

## Part A — G0 review (reciprocal; builder=claude)

Cards (D:\QM\strategy_farm\artifacts\cards_review\):
- QM5_20114_h4-engulf-sma50-stop_card.md (STR-040)
- QM5_20116_ema512-rsi7-m15_card.md      (STR-044; rebuild vs QM5_9701
  justified by its invented spread/session filters — verify you accept)

Verify vs 00_source.md + 03_reconciliation.md + 04_spec_final.md. Also
review the bulk-audit evidence doc and CONTEST any of the 9 duplicate
resolutions or 6 suspect flags you find wrong (your independent check is
the review function here). Verdicts: APPROVE (edit frontmatter) or REJECT.
Deliver G0_REVIEW_T6.md.

## Part B — Hooks (approved only)

hooks_QM5_20114.mq5.txt / hooks_QM5_20116.mq5.txt per 04_spec_final.
Binding conventions as tranches 2-5. 20114: pending lifecycle in Manage
(cancel on exit-condition/opposite setup, refresh on new setup, no gap
chase), ExitSignal = SMA-cross close. Read-only; deliverables only.
