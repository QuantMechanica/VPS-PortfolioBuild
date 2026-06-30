# QM5_12829_wti-cushing-fade - Strategy Spec

**EA ID:** QM5_12829
**Slug:** `wti-cushing-fade`
**Source:** `EIA-CUSHING-STORAGE-2021`
**Author of this spec:** Codex
**Last revised:** 2026-06-30

## 1. Strategy Logic

This EA implements a low-frequency structural crude-oil relief sleeve on
`XTIUSD.DWX`. Entries are evaluated only on the first D1 bar of a new
broker-calendar week. The short setup waits for the prior completed D1 bar to
pierce a multi-month channel high, fail back below that channel by the close,
and close weakly in the lower part of its own range while the broader trend is
still up.

The source lineage is Cushing delivery-hub tightness. The card deliberately
uses no Cushing inventory file, EIA runtime feed, futures curve, CSV, API, or
external input in MT5. Runtime data is limited to Darwinex MT5 `XTIUSD.DWX`
OHLC, broker calendar, spread, SMA, and ATR calculations.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_channel_lookback_d1` | 63 | 42-84 | Prior completed bars for the channel high, excluding the signal bar |
| `strategy_return_lookback_d1` | 21 | 14-42 | Completed D1 bars for recent return pressure |
| `strategy_fast_sma_period` | 20 | 15-30 | Fast trend and close-exit SMA |
| `strategy_slow_sma_period` | 126 | 84-168 | Slow trend filter |
| `strategy_min_pierce_margin_pct` | 0.50 | 0.25-0.75 | Required signal high pierce above prior channel high |
| `strategy_min_return_pct` | 4.0 | 2.0-6.0 | Minimum recent upside pressure before fade |
| `strategy_max_return_pct` | 22.0 | 14.0-30.0 | Blow-off guard |
| `strategy_min_bar_range_atr` | 0.80 | 0.60-1.10 | Minimum signal-bar range versus ATR |
| `strategy_reversal_close_ratio` | 0.45 | 0.35-0.55 | Maximum close location within the signal bar range |
| `strategy_atr_period` | 20 | 14-30 | ATR period for hard stop |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | ATR hard-stop multiplier |
| `strategy_max_hold_days` | 14 | 7-21 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- Host/traded symbol: `XTIUSD.DWX`, magic slot 0.
- No read-only confirmation symbols.
- No basket manifest.

## 4. Timeframe

- Base timeframe: D1.
- Bar gating: `QM_IsNewBar()`.
- Entry cadence: first D1 bar of a new broker-calendar week.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 3-8.
- Typical hold: multi-day WTI failed-spike relief moves, capped at 14 calendar
  days by default.
- Regime preference: WTI upside tightness spikes that cannot hold the breakout
  close.
- Direction: short-only.

## 6. Source Citation

U.S. Energy Information Administration, "Crude oil inventories at Cushing,
Oklahoma, remain low after summer draws", Today in Energy, October 21, 2021,
URL https://www.eia.gov/todayinenergy/detail.php?id=49636.

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
| v1 | 2026-06-30 | Initial WTI Cushing failed-spike fade build |
