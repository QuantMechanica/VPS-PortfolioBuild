---
ea_id: QM5_10219
slug: tv-open-impulse
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
target_symbols: [NDX.DWX, WS30.DWX, GER40.DWX, SP500.DWX, XAUUSD.DWX]
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/opening-range]]"
  - "[[concepts/momentum-breakout]]"
indicators:
  - "[[indicators/average-true-range]]"
  - "[[indicators/session-filter]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 70
last_updated: 2026-05-19
g0_approval_reasoning: "R1 TradingView URL/author cited; R2 mechanical open-time ATR impulse entry, candle stop, RR exit with ~70 trades/year/symbol; R3 testable on DWX intraday CFDs incl SP500 backtest caveat; R4 fixed non-ML one-position rules."
---

# TradingView Market Open Impulse

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `Market Open Impulse [LuciTech]`, author handle `TradesLuci`, published 2025-08-12, https://www.tradingview.com/script/5VVg9PqU-Market-Open-Impulse-LuciTech/

## Mechanik

### Entry
Use M5 execution. Activate only at the configured market-open timestamp; source default is 2:30 PM UK time. Compute ATR with the configured length. A candle qualifies as impulsive when its range exceeds the configured ATR multiple, default 1.5 * ATR. Long when the impulse candle closes above both its midpoint and the opening price. Short when the impulse candle closes below both its midpoint and the opening price.

### Exit
Use a risk-reward target, source default 3:1. Optional breakeven behavior may move stop to entry after the configured profit threshold; keep this disabled for first P2 pass unless the source code default confirms it.

### Stop Loss
Primary stop at the opposite extreme of the impulse candle: low for longs, high for shorts. Source also allows ATR-based stop calculation; include ATR stop as P3 variant, not baseline.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number. Ignore source percentage-risk sizing in the initial card.

### Zusatzliche Filter
One setup window per session. Use NDX/WS30/GER40 first because the edge is explicitly about market-open volatility; XAUUSD is a volatility cross-check. For SP500.DWX, use US cash open analog.

## Concepts (was ist das fur eine Strategie)
- [[concepts/opening-range]] - single-session open impulse capture.
- [[concepts/momentum-breakout]] - trades in the direction of a high-ATR opening candle.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `TradesLuci` are cited. |
| R2 Mechanical | PASS | Source gives session timing, ATR impulse threshold, long/short trigger, stop, RR target, and optional breakeven behavior. |
| R3 Data Available | PASS | Intraday OHLC, ATR, and session time are available on DWX index/gold CFDs. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. |
| R4 ML Forbidden | PASS | Fixed ATR impulse and bracket rules; no ML, grid, martingale, or performance-adaptive parameters. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView popular Pine strategy page.

## Verwandte Strategien
- [[strategies/QM5_10153_tv-mnq-orb15-confirm]] - opening-range breakout family.
- [[strategies/QM5_10164_tv-hilo-atr-break]] - first-window breakout with ATR trailing stop.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
