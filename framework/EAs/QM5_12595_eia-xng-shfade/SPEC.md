# QM5_12595_eia-xng-shfade - Strategy Spec

**EA ID:** QM5_12595
**Slug:** `eia-xng-shfade`
**Source:** `EIA-XNG-SHOULDER-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-27

## 1. Strategy Logic

This EA implements a low-frequency structural natural-gas sleeve on `XNGUSD.DWX`. It trades only in April-May and September-October, fading bearish rejection bars that stretch at least 1.25 ATR above SMA(63) and tag a recent D1 high. Positions exit on mean reversion to SMA(63), channel invalidation, shoulder-window expiry, max-hold timeout, or the fixed ATR stop.

The strategy is intentionally not a duplicate of `QM5_12567_cum-rsi2-commodity`: it does not use RSI or short-horizon pullback logic. It is also distinct from the existing XNG EIA trend/event builds because it is short-only shoulder-season failed-rally mean reversion rather than broad monthly seasonality, storage aftershock, winter breakout, injection breakdown, or summer squeeze.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_reject_lookback` | 20 | 15-30 | Previous-bar D1 channel for failed-rally high test |
| `strategy_exit_channel` | 10 | 7-15 | Previous-bar D1 channel for short invalidation |
| `strategy_trend_period` | 63 | 42-84 | Slow D1 SMA mean |
| `strategy_atr_period` | 20 | 14-30 | ATR period for stretch filter and stop |
| `strategy_min_stretch_atr` | 1.25 | 1.0-1.75 | Minimum close stretch above SMA in ATR units |
| `strategy_min_upper_wick_ratio` | 0.35 | 0.25-0.50 | Minimum upper wick as share of signal-bar range |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | Stop distance multiplier |
| `strategy_max_hold_days` | 7 | 5-10 | Calendar-day time exit |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` - Darwinex custom natural-gas CFD with D1 history available in the symbol matrix; this is the intended energy sleeve.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 6.
- Typical hold: several days to one trading week, segmented by Friday close.
- Regime preference: spring/fall natural-gas shoulder periods where failed rallies can mean-revert toward a slow D1 mean.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Natural gas consumption, production respond to seasonal changes", Today in Energy, 2015-09-24, URL https://www.eia.gov/todayinenergy/detail.php?id=22892. Supplemental source: U.S. Energy Information Administration, Weekly Natural Gas Storage Report, URL https://www.eia.gov/naturalgas/storage/.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest or `T_Live` file is touched by this build.

## Revision History

| Version | Date | Change | Actor |
|---|---|---|---|
| v1 | 2026-06-27 | Initial structural XNG shoulder-season failed-rally fade build | Codex |
