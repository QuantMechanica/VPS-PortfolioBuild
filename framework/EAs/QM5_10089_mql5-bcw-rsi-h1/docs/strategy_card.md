---
ea_id: QM5_10089
slug: mql5-bcw-rsi-h1
type: strategy
source_id: a120af9a-fb72-526c-bb80-d1d098a617b5
sources:
  - "[[sources/mql5-examples]]"
concepts:
  - "[[concepts/candlestick-reversal]]"
  - "[[concepts/oscillator-confirmation]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/rsi]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: H1
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 35
last_updated: 2026-05-19
g0_approval_reasoning: "R1 MQL5 article URL cited; R2 deterministic candle+RSI entries/exits with 35 trades/year/symbol; R3 OHLC+RSI testable on DWX symbols; R4 fixed rules, no ML/grid/martingale, one position per magic."
---

# MQL5 Black Crows White Soldiers RSI H1

## Quelle
- Source: [[sources/mql5-examples]]
- Page / Timestamp: Artyom Trishkin, "Deconstructing examples of trading strategies in the client terminal", MQL5 Articles, 13 February 2025, https://www.mql5.com/en/articles/15479

## Mechanik

### Entry
- Trading period: H1 baseline.
- Evaluate only on a newly completed candle.
- Buy when the 3 White Soldiers bullish reversal pattern is present: three consecutive bullish candles with sufficient body size after a bearish/downward context.
- Confirm the buy with RSI(1) below 40 on the last completed bar.
- Sell when the 3 Black Crows bearish reversal pattern is present: three consecutive bearish candles with sufficient body size after a bullish/upward context.
- Confirm the sell with RSI(1) above 60 on the last completed bar.
- Enforce one active position per symbol/magic.

### Exit
- Close long when RSI crosses downward through 70 or 30.
- Close short when RSI crosses upward through 30 or 70.
- If an opposite confirmed pattern appears before the RSI exit, close the existing position before any new entry.

### Stop Loss
- Source article documents oscillator exits but not a fixed protective stop. Use V5 default ATR stop for P1/P2, initially 2.0 ATR(14), subject to later sweep.

### Position Sizing
- V5 fixed $1,000 risk for P2 baseline.

### Zusaetzliche Filter
- Target symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.
- Optional fixed spread filter.
- No grid, martingale, pyramiding, or multiple positions per magic.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/candlestick-reversal]] - primary
- [[concepts/oscillator-confirmation]] - secondary
- [[concepts/mean-reversion]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | Full MQL5 article URL with named author Artyom Trishkin. |
| R2 Mechanical | PASS | Pattern family, RSI entry thresholds, and RSI exit crossings are deterministic; stop gap can use V5 default. |
| R3 Data Available | PASS | Uses OHLC candles and RSI on explicit DWX target symbols. |
| R4 ML Forbidden | PASS | Fixed thresholds and one active position; no ML, online learning, grid, martingale, or adaptive parameters. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10090_mql5-harami-h1]] - same article and RSI confirmation, different candlestick reversal pattern.

## Lessons Learned (waehrend Pipeline-Lauf)
- TBD.
