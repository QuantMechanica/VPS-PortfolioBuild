---
ea_id: QM5_10090
slug: mql5-harami-h1
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
expected_trades_per_year_per_symbol: 80
last_updated: 2026-05-19
g0_approval_reasoning: "R1 MQL5 article URL cited; R2 deterministic Harami+RSI entries/exits with 80 trades/year/symbol; R3 OHLC+RSI testable on DWX symbols; R4 fixed rules, no ML/grid/martingale, one position per magic."
---

# MQL5 Harami RSI H1

## Quelle
- Source: [[sources/mql5-examples]]
- Page / Timestamp: Artyom Trishkin, "Deconstructing examples of trading strategies in the client terminal", MQL5 Articles, 13 February 2025, https://www.mql5.com/en/articles/15479

## Mechanik

### Entry
- Trading period: H1 baseline.
- Evaluate only on a newly completed candle.
- Buy when a Bullish Harami pattern is present: a long bearish candle is followed by a bullish candle whose body is fully contained inside the bearish candle body during a downward context.
- Confirm the buy with RSI(1) below 40.
- Sell when a Bearish Harami pattern is present: a long bullish candle is followed by a bearish candle whose body is fully contained inside the bullish candle body during an upward context.
- Confirm the sell with RSI(1) above 60.
- Enforce one active position per symbol/magic.

### Exit
- Close long when RSI crosses downward through 70 or 30.
- Close short when RSI crosses upward through 30 or 70.
- Opposite confirmed signal may close and reverse only after the current position is flat.

### Stop Loss
- Source article documents indicator exits but not a fixed protective stop. Use V5 default ATR stop for P1/P2, initially 2.0 ATR(14), with later sweep allowed.

### Position Sizing
- V5 fixed $1,000 risk for P2 baseline.

### Zusaetzliche Filter
- Target symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.
- Optional fixed spread filter.
- Optional minimum candle-body filter copied from the MT5 example implementation if exposed during build.
- No grid, martingale, pyramiding, or adaptive sizing.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/candlestick-reversal]] - primary
- [[concepts/oscillator-confirmation]] - secondary
- [[concepts/mean-reversion]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | Full MQL5 article URL with named author Artyom Trishkin. |
| R2 Mechanical | PASS | Harami definitions, RSI thresholds, and RSI close crossings are deterministic. |
| R3 Data Available | PASS | Uses OHLC candles and RSI on explicit DWX target symbols. |
| R4 ML Forbidden | PASS | Fixed-rule oscillator-confirmed candle pattern; one active position per magic. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10089_mql5-bcw-rsi-h1]] - same source article and RSI confirmation, different reversal pattern.

## Lessons Learned (waehrend Pipeline-Lauf)
- TBD.
