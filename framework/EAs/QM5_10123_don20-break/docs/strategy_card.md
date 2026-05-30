---
ea_id: QM5_10123
slug: don20-break
type: strategy
source_id: d3c009d7-a8d6-5251-b572-4777b207c2b9
sources:
  - "[[sources/raposa-trade-python-backtesting]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/breakout]]"
indicators:
  - "[[indicators/donchian-channel]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
period: D1
expected_trades_per_year_per_symbol: 10
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source URL/mirror cited; R2 Donchian breakout entry/exit mechanical with ~10 trades/year/symbol; R3 OHLC-only portable to DWX symbols; R4 fixed-rule no ML/grid/martingale."
---

# 20 Day Donchian Channel Breakout

## Quelle
- Source: [[sources/raposa-trade-python-backtesting]]
- Primary URL: https://raposa.trade/blog/three-strategies-for-trading-the-donchian-channel-in-python/
- Accessible mirror used for rule extraction: https://readmedium.com/use-python-to-trade-the-donchian-channel-6bf59d0bc740
- Author / institution: Raposa.Trade / Raposa Technologies
- Date: Aug. 15, 2022
- Page / Timestamp: "Example Strategy 2: Donchian Channel Breakout"

## Mechanik

### Entry
- Calculate upper/lower Donchian channel over `N` periods.
- Default from source example: `N = 20`.
- Enter long when `Close > upperDon[1]`, i.e. close breaks above yesterday's upper Donchian bound.
- Optional short mode: enter short when `Close < lowerDon[1]`.

### Exit
- Long-only mode: exit to flat when `Close < lowerDon[1]`.
- Long/short mode: reverse short when `Close < lowerDon[1]`; reverse long when `Close > upperDon[1]`.
- Source code forward-fills position until the opposite/exit signal appears.

### Stop Loss
- Source simple backtest does not add a separate stop.
- Research default: add emergency `3 * ATR(14)` stop for MT5 risk containment, while preserving lower-channel exit as primary close.

### Position Sizing
- Source vectorized example does not define position sizing.
- Use V5 fixed-risk baseline for P2.

### Zusaetzliche Filter
- Timeframe: D1.
- Use prior channel (`shift(1)`) to avoid lookahead.
- Minimum history: `N + 1` completed daily bars.
- Start long-only; short-enabled variant can be swept.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/breakout]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | Verifiable Raposa.Trade URL/mirror and named author handle. |
| R2 Mechanical | PASS | Entry and exit/reversal are direct channel breakout rules in source code. |
| R3 Data Available | PASS | OHLC-only rule; portable to DWX FX, metals, oil, and indices. |
| R4 ML Forbidden | PASS | Deterministic fixed lookback breakout; no ML/adaptive/grid/martingale. |

## R3
Raposa example used XOM daily data; port mechanically to DWX symbols. If SP500.DWX is used: Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source says the basic idea is to go long when price breaks through the upper channel and short or exit when price breaks below the lower channel.
- Source reports this breakout model further separated itself from buy-and-hold and had better stats than the midline cross-over on the sample.

## Parameters To Test
- `donchian_period`: 10, 20, 40, 55
- `shorts_enabled`: false, true
- `atr_stop_mult`: 2.0, 3.0, 4.0
- `use_previous_bar_channel`: true

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, Research draft from Raposa mechanical tutorial.

## Verwandte Strategien
- [[strategies/QM5_10122_don-mid-cross]] - Donchian midline cross-over.
- [[strategies/QM5_10121_don100-trail]] - long-term Donchian breakout with trailing stop.

## Lessons Learned
- TBD
