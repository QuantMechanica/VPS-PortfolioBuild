---
ea_id: QM5_10158
slug: tv-es-wicklength-hold
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/candlestick-pattern]]"
  - "[[concepts/volatility-expansion]]"
indicators:
  - "[[indicators/moving-average]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 160
last_updated: 2026-05-19
g0_approval_reasoning: "R1 exact TradingView URL and author handle cited; R2 deterministic wick-length MA long entry with fixed-bar/ATR exits and ~160 trades/year/symbol; R3 ES analog testable on SP500.DWX backtest plus NDX/WS30 live fallbacks with T6 caveat; R4 no ML/grid/martingale/adaptive parameters or pyramiding."
---

# TradingView ES Wick Length Hold

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `Daytrading ES Wick Length Strategy`, author handle `EdgeTools`, published 2024-12-31, https://www.tradingview.com/script/m78ZqKsX/

## Mechanik

### Entry
Use 30-minute or 1-hour bars for index-CFD baseline.

- Compute upper wick length: `high - max(open, close)`.
- Compute lower wick length: `min(open, close) - low`.
- Compute total wick length: `upper_wick + lower_wick`.
- Compute moving average of total wick length; source supports SMA, EMA, WMA, and VWMA.
- Baseline: SMA(20) of total wick length.
- Long: total wick length exceeds the moving-average value plus the configured offset.

### Exit
- Source exits automatically after a user-defined holding period.
- Baseline holding period: 8 bars on M30 or 4 bars on H1.
- Exit earlier if protective stop is hit.

### Stop Loss
- Source does not specify a price stop in public text.
- V5 protective default: 1.5 ATR from entry, or below the signal candle low if tighter.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Long-only source. Do not add shorts during baseline.
- Offset default: 0.0 MA units; sweep positive offsets in P3 if P2 survives.
- Primary port: SP500.DWX for ES analog; secondary ports NDX.DWX and WS30.DWX.

## Concepts (was ist das fur eine Strategie)
- [[concepts/candlestick-pattern]] - primary
- [[concepts/volatility-expansion]] - unusually long wick as trigger

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `EdgeTools` are cited. |
| R2 Mechanical | PASS | Source defines total-wick calculation, moving-average comparison with offset, long entry, and fixed-bar holding exit. |
| R3 Data Available | PASS | ES source ports to SP500.DWX backtest analog and live-tradable NDX.DWX/WS30.DWX alternatives. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. |
| R4 ML Forbidden | PASS | No ML, neural net, grid, martingale, adaptive online parameters, or pyramiding described. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10156_tv-candle-close-pattern]] - related candle-derived signal.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
