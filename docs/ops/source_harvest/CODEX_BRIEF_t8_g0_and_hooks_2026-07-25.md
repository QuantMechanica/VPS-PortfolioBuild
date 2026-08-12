# Codex brief — Tranche 8 G0 review + hooks (20121/20122/20123)

Same two-part protocol as tranches 2-7. NOTE: Factory is temporarily OFF
(OWNER 2026-07-25) — build/enqueue continues, backtests queue for later;
NO terminal interaction of any kind.

## Part A — G0 review (reciprocal; builder=claude)

Cards (D:\QM\strategy_farm\artifacts\cards_review\):
- QM5_20121_mtf-rsi2-align-m15_card.md    (STR-066)
- QM5_20122_bb-stoch-bandcross-h1_card.md (STR-067 — the resolved
  variant-split suspect; verify you accept the four-case resolution and
  the D1-exclusion override on 20121)
- QM5_20123_dailyopen-h1-basket_card.md   (STR-069 — BASKET class,
  host_symbol EURUSD.DWX; your combined-+10 equity reading adopted)

Verify vs 00_source.md + 03_reconciliation.md + 04_spec_final.md.
Verdicts: APPROVE (edit frontmatter) or REJECT. Deliver G0_REVIEW_T8.md.

## Part B — Hooks (approved only)

hooks_QM5_20121/20122/20123.mq5.txt per 04_spec_final. Binding
conventions as before. 20121: six iRSI handles with per-TF closed-bar
reads + BarsCalculated gating. 20122: four-case precedence order +
per-tick 15-pip trail ratchet (min-step, never widen). 20123: BASKET —
member requests via req.symbol_slot 0/1 (two-phase placement), member D1
opens/H1 closes read per symbol, combined floating-pip aggregation with
per-symbol pip values, basket close with once-latch + per-bar retry
pacing (check QM_TradeManagement for close helpers; the framework opens
member-symbol positions from the host chart per the T-WIN basket
precedent — verify the entry path supports symbol_slot cross-symbol
requests and note any constraint you find).
Read-only repo; deliverables only; no terminals.
