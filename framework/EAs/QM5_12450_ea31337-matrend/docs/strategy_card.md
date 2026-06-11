---
ea_id: QM5_12450
slug: ea31337-matrend
type: strategy
source_id: 041e0d5c-bf76-501d-bee2-31c0f4a6e233
sources:
  - "[[sources/github-mql5-topic]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/multi-timeframe]]"
indicators:
  - "[[indicators/moving-average]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 60
last_updated: 2026-05-26
g0_approval_reasoning: "R1 single source_id with exact EA31337 MA Trend repo/file; R2 deterministic current/D1 MA slope-threshold entries plus fixed/time/opposite exits with plausible H1 cadence gated by D1 trend; R3 OHLC/MA logic portable to DWX CFDs; R4 deterministic no ML/martingale/multi-position."
---

# EA31337 Multi-Timeframe Moving Average Trend

## Quelle
- Source citation: 2026 URL https://github.com/EA31337/Strategy-MA_Trend
- Source: [[sources/github-mql5-topic]]
- Primary URL: https://github.com/topics/mql5
- Exact repository: https://github.com/EA31337/Strategy-MA_Trend
- Exact source file: https://github.com/EA31337/Strategy-MA_Trend/blob/master/Stg_MA_Trend.mqh
- Parent strategy collection: https://github.com/EA31337/EA31337-strategies
- Author / institution: EA31337 Ltd / `EA31337`, GitHub repository `Strategy-MA_Trend`
- Location: `Stg_MA_Trend.mqh` header, user inputs, `PriceStop()`, and `SignalOpen()`.

## Mechanik

### Entry
Use the selected MA-family indicator on the chart timeframe and the same indicator on D1. Source defaults include `SignalOpenMethod=8`, `SignalOpenLevel=7.0`, max spread 4 pips, and close loss/profit/time controls.

Long:
- Absolute D1 indicator change from the prior bar exceeds `SignalOpenLevel` in pips.
- Chart-timeframe indicator is increasing on the closed bar.
- D1 indicator is increasing on the closed bar.
- D1 indicator change is positive and greater than the level threshold.
- Source method bit 3 default requires current chart-timeframe value to be the maximum of the last four values.
- Open one long.

Short:
- Absolute D1 indicator change from the prior bar exceeds `SignalOpenLevel` in pips.
- Chart-timeframe indicator is decreasing on the closed bar.
- D1 indicator is decreasing on the closed bar.
- Source method bit 3 default requires current chart-timeframe value to be the minimum of the last four values.
- Open one short.

### Exit
- Source default close controls: close loss 80, close profit 80, close time `-30` bars.
- V5 baseline: fixed SL/TP plus 30-bar time exit; close early on opposite MA trend signal.

### Stop Loss
- Source `PriceStop()` can place SL around the D1 indicator and TP by the distance between D1 and chart-timeframe indicators.
- V5 baseline: source-style D1 MA stop where feasible, otherwise ATR-scaled protective stop.

### Position Sizing
- Backtest: V5 default fixed risk $1,000 per trade.
- Live candidate: V5 default percent risk after pipeline approval.

### Zusaetzliche Filter
- One position per symbol/magic.
- Max spread 4 pips.
- Closed-bar evaluation only.
- Suggested baseline period: H1.
- Suggested first universe: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, DAX.DWX.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/trend-following]] -- primary; requires same-direction indicator slope on current timeframe and D1.
- [[concepts/multi-timeframe]] -- secondary; D1 trend strength gates lower-timeframe entries.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | Single `source_id`; public GitHub topic plus exact EA31337 repository/file and named institution. |
| R2 Mechanical | PASS | Current/D1 slope checks, pips threshold, four-bar extreme confirmation, stop logic, spread cap, and exits are explicit. |
| R3 Data Available | PASS | OHLC and moving-average family indicators are available or computable on DWX Forex, metal, and index CFDs. |
| R4 ML Forbidden | PASS | Deterministic multi-timeframe indicator rule; no ML, online adaptation, martingale, or multi-position requirement. |

## Pipeline-Verlauf
- G0: 2026-05-26, PENDING, drafted from GitHub topic:mql5 top-starred repository mining.

## Verwandte Strategien
- [[strategies/QM5_12449_ea31337-mabrk]] -- same source family, MA breakout logic.

## Lessons Learned (waehrend Pipeline-Lauf)
- 2026-05-26: Q01 should verify the MA-family selector default and normalize `SignalOpenLevel=7.0` by symbol pip size.
