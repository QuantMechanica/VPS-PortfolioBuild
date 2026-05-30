---
ea_id: QM5_10203
slug: tv-actionzone-atr-rev
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX, WS30.DWX]
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/reversal-system]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 100
last_updated: 2026-05-19
g0_approval_reasoning: "R1 TradingView URL and author cited; R2 EMA cross reversal plus ATR/RSI stop rules mechanical and high cadence; R3 indicators testable on listed DWX FX/gold/index CFDs; R4 fixed rules one position no ML/grid/martingale."
---

# TradingView ActionZone ATR Reversal

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `action zone - ATR stop reverse order strategy v0.1 by 9nck`, author handle `fenirlix`, updated 2022-01-24, https://www.tradingview.com/script/C6b8iwJt-action-zone-ATR-stop-reverse-order-strategy-v0-1-by-9nck/

## Mechanik

### Entry
Use H1 bars in baseline.

- Baseline fast EMA length: 9; slow EMA length: 21, matching the source's suggested fast 7-10 / slow 17-22 zone.
- Long entry: fast EMA crosses above slow EMA while flat.
- Short entry: fast EMA crosses below slow EMA while flat.
- If already positioned, an opposite crossover closes the current side and reverses on the next bar, subject to minimum hold.

### Exit
- Opposite fast/slow EMA crossover exits and reverses after the minimum hold period.
- ATR stop exits immediately even before minimum hold.

### Stop Loss
- Source flex stop is fast EMA +/- middle ATR.
- Long stop = max(prior stop, fast EMA - 1.5 * ATR(14)).
- Short stop = min(prior stop, fast EMA + 1.5 * ATR(14)).
- For long positions, if a bar is overbought per RSI(14) > 70, raise stop to that bar's low. For short positions, if RSI(14) < 30, lower stop to that bar's high.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Target symbols: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX, WS30.DWX.
- Minimum hold period: 3 bars, except ATR stop may always close.
- Do not calculate on every tick; confirmed bar close only.
- Spread must be <= 15% of stop distance.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - EMA cross direction.
- [[concepts/reversal-system]] - always-ready opposite crossover reversal with ATR stop.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `fenirlix` are cited. |
| R2 Mechanical | PASS | Source gives EMA cross entries/reversals, ATR-derived stop, minimum hold, and bar-close execution guidance. |
| R3 Data Available | PASS | EMA, ATR, RSI, and OHLC logic is testable on DWX FX, gold, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed indicator rules and one active position; no ML, grid, martingale, or pyramiding. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10202_tv-dema-atr-scaleout]] - related ATR trend-following family with DEMA substrate.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
