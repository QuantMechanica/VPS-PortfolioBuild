---
ea_id: QM5_9269
slug: mql5-gator-ad-hidden
type: strategy
source_id: ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
source_citation: "Stephen Njuki, MQL5 Wizard Techniques you should know (Part 78): Gator and AD Oscillator Strategies for Market Resilience, MQL5 Articles, 2025-08-04, https://www.mql5.com/en/articles/18992"
sources:
  - "[[sources/mql5-articles]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/divergence]]"
  - "[[concepts/volume-confirmation]]"
indicators:
  - "[[indicators/gator-oscillator]]"
  - "[[indicators/accumulation-distribution]]"
  - "[[indicators/atr]]"
target_symbols: [EURUSD.DWX, GBPJPY.DWX, XAUUSD.DWX]
period: H4
expected_trade_frequency: "Low-medium frequency; hidden AD divergence plus Gator resume condition should trigger roughly 15-40 trades per year per symbol."
expected_trades_per_year_per_symbol: 25
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; MQL5 article by Stephen Njuki with full URL provides traceable lineage."
r2_mechanical: PASS
r2_reasoning: "Gator histogram color sequence, price structure (higher-low/lower-high), and AD extremum conditions are fully mechanically specified."
r3_data_available: PASS
r3_reasoning: "Target symbols EURUSD.DWX, GBPJPY.DWX, XAUUSD.DWX are all DWX-available; tick-volume-based AD is accessible in MT5."
r4_ml_forbidden: PASS
r4_reasoning: "Uses only fixed Pattern-7 rules from the non-ML article section; no ML, no ONNX, no PnL-adaptive parameters, one position per magic."
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS MQL5 article URL and attribution; R2 PASS mechanical entry/exit with 25 trades/year/symbol estimate; R3 PASS Gator/AD/ATR testable on DWX symbols; R4 PASS fixed non-ML one-position rules."
---

# MQL5 Gator AD Hidden Divergence

## Quelle
- Source: [[sources/mql5-articles]]
- Article: "MQL5 Wizard Techniques you should know (Part 78): Gator and AD Oscillator Strategies for Market Resilience"
- Author: Stephen Njuki
- Date: 2025-08-04
- URL: https://www.mql5.com/en/articles/18992
- Page / Timestamp: Pattern-7 "Hidden Volume Divergence"; source code requires prior dual-red Gator bars, current dual-green Gator bars, price higher-low/lower-high behavior, and AD extreme confirmation.

## Mechanik

### Target Symbols
- EURUSD.DWX, GBPJPY.DWX, XAUUSD.DWX.

### Entry
- Calculate Bill Williams Gator oscillator colors and Accumulation/Distribution on closed H4 bars.
- Long entry: previous bar has both Gator histograms red, current bar has both Gator histograms green, Low[2] > Low[1], Close[0] > Low[1], and AD[0] >= max(AD[1], AD[2]).
- Short entry: previous bar has both Gator histograms red, current bar has both Gator histograms green, High[2] < High[1], Close[0] < High[1], and AD[0] <= min(AD[1], AD[2]).
- Enter at the next bar open; one position per magic number.

### Exit
- Close long when either Gator histogram turns red for 2 consecutive closed bars, AD[0] < AD[1] < AD[2], or price closes below the pullback low.
- Close short when either Gator histogram turns red for 2 consecutive closed bars, AD[0] > AD[1] > AD[2], or price closes above the relief-rally high.
- Failsafe time exit after 24 H4 bars.

### Stop Loss
- Long stop: 0.5 * ATR(14) below Low[1] from the hidden-divergence setup.
- Short stop: 0.5 * ATR(14) above High[1] from the hidden-divergence setup.
- Initial take profit: 2.5R.

### Position Sizing
- V5 fixed $1,000 P2 risk from stop distance; live RISK_PERCENT default after approval.

### Zusätzliche Filter
- Closed-bar execution only.
- Require ATR(14) > its 100-bar 20th percentile to avoid dead-range signals.
- V5 default spread/news filters.

## Concepts (was ist das für eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/divergence]] - secondary
- [[concepts/volume-confirmation]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full MQL5 article URL with named author Stephen Njuki. |
| R2 Mechanical | PASS | Source gives exact Gator color, price structure, and AD max/min conditions for both directions. |
| R3 Data Available | PASS | Uses OHLC, tick-volume-derived Accumulation/Distribution, Gator oscillator, and ATR available on DWX symbols. |
| R4 ML Forbidden | PASS | Fixed indicator-pattern rules; no supervised learning, ONNX, adaptive parameter selection, grid, or martingale. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9227_mql5-gator-ma]] - also uses Gator, but this card uses Accumulation/Distribution hidden divergence confirmation.

## Lessons Learned (während Pipeline-Lauf)
- TBD

---

*Research note: The article has a separate supervised-learning follow-up; this card deliberately uses only the fixed Pattern-7 rules from the non-ML article.*
