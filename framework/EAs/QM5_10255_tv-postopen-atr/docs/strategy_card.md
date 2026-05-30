---
ea_id: QM5_10255
slug: tv-postopen-atr
type: strategy
source_id: c84ae47e-8ea0-56f1-8b25-4436b6dda5b5
sources:
  - "[[sources/tradingview-top-pine-scripts]]"
concepts:
  - "[[concepts/opening-range-breakout]]"
  - "[[concepts/volatility-breakout]]"
indicators:
  - "[[indicators/bollinger-bands]]"
  - "[[indicators/ema]]"
  - "[[indicators/rsi]]"
  - "[[indicators/adx]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
primary_symbol: GER40.DWX
expected_trades_per_year_per_symbol: 90
last_updated: 2026-05-19
g0_approval_reasoning: "R1 TradingView URL+author cited; R2 mechanical post-open breakout with ATR exit and ~90 trades/year/symbol; R3 DWX FX/index CFDs testable; R4 fixed-rule non-ML one-position logic."
---

# QM5_10255 TradingView Post-Open ATR Breakout

## Quelle
- Source: TradingView Pine script "Post-Open Long Strategy with ATR-based Stop Loss and Take Profit"
- URL: https://www.tradingview.com/script/wApzruR3/
- Author: MatteoRizzitelli (TradingView handle - anon OK under relaxed R1 post-2026-05-15)
- Source location: TradingView script page, open-source script, published 2024-09-19.

## Mechanik

### Entry
- Long-only baseline on M5 or M15.
- Trade only during source windows: German open 08:00-12:00 and US open 15:30-19:00 local exchange/session time.
- Compute Bollinger Bands length 14, deviation 1.5.
- Compute EMA(10), EMA(200), RSI(7), ADX(7) with 7-period smoothing, ATR(14).
- Detect lateralization when price is near the Bollinger basis; P1 default: `abs(close - bb_basis) <= 0.25 * band_width`.
- Detect resistance as the highest high of the previous 20 candles, requiring at least two touches within a small tolerance.
- Long entry at bar close when:
  - Close breaks above the identified 20-bar resistance.
  - Lateralization condition is true before breakout.
  - Close is above EMA(10) and EMA(200).
  - RSI(7) > 30.
  - ADX(7) > 10.
  - The previous two candles are not both bearish.
  - Current candle closes bearish, matching the source "panic candle" filter.

### Exit
- Take profit at entry + 4.0 * ATR(14).
- Stop loss at entry - 2.0 * ATR(14).
- Flatten at session end if neither bracket level is hit.

### Stop Loss
- Source stop: 2.0 * ATR(14) below entry.
- P3 sweep: ATR stop multipliers 1.5, 2.0, 2.5 and target multipliers 3.0, 4.0, 5.0.

### Position Sizing
- V5 standard: `RISK_FIXED = $1,000` for P2 baseline. `RISK_PERCENT` for live.
- One open position per magic number.

### Zusaetzliche Filter
- Standard V5 spread, news, kill-switch, Friday-close, and max-DD filters.
- Best DWX ports: GER40.DWX, NDX.DWX, WS30.DWX, EURUSD.DWX, GBPUSD.DWX.

## Concepts
- [[concepts/opening-range-breakout]] - primary; post-open breakout after low-volatility consolidation.
- [[concepts/volatility-breakout]] - ATR bracket expects expansion after lateralization.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | PASS | Public TradingView URL and author handle MatteoRizzitelli are cited. |
| R2 Mechanical | PASS | Source gives exact time windows, BB/EMA/RSI/ADX filters, resistance breakout, and ATR stop/target. |
| R3 Data Available | PASS | OHLC, session clocks, BB, EMA, RSI, ADX, and ATR are available on DWX FX/index CFDs. |
| R4 ML Forbidden | PASS | Fixed indicator and breakout rules only; no ML, grid, martingale, DCA, or adaptive online parameters. |

## Pipeline-Verlauf
- G0: 2026-05-19 - drafted from TradingView top-script resume batch, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9165_tv-joovier-london-session-breakout]] - session breakout sibling from the same source family.

## Lessons Learned (waehrend Pipeline-Lauf)
- *(populated as pipeline progresses)*

## Implementation Notes for Codex (P1)
- Use broker/session conversion explicitly; source windows are human-market-open windows, not server-clock literals.
- Keep baseline long-only because the source is explicitly a post-open long strategy.
