---
ea_id: QM5_10233
slug: tv-macd-rsi-day
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/day-trading]]"
  - "[[concepts/momentum-continuation]]"
indicators:
  - "[[indicators/macd]]"
  - "[[indicators/rsi]]"
  - "[[indicators/ema]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 120
last_updated: 2026-05-19
g0_approval_reasoning: "R1 verifiable TradingView URL; R2 mechanical EMA/MACD/RSI/volume/session entries plus ATR/EOD exits with ~120 trades/year/symbol; R3 testable on DWX CFDs with SP500 caveat; R4 fixed deterministic no ML/martingale."
---

# MACD RSI EMA Day Trade

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script page, "MACD + RSI + EMA + BB + ATR Day Trading Strategy" by shui2967, published 2025-05-30.
- URL: https://www.tradingview.com/script/2Q5tFJUc-MACD-RSI-EMA-BB-ATR-Day-Trading-Strategy/

## Mechanik

### Entry
- Execution timeframe: M5.
- Higher-timeframe confirmation: M15 trend must agree with trade direction.
- Long entry when EMA9 > EMA21, close > EMA9, higher timeframe confirms uptrend, MACD line crosses above signal line, RSI is between 40 and 70, current volume is greater than 1.2 * SMA(volume, 20), ATR indicates sufficient movement, and time is within 09:30-11:30 New York.
- Short entry is the mirrored condition: EMA9 < EMA21, close < EMA9, higher timeframe confirms downtrend, MACD line crosses below signal line, RSI is between 30 and 60, current volume is greater than 1.2 * SMA(volume, 20), ATR movement filter passes, and time is within 09:30-11:30 New York.

### Exit
- Close all positions by 16:00 New York to avoid overnight risk.
- Exit earlier if ATR stop, ATR trailing stop, or opposite signal fires.

### Stop Loss
- Initial stop at 2.0 ATR from entry.
- Trailing stop at 1.5 ATR once price moves favorably.

### Position Sizing
- V5 fixed-risk baseline: risk USD 1,000 per P2 backtest trade.
- One open position per magic number.

### Zusätzliche Filter
- Source mentions Bollinger Bands in title/tags, but public entry text does not expose a Bollinger trigger; P1 should not add a BB condition unless verified from Pine source.
- Best DWX ports: NDX.DWX, GER40.DWX, WS30.DWX, XAUUSD.DWX. For SP500 analog tests, use SP500.DWX.
- Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Concepts (was ist das für eine Strategie)
- [[concepts/day-trading]] - primary
- [[concepts/momentum-continuation]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle shui2967 are cited. |
| R2 Mechanical | PASS | EMA, MACD, RSI, volume, session, ATR stop, trailing stop, and EOD exit rules are explicit. |
| R3 Data Available | PASS | Required OHLC, tick volume proxy, EMA, MACD, RSI, ATR, and session clock are available on DWX CFDs. |
| R4 ML Forbidden | PASS | No ML, neural logic, grid, martingale, DCA, pyramiding, or online parameter adaptation. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.
- P1: TBD.
- P2: TBD.

## Verwandte Strategien
- [[strategies/QM5_10163_tv-rsi-macd-long]] - RSI/MACD long-only variant.
- [[strategies/QM5_10118_tv-rsi-trend-cont]] - RSI/MACD/Stochastic trend continuation.

## Lessons Learned (während Pipeline-Lauf)
- TBD.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
