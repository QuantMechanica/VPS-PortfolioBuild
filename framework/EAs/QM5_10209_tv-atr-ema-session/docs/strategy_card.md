---
ea_id: QM5_10209
slug: tv-atr-ema-session
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
target_symbols: [GER40.DWX, NDX.DWX, WS30.DWX, XAUUSD.DWX, EURUSD.DWX]
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/intraday-momentum]]"
  - "[[concepts/volatility-regime]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/ema]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 120
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS TradingView URL/author cited; R2 PASS ATR/EMA/session entry and TP/SL/EOD exits with ~120 trades/year/symbol; R3 PASS portable to DWX FX/gold/index CFDs; R4 PASS fixed non-ML one-position rules."
---

# TradingView ATR EMA Session Volatility Switch

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `ATR EMA Strategy`, author handle `whitebear28`, published 2026-04-13, https://www.tradingview.com/script/uKRleT8B-ATR-EMA-Strategy/

## Mechanik

### Entry
Use M15 or M30 bars inside the configured trading session.

- Compute ATR(25).
- Compute EMA(50).
- Baseline session window: 09:00-17:30 exchange/server mapped to target symbol local liquid hours.
- Long entry:
  - ATR(25) is below the long threshold, source default 20.
  - Price crosses above EMA(50).
- Short entry:
  - ATR(25) is above the short threshold, source default 25.
  - Price crosses below EMA(50).
- Respect max daily trades, source default 3.

### Exit
Each position exits on the first of:

- Take profit at entry +/- 5.0 * ATR(25).
- Stop loss at entry -/+ 10.0 * ATR(25).
- End-of-day/session close.

### Stop Loss
Use the source ATR stop: 10.0 * ATR(25) from entry. Cap in P1 smoke if broker stop-distance or margin makes the baseline infeasible.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Target symbols: GER40.DWX, NDX.DWX, WS30.DWX, XAUUSD.DWX, EURUSD.DWX.
- Because source ATR thresholds are price-unit dependent, P1/P2 should normalize thresholds by symbol point value or run an initial conservative threshold mapping per symbol. The source logic itself remains fixed: low ATR permits longs, high ATR permits shorts.
- Spread must be <= 10% of ATR stop distance.

## Concepts (was ist das fur eine Strategie)
- [[concepts/intraday-momentum]] - trades EMA cross signals only inside the session.
- [[concepts/volatility-regime]] - uses ATR regime to switch long/short permission.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `whitebear28` are cited. |
| R2 Mechanical | PASS | Source gives ATR thresholds, EMA cross entries, session gate, TP, SL, EOD exit, and daily trade cap. |
| R3 Data Available | PASS | ATR, EMA, OHLC, and session time are available on DWX FX, gold, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed indicators and fixed exits; no ML, grid, martingale, or live performance-adaptive parameters. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView popular Pine strategy page.

## Verwandte Strategien
- [[strategies/QM5_10175_tv-atr-ema-vwap]] - ATR/EMA trend family, but this card uses ATR regime thresholds and session/EOD exits.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
