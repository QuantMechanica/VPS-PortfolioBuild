---
ea_id: QM5_10709
slug: tv-orb-multitp
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
source_citation: "TradingView script `Open Range Breakout Strategy With Multi TakeProfit`, author handle `Milvetti`, open-source strategy, published 2025-08-13 per TradingView page, https://www.tradingview.com/script/Tr0vgxkq-Open-Range-Breakout-Strategy-With-Multi-TakeProfit/"
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/opening-range-breakout]]"
  - "[[concepts/session-momentum]]"
  - "[[concepts/scaled-exit]]"
indicators: []
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 180
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS linked TradingView source; R2 PASS mechanical opening-range breakout with stop, multi-TP/session exit and ~180 trades/year/symbol; R3 PASS DWX FX/gold/index testable with SP500 T6 caveat; R4 PASS fixed non-ML one-position-compatible rules."
---

# TradingView Open Range Breakout Multi Take Profit

## Quelle
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Page / Timestamp: TradingView script `Open Range Breakout Strategy With Multi TakeProfit`, author handle `Milvetti`, open-source strategy, TradingView page shows Aug 13, 2025, https://www.tradingview.com/script/Tr0vgxkq-Open-Range-Breakout-Strategy-With-Multi-TakeProfit/

## Mechanik

### Entry
Use M5 or M15 bars and trade both directions during a configurable intraday trade session.

- Define an opening range from the first 15, 30, or 60 minutes of the selected session; baseline uses the first 30 minutes.
- Lock `or_high` and `or_low` after the range window ends.
- Long entry when price breaks above `or_high` during the trade session.
- Short entry when price breaks below `or_low` during the trade session.
- Allow only the first valid breakout per direction per session; no pyramiding.

### Exit
- Use two take-profit targets calculated from initial risk.
- Baseline split: 50% at 1.0R, 50% at 2.0R.
- Force-close remaining position at the end of the configured trade session.

### Stop Loss
- Baseline stop mode: opposite side of opening range.
- Alternative parameter sweep: stop at midpoint of the opening range.
- Skip trades where opening-range width is less than 0.15% or greater than 1.25% of price.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number. Partial exits must be implemented as one net position with deterministic reduce-only exits.

### Zusatzliche Filter
- Target symbols: GER40.DWX, NDX.DWX, WS30.DWX, EURUSD.DWX, XAUUSD.DWX.
- SP500.DWX can be used for backtest-only comparison. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Concepts (was ist das fur eine Strategie)
- [[concepts/opening-range-breakout]] - trades continuation beyond the early-session range.
- [[concepts/session-momentum]] - range breakout is only valid during the selected intraday session.
- [[concepts/scaled-exit]] - two fixed R targets reduce the position deterministically.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `Milvetti` are cited. |
| R2 Mechanical | PASS | Source defines opening range, breakout direction, stop modes, two TP targets, and session close. |
| R3 Data Available | PASS | Uses OHLC and session times; portable to DWX FX, gold, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed non-ML rules, no grid, no martingale; partial exits are deterministic under one magic number. |

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from TradingView mechanical strategy source.

## Verwandte Strategien
- [[strategies/QM5_10658_tv-orb-vwap]] - ORB with VWAP and volume filters.
- [[strategies/QM5_10701_tv-or-ny-rr]] - New York opening-range breakout with fixed percentage SL.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
