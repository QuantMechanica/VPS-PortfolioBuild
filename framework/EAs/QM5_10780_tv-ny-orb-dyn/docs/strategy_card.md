---
ea_id: QM5_10780
slug: tv-ny-orb-dyn
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
source_citation: "mcward302, NY ORB - Full Dynamic System, TradingView open-source strategy, https://www.tradingview.com/script/SYneoMiP-NY-ORB-Full-Dynamic-System/"
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/opening-range-breakout]]"
  - "[[concepts/intraday-session-pattern]]"
  - "[[concepts/atr-risk-management]]"
indicators:
  - "[[indicators/opening-range]]"
  - "[[indicators/atr]]"
  - "[[indicators/vwap]]"
  - "[[indicators/macd]]"
  - "[[indicators/rsi]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 100
last_updated: 2026-05-22
g0_approval_reasoning: "R1 exact TradingView URL/author; R2 mechanical ORB entry/filters/stops/targets/hard exit with ~100 trades/year/symbol; R3 DWX intraday OHLC/indicator/session testable incl SP500 caveat; R4 fixed non-ML one-position rules."
---

# TradingView NY ORB Dynamic System

## Quelle
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Page / Timestamp: TradingView script `NY ORB - Full Dynamic System`, author handle `mcward302`, open-source strategy, published 2025-11-02, accessed 2026-05-22, https://www.tradingview.com/script/SYneoMiP-NY-ORB-Full-Dynamic-System/

## Mechanik

### Entry
Use M1/M5/M15 intraday baseline.

- Build the opening range from the New York pre-market window; source default is 08:30-08:45 New York time.
- Allow entries only after the opening range is complete; source default entry window is 08:50-12:00.
- Long setup:
  - Price breaks above the opening range high.
  - Optional second-breakout mode: require price to break out, reverse back into the range, then break out upward again.
  - Optional confirmation-candle filter: require the close 1-2 bars ago to still be inside the range.
  - Optional filters pass: RSI not overbought, MACD line above signal, price above VWAP, and price above 50-period SMMA.
- Short setup mirrors long below the opening range low, with RSI not oversold, MACD below signal, price below VWAP, and price below 50-period SMMA.
- Enter only with no existing position.

### Exit
- Hard exit any open trade at the configured fixed time; source default is 13:25.
- Profit target is dynamically calculated from ATR or opening-range size.
- Optional MA-cross exit closes on counter-trend cross over SMMA or VWAP.
- V5 baseline disables daily PnL-adaptive blocking for P2, then tests static daily loss/profit limits separately.

### Stop Loss
- Test source stop modes as fixed ticks, ATR, capped ATR, and OR-range multiple.
- P2 baseline: ATR(14) stop with cap and fixed R target.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per symbol/magic.

### Zusatzliche Filter
- RSI, MACD, VWAP, and SMMA filters are separate ablation axes.
- Second-breakout mode is a separate entry-model axis.
- Daily loss/profit limits must be fixed thresholds, not adaptive online sizing.

## Concepts (was ist das fur eine Strategie)
- [[concepts/opening-range-breakout]] - uses pre-market ORB high/low as the trigger.
- [[concepts/intraday-session-pattern]] - depends on NY session timing and forced flat.
- [[concepts/atr-risk-management]] - dynamic stops/targets are ATR or range based.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `mcward302` are cited. |
| R2 Mechanical | PASS | Source defines ORB window, entry window, breakout/second-breakout logic, optional filters, stop modes, target modes, and hard exit time. |
| R3 Data Available | PASS | OHLC, ATR, RSI, MACD, VWAP proxy, SMMA, and session filters are available on DWX symbols. |
| R4 ML Forbidden | PASS | Fixed indicator/session rules; no ML, grid, martingale, or online learning. Adaptive breakeven is treated as a disabled/fixed-mode ablation. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD, GER40.DWX, NDX.DWX, WS30.DWX.

If this is later tested primarily on SP500.DWX, live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source says the ORB is built from the 08:30-08:45 New York pre-market window.
- Source says entries are generated when price breaks the ORB and optional filters align.
- Source says remaining positions are closed at a fixed hard exit time.

## Parameters To Test
- ORB window: 08:30-08:45, 09:30-09:45, first 15 minutes of local session.
- Entry window end: 11:00, 12:00.
- Second-breakout mode: off, on.
- Confirmation candle count: 0, 1, 2.
- Filters: none, VWAP only, VWAP+SMMA, VWAP+SMMA+MACD+RSI.
- Stop mode: ATR, capped ATR, OR-range.
- Target mode: ATR R target, OR-range target.
- MA-cross exit: off, VWAP, SMMA.

## Initial Risk Profile
Mechanically rich but high-dimensional. G0 should accept the rule source, while P3 must keep the search space controlled and avoid optimizing daily PnL guardrails into adaptive behavior.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- QM5_10770 tv-bigdaddy-orb
- QM5_10743 tv-nq-orb
- QM5_10779 tv-orb-fvg

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
