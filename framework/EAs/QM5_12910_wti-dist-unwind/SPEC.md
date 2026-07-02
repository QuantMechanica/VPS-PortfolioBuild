# QM5_12910_wti-dist-unwind - Strategy Spec

**EA ID:** QM5_12910
**Slug:** `wti-dist-unwind`
**Source:** `EIA-DISTILLATE-CRACK-SEASON-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-02

## 1. Strategy Logic

This EA implements a structural WTI D1 sleeve on `XTIUSD.DWX`. It trades only
inside the March-April post-winter distillate-crack unwind window. The entry is
short-only: prior closed D1 bar must be below a falling slow SMA and must close
below the prior channel low, confirming downside continuation after the EIA
October-February distillate crack-spread peak season has ended.

The strategy is intentionally distinct from winter distillate long breakout or
pullback builds, refinery shoulder stretch fades, gasoline/RBOB/jet-fuel
seasonal sleeves, WPSR/event timing, XTI/XNG or metal ratio baskets, and
`QM5_12567` RSI commodity pullback logic. Runtime uses only MT5 OHLC, spread,
ATR, SMA, broker calendar, and V5 framework state; it does not import EIA or
crack-spread data.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_start_month` | 3 | 3 | Start month for unwind window |
| `strategy_start_day` | 1 | 1 | Start day for unwind window |
| `strategy_end_month` | 4 | 4 | End month for unwind window |
| `strategy_end_day` | 30 | 15-30 | End day for unwind window |
| `strategy_trend_period` | 63 | 50-84 | Slow SMA trend period |
| `strategy_sma_slope_shift` | 10 | 5-15 | Bars back for SMA slope test |
| `strategy_breakdown_lookback` | 8 | 5-12 | Prior completed D1 bars for entry breakdown low |
| `strategy_exit_channel` | 8 | 5-12 | Prior completed D1 bars for recovery exit high |
| `strategy_atr_period` | 20 | 14-30 | ATR period for hard stop |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | ATR stop distance |
| `strategy_max_hold_days` | 12 | 8-18 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-10.
- Typical hold: one to two trading weeks, subject to Friday close.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration, "What drives petroleum product prices:
Prices and Crack Spreads", https://www.eia.gov/finance/markets/products/prices.php.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-02 | Initial build from card | Enqueue Q02 |
