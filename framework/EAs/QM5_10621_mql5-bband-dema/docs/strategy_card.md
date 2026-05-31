---
ea_id: QM5_10621
slug: mql5-bband-dema
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "An Expert Advisor, based on Bollinger Bands, AM2, MQL5 CodeBase, published 2010-08-12, updated 2016-11-22, https://www.mql5.com/en/code/166"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/bollinger-band-reversal]]"
  - "[[concepts/trend-following]]"
indicators: [Bollinger_Bands, DEMA]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: M30
expected_trade_frequency: "Bollinger outer-band candle crosses filtered by DEMA direction on M30 should be moderate; conservative estimate is 35-70 trades/year/symbol."
expected_trades_per_year_per_symbol: 55
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS verifiable MQL5 CodeBase URL; R2 PASS deterministic Bollinger/DEMA entries and opposite-band exits with plausible 35-70 trades/year/symbol; R3 PASS OHLC indicators portable to DWX symbols; R4 PASS no ML/grid/martingale and one-position enforced."
---

# MQL5 Bollinger DEMA Band Cross

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: AM2, "An Expert Advisor, based on Bollinger Bands", MQL5 CodeBase, published 2010-08-12, updated 2016-11-22, URL https://www.mql5.com/en/code/166.
- Source location: page states the EA uses a trend-following DEMA filter and Bollinger Bands; source example references EURUSD M30.

## Mechanik

### Target Symbols
- Baseline DWX test symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

### Entry
- Compute DEMA and Bollinger Bands on completed bars.
- Long setup:
  - DEMA is rising.
  - The completed candle is bullish.
  - The candle crosses the lower Bollinger Band from below to above.
  - No existing position for this symbol/magic.
- Short setup:
  - DEMA is falling.
  - The completed candle is bearish.
  - The candle crosses the upper Bollinger Band from above to below.
  - No existing position for this symbol/magic.

### Exit
- Close long when a bearish candle crosses the upper Bollinger Band from above to below.
- Close short when a bullish candle crosses the lower Bollinger Band from below to above.
- V5 hard stop/target remains active as bounded protection.

### Stop Loss
- Initial V5 baseline: SL = 1.5 x ATR(14), or beyond the signal candle extreme if closer but still broker-valid.
- TP baseline: source band-cross exit plus emergency 2R take-profit.

### Position Sizing
- V5 baseline: fixed-risk $1,000 per backtest trade, converted to lots from stop distance.
- Enforce one-position-per-symbol/magic.

### Zusatzliche Filter
- V5 default spread guard.
- New-bar execution only.
- Default starting parameters: Bollinger period 20, deviation 2.0, DEMA period 20 unless source-code inputs reveal different defaults at build time.

## Concepts
- [[concepts/bollinger-band-reversal]] - primary
- [[concepts/trend-following]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Verifiable MQL5 CodeBase URL with title, author/handle, publish date, and explicit source rules. |
| R2 Mechanical | PASS | DEMA slope, candle color, Bollinger band cross, and opposite band-cross exits are deterministic. |
| R3 Data Available | PASS | Uses OHLC-derived Bollinger Bands and DEMA; portable to DWX FX, metals, oil, and index CFDs. |
| R4 ML Forbidden | PASS | No ML, no grid, no martingale, no adaptive parameters; V5 enforces one position. |

## Pipeline-Verlauf
- G0: Pending batch review.

## Verwandte Strategien
- [[strategies/QM5_10618_mql5-engulf-rsi]] - another completed-candle reversal system from the same page-38/39 mining pass.
- [[strategies/QM5_10451_mql5-wprbb]] - earlier MQL5 Bollinger-family reversal card using WPR/ATR rather than DEMA direction.

## Lessons Learned
- TBD

---

*Research note: expected cadence is conservative for M30 Bollinger band crosses filtered by DEMA direction.*
