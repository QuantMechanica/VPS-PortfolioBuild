---
ea_id: QM5_10241
slug: tv-vwap-retest
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/vwap-pullback]]"
  - "[[concepts/intraday-continuation]]"
indicators:
  - "[[indicators/vwap]]"
  - "[[indicators/atr-stop]]"
  - "[[indicators/volume-filter]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 70
last_updated: 2026-05-19
g0_approval_reasoning: "R1 URL cited; R2 mechanical VWAP break/retest/confirmation with ATR exits and ~70 trades/year/symbol; R3 DWX CFD ports incl SP500 backtest caveat; R4 no ML/grid/martingale."
---

# VWAP Retest Continuation

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script page, "VWAP Reversal Strategy V1" by DerAndi72 / COT-Trader.com, published 2026-02-13.
- URL: https://www.tradingview.com/script/9dkGK2jB-VWAP-Reversal-Strategy-V1/

## Mechanik

### Entry
- Execution timeframe: M15 or M30 intraday.
- Long setup: price first breaks above session VWAP, then retests VWAP within a defined number of bars, then prints a bullish confirmation candle.
- Short setup is mirrored below VWAP and can be disabled for long-only testing.
- Optional filters documented by the source: rejection wick confirmation, volume spike confirmation, minimum ATR-based distance from VWAP, and optional H1 VWAP directional bias.
- Baseline P1 setting: enable rejection wick and volume spike filters; leave H1 bias as a P3 sweep parameter.

### Exit
- Exit at ATR-based take profit.
- Exit at ATR-based stop loss.
- Enforce maximum trades per day and optional session close flat.

### Stop Loss
- ATR-based stop loss from entry.
- P1 default: 1.0 ATR stop and 1.5 ATR target unless Pine source exposes stronger defaults.

### Position Sizing
- V5 fixed-risk baseline: risk USD 1,000 per P2 backtest trade.
- One open position per magic number.

### Zusätzliche Filter
- Maximum trades per day: 2 in baseline to preserve the source's selective framework.
- Best DWX ports: NDX.DWX, WS30.DWX, GER40.DWX, XAUUSD.DWX, EURUSD.DWX.
- For SP500 analog tests, use SP500.DWX.
- Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Concepts (was ist das für eine Strategie)
- [[concepts/vwap-pullback]] - primary
- [[concepts/intraday-continuation]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle DerAndi72 / COT-Trader.com are cited. |
| R2 Mechanical | PASS | Break, retest, confirmation candle, ATR stop/target, max trades, and session filter are deterministic. |
| R3 Data Available | PASS | OHLC, VWAP, volume proxy, ATR, and session clock are available on DWX CFDs. |
| R4 ML Forbidden | PASS | No ML, neural logic, grid, martingale, DCA, pyramiding, or online parameter adaptation. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.
- P1: TBD.
- P2: TBD.

## Verwandte Strategien
- [[strategies/QM5_10159_tv-vwap-sma-cross]] - simple VWAP/SMA cross family.
- [[strategies/QM5_10178_tv-vwap-mr-forex]] - VWAP mean-reversion family.

## Lessons Learned (während Pipeline-Lauf)
- TBD.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
