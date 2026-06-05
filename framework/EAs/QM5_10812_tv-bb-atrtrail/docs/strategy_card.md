---
ea_id: QM5_10812
slug: tv-bb-atrtrail
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
source_citation: "hamsung, bolinger band breakout + atr trailing stop strategy [running], TradingView invite-only strategy page, visible 2026-05-22, https://www.tradingview.com/script/MwlYnQZT/"
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/bollinger-band-breakout]]"
  - "[[concepts/volatility-trailing-stop]]"
indicators:
  - "[[indicators/bollinger-bands]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 70
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS exact TradingView URL/author cited; R2 PASS mechanical BB/SMA breakout with ATR trailing stop and ~70 trades/year/symbol; R3 PASS DWX OHLC indicators available; R4 PASS fixed-rule no ML/grid/martingale."
---

# TradingView BB ATR Trail Breakout

## Quelle
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Page / Timestamp: TradingView script `bolinger band breakout + atr trailing stop strategy [running]`, author handle `hamsung`, invite-only strategy page with visible rules, accessed 2026-05-22, https://www.tradingview.com/script/MwlYnQZT/

## Mechanik

### Entry
Use H1/H4/D1 baseline.

- Compute Bollinger Bands; baseline length 20, deviation 2.0 unless code/defaults reveal otherwise.
- Compute SMA(200).
- Long entry when close crosses above the upper Bollinger Band and close is above SMA(200).
- Short entry when close crosses below the lower Bollinger Band and close is below SMA(200).
- Enter only when flat.
- One open position per symbol/magic.

### Exit
- Source exit is an ATR trailing stop based on median price.
- For long: stop = max(previous stop, hl2 - 3.0 * ATR(14)).
- For short: stop = min(previous stop, hl2 + 3.0 * ATR(14)).
- Close immediately when price touches the stop level; MT5 implementation uses stop order simulation at bar high/low in backtest.

### Stop Loss
- Initial stop is the ATR trailing stop at entry.
- Stop never widens after entry.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per symbol/magic.

### Zusatzliche Filter
- Recommended source timeframes are H1, H4, and D1.
- Optional no-trade filter for low volatility: skip when Bollinger bandwidth is below its 100-bar median.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - trades in direction of SMA200-filtered breakout.
- [[concepts/bollinger-band-breakout]] - entry is outer-band momentum expansion.
- [[concepts/volatility-trailing-stop]] - exit uses ATR trail.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `hamsung` are cited. Invite-only pages are acceptable if visible rules are attributable. |
| R2 Mechanical | PASS | Visible page gives long/short entry, SMA filter, ATR trailing stop formula, and flat-only entry. |
| R3 Data Available | PASS | Bollinger Bands, SMA, ATR, hl2, and OHLC are available on DWX symbols. |
| R4 ML Forbidden | PASS | Fixed indicator rules and fixed ATR trail; no ML, grid, martingale, or adaptive online parameters. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD, GER40.DWX, NDX.DWX, WS30.DWX.

If this is later tested primarily on SP500.DWX, live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source describes a Bollinger breakout system with SMA(200) trend alignment.
- Source describes an ATR trailing stop calculated from median price with multiplier 3.0.
- Source recommends H1, H4, and D1 for more established trends.

## Parameters To Test
- Bollinger length/deviation: 20/2.0, 30/2.0, 20/2.5.
- SMA filter: 100, 200.
- ATR length: 14, 20.
- ATR trail multiplier: 2.0, 3.0, 4.0.
- Timeframe: H1, H4, D1.

## Initial Risk Profile
Classic volatility breakout with trend filter. Main risk is whipsaw after false outer-band breaks; ATR trail should bound losses but may give back open profit.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- QM5_10810 tv-bb80-daily
- QM5_10790 tv-bb-trend

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD

