# QM5_12828_wti-cushing-brk - Strategy Spec

**EA ID:** QM5_12828
**Slug:** `wti-cushing-brk`
**Source:** `EIA-CUSHING-STORAGE-2021`
**Author of this spec:** Codex
**Last revised:** 2026-06-30

## 1. Strategy Logic

This EA implements a low-frequency structural crude-oil sleeve on
`XTIUSD.DWX`. Entries are evaluated on the first available D1 bar of a new
broker-calendar week. A long setup requires the prior completed D1 close to
break above a multi-month closing-channel high, fast trend to be above slow
trend, price to be above the slow SMA, and recent return to be positive but not
an extreme blow-off.

The source lineage is Cushing delivery-hub tightness, but the EA uses no
inventory data, EIA file, futures curve, storage feed, API, or external runtime
input. Runtime data is limited to Darwinex MT5 `XTIUSD.DWX` OHLC, broker
calendar, spread, and ATR/SMA calculations.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_breakout_lookback_d1` | 63 | 42-84 | Prior closed bars for the channel high, excluding the signal bar |
| `strategy_return_lookback_d1` | 21 | 14-42 | Completed D1 bars for recent return pressure |
| `strategy_fast_sma_period` | 20 | 15-30 | Fast trend and close-exit SMA |
| `strategy_slow_sma_period` | 126 | 84-168 | Slow trend filter |
| `strategy_min_breakout_margin_pct` | 0.25 | 0.10-0.50 | Required close above prior channel high |
| `strategy_min_return_pct` | 2.0 | 1.0-3.5 | Minimum recent return |
| `strategy_max_return_pct` | 18.0 | 12.0-25.0 | Blow-off guard |
| `strategy_atr_period` | 20 | 14-30 | ATR period for hard stop |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | ATR hard-stop multiplier |
| `strategy_max_hold_days` | 28 | 14-42 | Calendar-day stale-position guard |
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

- Expected trades/year/symbol: about 4-10.
- Typical hold: multi-day WTI breakout packages, capped at 28 calendar days by
  default.
- Regime preference: WTI upside continuation when price action is consistent
  with crude-delivery-hub tightness.
- Direction: long-only.

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
| v1 | 2026-06-30 | Initial WTI Cushing tightness breakout build |
