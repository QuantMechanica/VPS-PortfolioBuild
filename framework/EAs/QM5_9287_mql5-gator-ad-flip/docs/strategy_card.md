---
ea_id: QM5_9287
slug: mql5-gator-ad-flip
type: strategy
source_id: ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
source_citation: "Stephen Njuki, MQL5 Wizard Techniques you should know (Part 78): Gator and AD Oscillator Strategies for Market Resilience, MQL5 Articles, 2025-08-04, https://www.mql5.com/en/articles/18992"
sources:
  - "[[sources/mql5-articles]]"
concepts:
  - "[[concepts/trend-reversal]]"
  - "[[concepts/volume-spike]]"
  - "[[concepts/alligator-crossover]]"
indicators:
  - "[[indicators/gator-oscillator]]"
  - "[[indicators/accumulation-distribution]]"
  - "[[indicators/standard-deviation]]"
  - "[[indicators/atr]]"
target_symbols: [GBPJPY.DWX, XAUUSD.DWX, GDAXI.DWX]
period: H1
expected_trade_frequency: "Medium frequency; trend-flip and volume-spike reversal pattern, roughly 40-90 trades per year per symbol"
expected_trades_per_year_per_symbol: 65
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id ba57d97a links to mql5-articles; named MQL5 Part 78 article URL with author Stephen Njuki provides full lineage."
r2_mechanical: PASS
r2_reasoning: "Pattern 8 Gator contraction, STD_DEV gate, AD range check, and price-midpoint comparison are explicit closed-form conditions with no discretion."
r3_data_available: PASS
r3_reasoning: "H1 strategy on DWX symbols (GBPJPY, XAUUSD, GDAXI) using OHLC, tick volume, standard deviation, and ATR all available in DWX MT5."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed indicator comparisons only; no ML, adaptive parameters, grid, martingale, or multiple positions per magic."
pipeline_phase: G0
last_updated: 2026-05-19
card_body_incomplete: false
card_body_missing: ""
g0_approval_reasoning: "R1 PASS MQL5 article URL and author; R2 PASS closed-bar Gator/AD/STD flip entry-exit with ~65 trades/year/symbol; R3 PASS OHLC/tick-volume indicators on DWX symbols; R4 PASS fixed rules, no ML/grid/martingale, one position per magic."
---

# MQL5 Gator AD Volume Flip

## Quelle
- Source: [[sources/mql5-articles]]
- Article: "MQL5 Wizard Techniques you should know (Part 78): Gator and AD Oscillator Strategies for Market Resilience"
- Author: Stephen Njuki
- Date: 2025-08-04
- URL: https://www.mql5.com/en/articles/18992
- Page / Timestamp: Alligator Crossover Reversal + Volume Spike, Pattern 8.

## Mechanik

### Entry
- On closed H1 bars, calculate Gator Oscillator, AD oscillator, and a standard deviation value matching the source's Pattern 8 volatility gate.
- Long setup:
  - Gator upper and lower histograms are both red on bar [0].
  - Standard deviation gate passes: STD_DEV[0] <= max(Gator_UP[0], abs(Gator_LO[0])).
  - AD range gate passes: 5.0 * STD_DEV[0] > max(AD[1], AD[2]) - min(AD[1], AD[2]).
  - Close[0] > midpoint of bar [1].
  - AD[0] > AD[1].
- Short setup:
  - Same Gator and standard deviation gates.
  - Close[0] < midpoint of bar [1].
  - AD[0] < AD[1].
- Enter at next bar open; one position per magic number.

### Exit
- Close long when Close[0] < midpoint of bar [1] or AD[0] < AD[1] for two consecutive bars.
- Close short when Close[0] > midpoint of bar [1] or AD[0] > AD[1] for two consecutive bars.
- Failsafe time exit after 72 H1 bars.

### Stop Loss
- Long stop: recent 5-bar swing low - 1.0 * ATR(14).
- Short stop: recent 5-bar swing high + 1.0 * ATR(14).
- Initial take profit: 2.5R.

### Position Sizing
- V5 fixed $1,000 P2 risk from stop distance; live RISK_PERCENT default after approval.

### Zusätzliche Filter
- Closed-bar execution only.
- Trade only when ATR(14) is above its 50-bar median to avoid dead ranges.
- V5 default spread and news filters.

## Concepts (was ist das für eine Strategie)
- [[concepts/trend-reversal]] - primary
- [[concepts/volume-spike]] - secondary
- [[concepts/alligator-crossover]] - secondary

## Target Symbols
- GBPJPY.DWX
- XAUUSD.DWX
- GDAXI.DWX

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full MQL5 article URL with named author Stephen Njuki. |
| R2 Mechanical | PASS | Source gives Pattern 8 fixed Gator color, standard-deviation, AD, and price-midpoint conditions. |
| R3 Data Available | PASS | Uses OHLC, tick volume, Gator, standard deviation, AD, and ATR available on DWX MT5 symbols. |
| R4 ML Forbidden | PASS | Fixed indicator comparisons only; no ML, adaptive parameters, grid, martingale, or multiple positions per magic. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9269_mql5-gator-ad-hidden]] - same source family, but this card trades the major flip/volume-spike pattern rather than hidden divergence continuation.
- [[strategies/QM5_9228_mql5-alligator-teeth]] - related Williams-line reversal family without AD volume validation.

## Lessons Learned (während Pipeline-Lauf)
- TBD

---

*Research note: Source frames Pattern 8 as a major trend flip using Gator contraction plus AD volume confirmation; this card ports the coded conditions directly and adds V5 risk exits.*
