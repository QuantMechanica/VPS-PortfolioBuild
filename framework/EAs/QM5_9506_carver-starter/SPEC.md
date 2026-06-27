# QM5_9506 carver-starter - Strategy Spec

**EA ID:** QM5_9506
**Slug:** carver-starter
**Source:** 1a059d6d-84fa-5d0c-94c5-86dd0481637c (`sources/carver-leveraged-trading`)
**Author of this spec:** Codex
**Last revised:** 2026-06-27

## Strategy Logic

This EA mechanizes the approved Carver starter-system card as a daily symmetric trend follower. On each D1 closed bar it reads SMA(16) and SMA(64). A bullish crossover opens a long position; a bearish crossover opens a short position. Existing positions close on the opposite SMA state or after the configured maximum hold.

## Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_fast_sma_period` | 16 | Fast SMA lookback on D1 closes. |
| `strategy_slow_sma_period` | 64 | Slow SMA lookback on D1 closes. |
| `strategy_risk_lookback_bars` | 256 | D1 close-return window for annualized stop estimate. |
| `strategy_atr_period` | 25 | ATR lookback used to bound stop distance. |
| `strategy_annual_risk_mult` | 0.50 | Multiplier on annualized price standard deviation. |
| `strategy_min_atr_stop_mult` | 2.0 | Minimum stop distance in ATR units. |
| `strategy_max_atr_stop_mult` | 8.0 | Maximum stop distance in ATR units. |
| `strategy_max_hold_bars` | 252 | Time-stop horizon in D1 bars. |
| `strategy_min_history_bars` | 300 | Minimum D1 history before entries. |
| `strategy_spread_median_days` | 60 | D1 spread sample for entry filter. |
| `strategy_spread_mult` | 2.0 | Maximum current spread relative to median spread. |

## Symbol Universe

Registered Q02 basket:

- `EURUSD.DWX`
- `GBPUSD.DWX`
- `USDJPY.DWX`
- `AUDUSD.DWX`
- `USDCAD.DWX`
- `XAUUSD.DWX`
- `NDX.DWX`
- `WS30.DWX`

The basket follows the approved card's DWX-native FX/metals/index universe and avoids unavailable proxy symbols.

## Framework Mapping

- No-Trade: blocks non-D1 charts; framework handles kill-switch, news, and Friday close.
- Entry: D1 SMA(16/64) crossover using `QM_SMA`; spread filter and risk stop are checked on the framework new-bar path.
- Management: no trailing or add-on logic; initial SL carries the card's catastrophic stop.
- Close: opposite SMA state or max-hold time stop.
- News: default framework two-axis news gate.

## Risk Model

Backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`. Live sizing remains disabled in these artifacts.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-06-27 | Initial build from approved card `QM5_9506_carver-starter`. |
