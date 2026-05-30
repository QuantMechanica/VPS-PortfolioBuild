---
ea_id: QM5_10251
slug: tv-nova-rev
type: strategy
source_id: c84ae47e-8ea0-56f1-8b25-4436b6dda5b5
sources:
  - "[[sources/tradingview-top-pine-scripts]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/reversal]]"
indicators:
  - "[[indicators/volatility-band]]"
  - "[[indicators/candlestick-pattern]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
primary_symbol: XAUUSD.DWX
expected_trades_per_year_per_symbol: 80
last_updated: 2026-05-19
g0_approval_reasoning: "R1 TradingView URL/handle cited; R2 deterministic band/candle reversal entries, fair-value exits, and 80 trades/year/symbol estimate; R3 DWX OHLC indicators testable; R4 fixed rules no ML/grid/martingale."
---

# QM5_10251 TradingView Nova Reversal Bands

## Quelle
- Source: TradingView Pine script "Nova Reversal Bands by LunqFX"
- URL: https://www.tradingview.com/script/LhrZrzve-Nova-Reversal-Bands-by-LunqFX/
- Author: LunqFX (TradingView handle - anon OK under relaxed R1 post-2026-05-15)
- Source location: TradingView Volatility category, public open-source script, 2026-05-19 snapshot.

## Mechanik

### Entry
- Compute fair value line as the source-described blend of Hull MA and WMA; V5 baseline: `0.5 * HMA(50) + 0.5 * WMA(50)`.
- Compute dynamic upper/lower bands around fair value using 85th percentile candle range plus ATR, with default band multiplier 2.4.
- Require reversal candle filter ON:
  - Pin bar: rejection wick > 50% of full candle range.
  - Or engulfing: current candle body fully engulfs previous body in the opposite direction.
- Long setup:
  - Price reaches or penetrates the lower band.
  - Signal score >= 3 stars, approximated as at least two of: deep band penetration, ATR expanding, bands widening.
  - Pin bar or bullish engulfing confirms rejection.
  - Enter long at next candle open.
- Short setup:
  - Price reaches or penetrates the upper band.
  - Signal score >= 3 stars.
  - Pin bar or bearish engulfing confirms rejection.
  - Enter short at next candle open.

### Exit
- Primary target: fair value center line.
- P3 variant: opposite band as extended target.
- Time-stop: flatten after 30 bars if target or stop is not reached.

### Stop Loss
- Long SL: just beyond lower band, baseline `lower_band - 0.25 x ATR(14)`.
- Short SL: just beyond upper band, baseline `upper_band + 0.25 x ATR(14)`.

### Position Sizing
- V5 standard: `RISK_FIXED = $1,000` for P2 baseline. `RISK_PERCENT` for live.

### Zusaetzliche Filter
- Do not take reversal trades during squeeze state; the same source treats squeeze as breakout context, not mean-reversion context.
- Trade only when band touch memory is 1-4 touches; skip exhausted gray-band state where the source expects a break rather than bounce.
- Standard V5: QM_KillSwitch, news filter, MAX_DD trip, Friday-close flatten.

## Concepts
- [[concepts/mean-reversion]] - primary; fade confirmed band extremes toward fair value.
- [[concepts/reversal]] - candle rejection/engulfing acts as final trigger.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | PASS | Public TradingView URL and author handle LunqFX are cited. |
| R2 Mechanical | PASS | Band touch, candle pattern, score threshold, SL beyond band, and fair-value target are deterministic. |
| R3 Data Available | PASS | Bands, ATR, HMA/WMA, and candle patterns are computable from DWX OHLC data. |
| R4 ML Forbidden | PASS | Fixed rules and thresholds only. No ML, adaptive learning, grid, or martingale. |

## Pipeline-Verlauf
- G0: 2026-05-19 - drafted from TradingView top-script resume batch, PENDING.

## Verwandte Strategien
- Same source also describes a squeeze-breakout variant; this card intentionally covers only the reversal setup to keep one entry/exit thesis.

## Lessons Learned (waehrend Pipeline-Lauf)
- *(populated as pipeline progresses)*

## Implementation Notes for Codex (P1)
- Default P2 symbols: XAUUSD.DWX, EURUSD.DWX, GBPUSD.DWX, NDX.DWX.
- Default timeframe: M30. P3 sweep: M15/H1.
- If exact source band code is not reused in P1, document the band approximation explicitly in the EA header.
