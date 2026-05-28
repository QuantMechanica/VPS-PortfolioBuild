---
ea_id: QM5_1189
slug: qp-oil-posshock-pullback
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
card_body_incomplete: true
card_body_missing: "period"
---

# Quantpedia Oil Positive-Shock Pullback

## Quelle

Quantpedia, **How to Analyze Individual Equity Curves**, published 2026-04-23, author David Mesicek / Quantpedia.

The article uses USO as an oil proxy and describes Quantpedia Pro tests for short-horizon edges after extreme returns and volatility shocks. It separately notes that strong positive moves can be followed by temporary pullbacks.

## Mechanik

### Universe

Preferred route: XTIUSD.DWX. Alternate route: XBRUSD.DWX if QB selects Brent as the canonical oil proxy.

### Period

D1 daily bars.

### Entry

At the close of a daily bar:

1. Compute daily return.
2. Compute ATR(20) as a percentage of close.
3. Compute trailing 252-session percentile rank of ATR(20)%.
4. If daily return is greater than or equal to `+2 * ATR20%` and ATR percentile is at or above 70, open short at the next session open.

### Exit

Close the position at the next daily close. A two-session maximum hold may be evaluated in P1 but must be frozen before P2.

### Stop Loss

Initial stop: 1.0 ATR(20) above entry. No averaging into losers.

### Position Sizing

Fixed fractional risk per trade, capped to one position per symbol and magic. No grid, martingale, or pyramiding.

### Zusätzliche Filter

- Trade short-only.
- Skip broker sessions with abnormal oil daily bars around holidays or contract transitions.
- Do not use discretionary news tags.

## Build Mapping

- Entry uses completed D1 bar return, ATR20% threshold, and 252-session ATR percentile.
- Exit uses scheduled next-D1 holding window.
- Abnormal oil bars are guarded by configurable ATR-range and ATR-gap filters.
- No external API, ML, grid, martingale, or averaging logic is used.
