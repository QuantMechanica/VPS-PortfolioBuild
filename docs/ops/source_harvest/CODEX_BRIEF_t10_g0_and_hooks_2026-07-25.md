# Codex brief — Tranche 10 G0 review + hooks (20129/20130/20131)

Same two-part protocol. Factory OFF — no terminals; manual dispatch.

## Part A — G0 review (reciprocal; builder=claude)

Cards (D:\QM\strategy_farm\artifacts\cards_review\):
- QM5_20129_ema-rsi-cci-h1_card.md  (STR-075; convergent)
- QM5_20130_channel-ma-m15_card.md  (STR-079; your reverse-through-
  workflow adopted; SL 40 chosen over your 50 — delayed-threshold
  coherence, risk-neutral under RISK_FIXED — verify you accept)
- QM5_20131_wick-latest-h1_card.md  (STR-082; your latest-signal
  projection adopted)

Verify vs 00_source.md + 03_reconciliation.md + 04_spec_final.md.
Verdicts: APPROVE (edit frontmatter yourself) or REJECT. Deliver
G0_REVIEW_T10.md to D:\QM\reports\source_harvest_build\.

## Part B — Hooks (approved only)

hooks_QM5_20129/20130/20131.mq5.txt per 04_spec_final. Binding
conventions as tranches 2-9 (artifact-header wiring flag if needed; no
QM_IsNewBar in hooks; inline perf-allowed markers; registered events;
fleet hook placement; retry latches). 20130: delayed-pending refresh
lifecycle in Manage (refresh to current EMA33 per closed bar while the
signal holds; cancel on invalidation; gap checks); reverse = signal
state persists into the normal entry path after the ExitSignal close.
20131: ExitSignal = opposite-desired close, entry next evaluation.
