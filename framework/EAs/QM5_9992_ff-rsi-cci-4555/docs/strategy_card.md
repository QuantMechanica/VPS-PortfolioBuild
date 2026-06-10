---
ea_id: QM5_9992
slug: ff-rsi-cci-4555
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
source_citation: "Thierry89 and DirkH143, RSI & CCI system, ForexFactory, 2009-01-27, https://www.forexfactory.com/thread/149331-rsi-cci-system"
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/oscillator-confirmation]]"
  - "[[concepts/scalping]]"
  - "[[concepts/trailing-stop]]"
indicators:
  - "[[indicators/rsi]]"
  - "[[indicators/cci]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, EURGBP.DWX]
period: M5
expected_trade_frequency: "M5 RSI/CCI momentum gate with 45/55 no-trade band; conservative estimate 150-300 trades/year/symbol after session/spread filters."
expected_trades_per_year_per_symbol: 220
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS ForexFactory URL/handles; R2 PASS deterministic RSI/CCI M5 entries/exits with SL/TP/trailing and 220 trades/year/symbol estimate; R3 PASS DWX FX majors testable; R4 PASS fixed non-ML one-position rules."
---

# ForexFactory RSI CCI 45/55 Scalper

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Citation: Thierry89 and DirkH143, "RSI & CCI system", ForexFactory, 2009, URL https://www.forexfactory.com/thread/149331-rsi-cci-system.
- Author / handle: `Thierry89`; 45/55 refinement by `DirkH143`.
- Source location: first post plus posts #5-#7. The source defines M5, EURUSD/USDCHF/EURJPY/GBPUSD, RSI(8), CCI(14), buys when RSI is above 50 and CCI above 0, sells when RSI below 50 and CCI below 0, exits on RSI reverse signal, trailing stop or TP. Posts #5-#7 add RSI 55/45 no-trade band: above 55 long, below 45 short, no entries between 45 and 55.

## Mechanik

### Entry
- Work on M5.
- Compute RSI(8) and CCI(14).
- Long setup:
  - `RSI(8)[1] <= 55 AND RSI(8)[0] > 55` OR first eligible bar after RSI leaves the 45-55 no-trade band upward.
  - `CCI(14)[0] > 0`.
  - Enter long at next bar open.
- Short setup:
  - `RSI(8)[1] >= 45 AND RSI(8)[0] < 45` OR first eligible bar after RSI leaves the 45-55 no-trade band downward.
  - `CCI(14)[0] < 0`.
  - Enter short at next bar open.
- No new entry while RSI is between 45 and 55.

### Exit
- Close long when RSI crosses back below 50 or CCI crosses below 0.
- Close short when RSI crosses back above 50 or CCI crosses above 0.
- Baseline TP = 15 pips.
- Time stop after 24 M5 bars.

### Stop Loss
- Initial hard stop = 15 pips.
- Move stop to breakeven after +8 pips.
- Trail by 8 pips once trade is +12 pips in favor.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- Trade London/NY overlap and liquid sessions only: 07:00-20:00 UTC.
- Spread <= 1.5 pips and <= 10% of stop distance.
- One active position per magic-symbol.

## Concepts
- [[concepts/oscillator-confirmation]] - primary
- [[concepts/scalping]] - secondary
- [[concepts/trailing-stop]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full ForexFactory URL plus named handles `Thierry89` and `DirkH143`. |
| R2 Mechanical | PASS | RSI thresholds, CCI zero filter, reverse-signal exits, fixed TP/SL, BE, trailing, and time stop are deterministic. |
| R3 DWX-testbar | PASS | Uses M5 OHLC-derived RSI/CCI on DWX FX majors. |
| R4 No ML | PASS | Fixed indicators and thresholds, no grid/martingale/ML, one position per magic. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, EURGBP.DWX. Not SP500-specific.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9701_ff-ema-rsi-m15]] - RSI confirms EMA cross; this card is pure RSI/CCI oscillator confirmation on M5.
- [[strategies/QM5_9958_ff-rsi-ema-cci-h1h4]] - multi-timeframe RSI/EMA/CCI trend; this card is the original M5 RSI/CCI threshold scalper.

## Lessons Learned
- TBD during pipeline run.

