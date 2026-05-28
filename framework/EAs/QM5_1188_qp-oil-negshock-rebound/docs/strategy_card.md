---
ea_id: QM5_1188
slug: qp-oil-negshock-rebound
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
card_body_incomplete: true
card_body_missing: period
---

# Quantpedia Oil Negative-Shock Rebound

## Source

Quantpedia, How to Analyze Individual Equity Curves, published 2026-04-23, author David Mesicek / Quantpedia.
Source URL is stored in the approved Strategy Card outside the EA folder.

## Mechanics

Universe:
- Preferred route: `XTIUSD.DWX`
- Alternate route: `XBRUSD.DWX`

Period:
- D1 daily bars.

Entry:
1. Compute daily close-to-close return.
2. Compute ATR(20) as a percentage of close.
3. Compute trailing 252-session percentile rank of ATR(20)%.
4. If daily return is less than or equal to `-2 * ATR20%` and ATR percentile is at or above 70, open long at the next session open.

Exit:
- Close at the next daily close. A fixed two-session safety hold is retained as a configurable variant.

Stop Loss:
- Initial stop 1.0 ATR(20) below entry. No averaging down.

Position Sizing:
- Fixed fractional risk per trade, capped to one position per symbol and magic.

Additional Filters:
- Long-only.
- Skip scheduled roll/holiday sessions if broker daily bars are abnormal.
- Do not use intraday news classification.

## Build Notes

This EA implements the card as a simple volatility-conditioned oil reversal. It uses MT5/DWX bars only and no external data or ML.
