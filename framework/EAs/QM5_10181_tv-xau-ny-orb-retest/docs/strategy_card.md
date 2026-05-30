---
ea_id: QM5_10181
slug: tv-xau-ny-orb-retest
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/opening-range-breakout]]"
  - "[[concepts/retest-entry]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 110
last_updated: 2026-05-19
g0_approval_reasoning: "R1 exact TradingView URL/author cited; R2 deterministic NY ORB breakout/retest with exits and ~110 trades/year/symbol; R3 testable on XAUUSD.DWX/index CFD ports; R4 no ML/grid/martingale and one-position baseline."
---

# TradingView XAU NY ORB Retest

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `XAUUSD - NY ORB Advanced`, author handle `DanTheMan278`, published 2026-05-16, https://www.tradingview.com/script/XhSNuRUR-XAUUSD-NY-ORB-Advanced/

## Mechanik

### Entry
Use M5 bars, long and short.

- Compute 1H EMA(50) for directional bias.
- Long bias: 1H close > 1H EMA(50). Short bias: 1H close < 1H EMA(50).
- Build the New York opening range from 09:30 to 09:45 EST; no trades during range formation.
- Skip the day if opening-range height > 2.0 ATR(14) on M5.
- Long breakout confirmation: a strong M5 candle closes above OR high, body >= 70% of candle range, and candle range >= 1.2 ATR(14), while long bias is true.
- Short breakout confirmation: mirror below OR low while short bias is true.
- Retest entry: after confirmed breakout, wait for price to pull back to the broken OR level and then close back in breakout direction.
- Maximum one trade per day.

### Exit
- Source scales out 50% at 1R and targets the remainder at configurable RR.
- V5 baseline closes the full position at 2.5R to preserve one position per magic number.
- Protective stop: most recent confirmed swing pivot beyond the retest level; baseline pivot length 3 left / 3 right.
- Time exit: close any open position by 16:00 New York time.

### Stop Loss
- Stop at most recent structural pivot. If pivot stop distance is less than 0.5 ATR(14), widen to 0.5 ATR(14).
- Skip trade if stop distance exceeds 2.5 ATR(14).

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Primary DWX symbol: XAUUSD.DWX.
- Secondary robustness ports: NDX.DWX, WS30.DWX, GER40.DWX.
- Skip NFP, FOMC, CPI, and other high-impact USD release windows.

## Concepts (was ist das fur eine Strategie)
- [[concepts/opening-range-breakout]] - NY open defines the intraday breakout range.
- [[concepts/retest-entry]] - entry waits for pullback and rejection after breakout confirmation.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `DanTheMan278` are cited. |
| R2 Mechanical | PASS | Source specifies 1H EMA bias, 09:30-09:45 OR, strong-candle breakout, retest entry, pivot stop, RR target, and one trade per day. |
| R3 Data Available | PASS | Source targets XAUUSD directly; XAUUSD.DWX is available and logic ports to DWX index CFDs. |
| R4 ML Forbidden | PASS | No ML, neural net, grid, martingale, pyramiding, or adaptive parameters. Source partial close is simplified to a single full-position exit. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10153_tv-mnq-orb15-confirm]] - related 15-minute ORB confirmation family.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
