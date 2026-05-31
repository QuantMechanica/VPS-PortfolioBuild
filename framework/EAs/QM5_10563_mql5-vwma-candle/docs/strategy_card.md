---
ea_id: QM5_10563
slug: mql5-vwma-candle
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "Exp_Volume_Weighted_MACandle, Nikolay Kositsin, MQL5 CodeBase, published 2016-10-10, updated 2016-11-22, https://www.mql5.com/en/code/15899"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/volume-weighted-ma]]"
  - "[[concepts/indicator-color-change]]"
indicators: [Volume_Weighted_MACandle, Volume_Weighted_MA]
target_symbols: [GBPUSD.DWX, EURUSD.DWX, GBPJPY.DWX, XAUUSD.DWX]
period: H4
expected_trade_frequency: "Volume-weighted MA candle color changes on H4 should be moderate; conservative estimate is 35-80 trades/year/symbol."
expected_trades_per_year_per_symbol: 55
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 cited MQL5 CodeBase URL/title/author; R2 closed-bar VWMA candle color-change entries/exits with ~55 trades/year/symbol; R3 portable to DWX FX/metals; R4 no ML/grid/martingale and one-position baseline."
---

# MQL5 Volume Weighted MA Candle Color Change

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: Nikolay Kositsin, "Exp_Volume_Weighted_MACandle", MQL5 CodeBase, published 2016-10-10, updated 2016-11-22, URL https://www.mql5.com/en/code/15899.
- Source location: page states the signal is formed at bar close when Volume_Weighted_MACandle indicator candlesticks change from green to pink or vice versa. Source test shown on GBPUSD H4.

## Mechanik

### Entry
- Compute Volume_Weighted_MACandle and required Volume_Weighted_MA support indicator.
- Long when the closed indicator candle changes from bearish/pink to bullish/green.
- Short when the closed indicator candle changes from bullish/green to bearish/pink.
- No existing position for this symbol/magic.

### Exit
- Close long when the indicator candle changes bearish/pink or hard stop/target is hit.
- Close short when the indicator candle changes bullish/green or hard stop/target is hit.
- V5 Friday close, news, and kill-switch exits apply.

### Stop Loss
- Source tests did not use SL/TP.
- P2 baseline: ATR(14) 2.0 hard stop and 1.5R target.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- One active position per symbol/magic.

### Zusaetzliche Filter
- Sweep H1/H4/H6, volume-weighted MA inputs after source-code confirmation, ATR stop multiplier, and optional ADX minimum-trend filter.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL, title, author, and publish/update dates. |
| R2 Mechanical | PASS | Direction is given by closed-bar color changes from green to pink or pink to green. |
| R3 DWX-testbar | PASS | OHLC/tick-volume moving-average logic is portable to DWX FX, metals, oil, and index CFDs. |
| R4 No ML | PASS | No ML, grid, martingale, or adaptive sizing; one-position V5 baseline enforced. |

## R3
Primary P2 basket: GBPUSD.DWX, EURUSD.DWX, GBPJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10561_mql5-delta-mfi]] - prior closed-bar color-change family.

## Lessons Learned
- TBD during pipeline run.
