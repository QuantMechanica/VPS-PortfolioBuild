# QM5_12588_eia-xng-sum-sqz - Strategy Spec

**EA ID:** QM5_12588
**Slug:** `eia-xng-sum-sqz`
**Source:** `EIA-XNG-SUMMER-POWER-2015`
**Author of this spec:** Codex
**Last revised:** 2026-06-26

## 1. Strategy Logic

This EA implements a low-frequency structural natural-gas sleeve on
`XNGUSD.DWX`. It trades long-only D1 upside breakouts during the EIA summer
electric-sector demand window, June through August. Entry requires prior-close
trend confirmation versus SMA(63), a recent D1 range-compression regime, and a
close above the prior Donchian channel. Positions exit on channel failure, SMA
failure, date-window expiry, max-hold timeout, or the ATR stop.

The strategy is intentionally not a duplicate of:

- `QM5_12567_cum-rsi2-commodity`: short-horizon RSI pullback.
- `QM5_12575_eia-xng-season`: monthly two-sided calendar/SMA season map.
- `QM5_12582_chan-ng-spring`: fixed long-only spring calendar window.
- `QM5_12584_eia-xng-storage`: weekly storage-report aftershock reaction.
- `QM5_12586_eia-xng-winter-brk`: winter withdrawal-season breakout.
- `QM5_12587_eia-xng-inj-brk`: injection-season short breakdown.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_channel` | 20 | 15-30 | Previous-bar D1 channel for upside breakout entry |
| `strategy_exit_channel` | 10 | 7-15 | Previous-bar D1 channel for failure exit |
| `strategy_trend_period` | 63 | 42-84 | Slow D1 SMA confirmation |
| `strategy_compression_lookback` | 10 | 7-15 | D1 bars for average range compression gate |
| `strategy_compression_atr_mult` | 0.85 | 0.70-1.00 | Maximum average range as ATR multiple |
| `strategy_atr_period` | 20 | 14-30 | ATR stop and compression baseline period |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | Stop distance multiplier |
| `strategy_max_hold_days` | 10 | 7-15 | Calendar-day time exit |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 2-6.
- Typical hold: several days to two trading weeks, segmented by Friday close.
- Regime preference: summer natural-gas power-burn upside squeeze.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Natural gas consumption, production
respond to seasonal changes", Today in Energy, 2015-09-24, URL
https://www.eia.gov/todayinenergy/detail.php?id=22892.

The source is used only for structural lineage; the EA uses Darwinex MT5 OHLC
at runtime and no external weather, storage, power-load, or EIA feed.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest or `T_Live` file is touched by this build.
