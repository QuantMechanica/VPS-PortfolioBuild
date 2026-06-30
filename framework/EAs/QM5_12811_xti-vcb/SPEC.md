# QM5_12811_xti-vcb - Strategy Spec

**EA ID:** QM5_12811
**Slug:** `xti-vcb`
**Source:** `BOLLINGER-BB-SQUEEZE-2001_XTI`
**Author of this spec:** Codex
**Last revised:** 2026-06-30

## 1. Strategy Logic

This EA implements a low-frequency WTI volatility-contraction breakout on
`XTIUSD.DWX`. On each new D1 bar, it computes Bollinger BandWidth on completed
daily closes, ranks the current BandWidth against a rolling lookback, and only
allows breakout entries when WTI is in a low-BandWidth state. A long requires a
close above the upper band, positive slow SMA slope, and a strong top-of-range
close. A short mirrors those rules below the lower band with negative slope.

The strategy is intentionally not a duplicate of the existing WTI family:
expiry-window, fixed weekday or month, WPSR, EIA event, OPEC, hurricane,
refinery, month-opening range, Williams box, 52-week anchor, seasonal, ratio,
broad time-series-momentum, Donchian, and commodity RSI pullback sleeves all
use different timing or entry logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bb_period` | 20 | 18-24 | Bollinger lookback on completed D1 closes |
| `strategy_bb_deviation` | 2.00 | 1.80-2.20 | Bollinger standard deviation multiplier |
| `strategy_bandwidth_lookback` | 126 | 84-189 | BandWidth rank window |
| `strategy_bandwidth_rank_max` | 0.20 | 0.15-0.25 | Maximum low-volatility rank allowed |
| `strategy_trend_period` | 80 | 50-120 | SMA trend confirmation |
| `strategy_sma_slope_shift` | 10 | 5-15 | Bars between current and prior SMA slope sample |
| `strategy_close_location_min` | 0.58 | 0.55-0.65 | Close-location threshold inside signal bar range |
| `strategy_break_buffer_atr` | 0.05 | 0.03-0.08 | ATR buffer beyond Bollinger band for entry confirmation |
| `strategy_atr_period` | 20 | 14-30 | ATR period for stop and target |
| `strategy_atr_sl_mult` | 2.75 | 2.25-3.25 | ATR stop distance multiplier |
| `strategy_atr_tp_mult` | 4.50 | 3.50-5.50 | ATR target distance multiplier |
| `strategy_max_hold_days` | 18 | 12-25 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.
- Not designed for `XNGUSD.DWX`, `XAUUSD.DWX`, `XAGUSD.DWX`, index symbols, FX
  symbols, or commodity ratio baskets.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 6-12.
- Typical hold: several D1 bars; capped at 18 calendar days by default.
- Regime preference: WTI expansion after a daily volatility contraction.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Bollinger, John. *Bollinger on Bollinger Bands*. McGraw-Hill, 2001.
Supplements: StockCharts ChartSchool Bollinger Band Squeeze,
https://chartschool.stockcharts.com/table-of-contents/trading-strategies-and-models/trading-strategies/bollinger-band-squeeze,
and CME Group Light Sweet Crude Oil Futures contract specifications,
https://www.cmegroup.com/markets/energy/crude-oil/light-sweet-crude.contractSpecs.html.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-06-30 | Initial WTI volatility-contraction breakout build |
