---
ea_id: QM5_10205
slug: tv-chop-dmi-psar
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX]
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/regime-filter]]"
indicators:
  - "[[indicators/choppiness-index]]"
  - "[[indicators/dmi-adx]]"
  - "[[indicators/parabolic-sar]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 80
last_updated: 2026-05-20
g0_approval_reasoning: "R1 TradingView URL/author cited; R2 mechanical CHOP+DMI/ADX+PSAR entry/exit with plausible ~80 trades/year/symbol; R3 DWX FX/gold/index testable; R4 fixed non-ML one-position rules."
---

# TradingView CHOP DMI PSAR Trend Entry

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `CHOP Zone Entry Strategy + DMI/PSAR Exit`, author handle `IronCasper`, updated 2021-01-02, https://www.tradingview.com/script/GrP0zABg-CHOP-Zone-Entry-Strategy-DMI-PSAR-Exit/

## Mechanik

### Entry
Use H1 as the initial build timeframe.

- Compute Choppiness Index CHOP(14), optionally smoothed with length 4.
- Compute DMI/ADX with DI length 14 and ADX smoothing 14.
- Compute Parabolic SAR with source defaults: start 0.015, increment 0.001, max 0.2.
- Long entry:
  - CHOP is above 61.8, marking the source's bullish zone.
  - ADX is above the key level, default 25.
  - If follow-trend mode is enabled, PSAR/momentum state is bullish.
- Short entry:
  - CHOP is below 38.2, marking the source's bearish zone.
  - ADX is above the key level, default 25.
  - If follow-trend mode is enabled, PSAR/momentum state is bearish.
- Use one open position maximum; if an opposite entry appears on a close flag, reverse only after closing the current position.

### Exit
- Close long if ADX falls below the key level and -DI crosses above +DI.
- Close short if ADX falls below the key level and +DI crosses above -DI.
- If PSAR is enabled, close when PSAR trend state flips against the position.
- If DMI and PSAR are both disabled in a test variant, close long when CHOP drops below 38.2 and close short when CHOP rises above 61.8.

### Stop Loss
Use PSAR as the source trailing stop. Add V5 emergency stop at 3.0 * ATR(14) from entry if PSAR distance is unavailable or wider.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Target symbols: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX.
- Spread must be <= 15% of current PSAR/ATR stop distance.
- Disable CHOP offset for the baseline to avoid forward/backward displacement ambiguity.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - uses ADX/DMI and PSAR to stay with directional moves.
- [[concepts/regime-filter]] - CHOP zone gates entries by market condition.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `IronCasper` are cited. |
| R2 Mechanical | PASS | Source gives CHOP thresholds, DMI/ADX confirmation, PSAR filter, and close/reversal rules. |
| R3 Data Available | PASS | CHOP, DMI/ADX, PSAR, OHLC, and ATR are available on DWX FX, gold, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed indicator rules, no ML, no grid, no martingale, one-position compatible. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView popular Pine strategy page.

## Verwandte Strategien
- [[strategies/QM5_10188_tv-adx-di-ema-long]] - ADX/DI family, but this card adds CHOP and PSAR regime/exit logic.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
