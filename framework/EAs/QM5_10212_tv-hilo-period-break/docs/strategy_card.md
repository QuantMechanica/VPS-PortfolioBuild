---
ea_id: QM5_10212
slug: tv-hilo-period-break
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX]
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/breakout]]"
  - "[[concepts/momentum-continuation]]"
indicators:
  - "[[indicators/period-high-low]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 90
last_updated: 2026-05-19
g0_approval_reasoning: "R1 exact TradingView URL/author cited; R2 mechanical prior-period high/low breakout plus fixed-bar/opposite-break exit with ~90 trades/year/symbol; R3 OHLC/ATR testable on DWX FX/gold/index CFDs; R4 fixed non-ML one-position rules."
---

# TradingView High Low Period Breakout Hold

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `High/Low Breakout Statistical Analysis Strategy`, author handle `EdgeTools`, published 2024-09-24, https://www.tradingview.com/script/q5NHaxo5/

## Mechanik

### Entry
Use H1 for intraday baseline with previous-day high/low as the reference period. Long entry when price crosses over the selected period high. Short entry when price crosses under the selected period low. The source permits daily, weekly, or monthly reference periods; freeze P2 to daily to keep cadence sufficient.

### Exit
Close after a fixed holding period in bars. Start with 8 H1 bars for P2. Also close early on opposite reference breakout if it occurs before the holding timer expires.

### Stop Loss
Source is a statistical breakout shell without explicit stop. Add V5 protective stop at 1.5 * ATR(14) from entry. If the opposite side of the prior-day range is closer than the ATR stop, use the opposite side as the stop.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
Target symbols: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX. Skip entries if spread exceeds 15% of stop distance. Do not open new positions in the final two bars of the broker day.

## Concepts (was ist das fur eine Strategie)
- [[concepts/breakout]] - trades breach of a prior period high/low.
- [[concepts/momentum-continuation]] - fixed hold tests post-break drift.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `EdgeTools` are cited. |
| R2 Mechanical | PASS | Source defines selected-period high/low breakout, direction selection, and fixed bar holding exit. |
| R3 Data Available | PASS | Prior-period highs/lows, ATR, and OHLC are available on DWX FX, gold, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed breakout and holding-period rules; no ML, grid, martingale, pyramiding, or adaptive online parameters. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView popular Pine strategy page.

## Verwandte Strategien
- [[strategies/QM5_9986_tv-donchian20-breakout-flip]] - Donchian breakout family.
- [[strategies/QM5_10164_tv-hilo-atr-break]] - high/low breakout with ATR trail family.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
