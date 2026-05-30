---
ea_id: QM5_10193
slug: tv-asia-gc-brk
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
target_symbols: [XAUUSD.DWX, XAGUSD.DWX, GER40.DWX, NDX.DWX]
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/opening-range-breakout]]"
  - "[[concepts/session-breakout]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 120
last_updated: 2026-05-19
g0_approval_reasoning: "R1 URL/author cited; R2 mechanical Asia range breakout with EMA/ATR exits and ~120 trades/year/symbol; R3 directly testable on XAUUSD.DWX; R4 fixed-rule no ML/grid/martingale one-position compatible."
---

# TradingView Asia Gold Range Breakout

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `Asia Range Breakout Scalper (GC/Gold) [Strategy]`, author handle `bradenstrock`, published 2026-03-01, https://www.tradingview.com/script/igbGCjKb-Asia-Range-Breakout-Scalper-GC-Gold-Strategy/

## Mechanik

### Entry
Use M5/M15 bars on XAUUSD.DWX.

- During the Asia session in New York time, record session high and session low.
- After the Asia session ends, trade only within the configured following trading window.
- Optional 200 EMA filter frozen ON:
  - Longs only when close > EMA(200).
  - Shorts only when close < EMA(200).
- Long entry: price breaks above Asia range high plus configurable buffer.
- Short entry: price breaks below Asia range low minus configurable buffer.
- Limit to one active position and one trade per direction per day.

### Exit
- Source management is ATR stop and ATR take profit, with optional trailing.
- Baseline TP = 2.0 * ATR(14) from entry.
- Baseline SL = 1.0 * ATR(14) from entry.
- Close any still-open position at end of the post-Asia trading window.

### Stop Loss
ATR(14) stop at 1.0x ATR from entry, trailed only if the optional trailing mode is enabled in P3 sweeps.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Primary symbol: XAUUSD.DWX. Optional cross-checks: XAGUSD.DWX, GER40.DWX, NDX.DWX.
- Spread must be <= 15% of ATR stop distance.
- Skip days where Asia range height < 0.5 * ATR(14) or > 3.0 * ATR(14) to avoid dead/noisy sessions.

## Concepts (was ist das fur eine Strategie)
- [[concepts/opening-range-breakout]] - trades break of a pre-defined session range.
- [[concepts/session-breakout]] - exploits post-Asia volatility expansion in gold.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `bradenstrock` are cited. |
| R2 Mechanical | PASS | Source gives Asia high/low capture, breakout buffer, EMA filter, ATR exits, daily limits, and end-window close. |
| R3 Data Available | PASS | XAUUSD.DWX is directly testable; session, EMA, and ATR logic are available in MT5. |
| R4 ML Forbidden | PASS | Fixed session/EMA/ATR rules, no ML, no grid, no martingale, and one-position-per-magic compatible. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_9988_tv-opening-range-breakout-dual]] - opening-range family, but this card is Asia-session gold-specific.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
