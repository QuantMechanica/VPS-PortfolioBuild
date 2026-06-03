---
ea_id: QM5_10577
slug: mql5-ma-round
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "Exp_MA_Rounding_Candle, Nikolay Kositsin, MQL5 CodeBase, published 2015-11-04, updated 2023-03-29, https://www.mql5.com/en/code/14095"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/candle-color-change]]"
  - "[[concepts/moving-average-smoothing]]"
indicators: [MA_Rounding_Candle, MA_Rounding]
target_symbols: [USDJPY.DWX, EURUSD.DWX, GBPJPY.DWX, XAUUSD.DWX]
period: H4
expected_trade_frequency: "Closed-bar MA_Rounding_Candle color changes on H4 should be moderate; conservative estimate is 20-55 trades/year/symbol."
expected_trades_per_year_per_symbol: 35
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 MQL5 CodeBase URL/title/author cited; R2 closed-bar MA_Rounding_Candle color-change entry and reverse/stop exits with ~35 trades/year/symbol; R3 portable to DWX FX/metals; R4 no ML/grid/martingale and one-position compatible."
---

# MQL5 MA Rounding Candle Color Change

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: Nikolay Kositsin, "Exp_MA_Rounding_Candle", MQL5 CodeBase, published 2015-11-04, updated 2023-03-29, URL https://www.mql5.com/en/code/14095.
- Source location: page states the EA is based on MA_Rounding_Candle candlestick color changes; a signal forms at bar close when candlestick color changes. Source test shown on USDJPY H4 for 2014.

## Mechanik

### Entry
- Compute MA_Rounding_Candle on the selected timeframe.
- Long when the latest closed bar changes the MA_Rounding_Candle state to bullish color.
- Short when the latest closed bar changes the MA_Rounding_Candle state to bearish color.
- No existing position for this symbol/magic.

### Exit
- Close long on a bearish MA_Rounding_Candle color change, hard stop/target, or V5 kill-switch.
- Close short on a bullish MA_Rounding_Candle color change, hard stop/target, or V5 kill-switch.
- V5 Friday close and news exits apply.

### Stop Loss
- Source tests did not use SL/TP.
- P2 baseline: ATR(14) 2.0 hard stop and 1.5R target.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- One active position per symbol/magic.

### Zusaetzliche Filter
- Sweep H1/H4/H6/H8, MA_Rounding_Candle smoothing parameters after source-code confirmation, ATR stop multiplier, and optional EMA200 slope filter.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL, title, author, and publish/update dates. |
| R2 Mechanical | PASS | Direction is determined by closed-bar bullish/bearish candle color change. |
| R3 DWX-testbar | PASS | MA-derived candle-color logic is portable to DWX FX, metals, oil, and index CFDs. |
| R4 No ML | PASS | No ML, grid, martingale, or adaptive sizing; one-position V5 baseline enforced. |

## R3
Primary P2 basket: USDJPY.DWX, EURUSD.DWX, GBPJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10563_mql5-vwma-candle]] - related closed-bar candle color-change family.

## Lessons Learned
- TBD during pipeline run.
