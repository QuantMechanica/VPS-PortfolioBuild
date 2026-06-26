# QM5_12586_eia-xng-winter-brk - Strategy Spec

**EA ID:** QM5_12586
**Slug:** `eia-xng-winter-brk`
**Source:** `EIA-XNG-WINTER-WITHDRAWAL-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-26

## 1. Strategy Logic

This EA implements a low-frequency structural natural-gas sleeve on
`XNGUSD.DWX`. It trades D1 channel breakouts only during the EIA winter
withdrawal season, November through March. Long entries require the prior D1
close to break above the previous Donchian channel and a slow SMA; short entries
require the prior D1 close to break below the previous channel and SMA.

This is intentionally not a duplicate of:

- `QM5_12567_cum-rsi2-commodity`: short-horizon RSI pullback.
- `QM5_12575_eia-xng-season`: monthly two-sided calendar/SMA season map.
- `QM5_12582_chan-ng-spring`: fixed long-only spring calendar window.
- `QM5_12584_eia-xng-storage`: weekly storage-report aftershock reaction.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_channel` | 30 | 20-55 | Previous-bar D1 channel for breakout entry |
| `strategy_exit_channel` | 12 | 8-20 | Previous-bar D1 channel for opposite-channel exit |
| `strategy_trend_period` | 63 | 42-126 | Slow D1 SMA confirmation |
| `strategy_atr_period` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.5 | 2.5-5.0 | Stop distance multiplier |
| `strategy_max_hold_days` | 12 | 7-21 | Calendar-day time exit |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-9.
- Typical hold: several days to two trading weeks, segmented by Friday close.
- Regime preference: winter natural-gas withdrawal-season directional shocks.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Weekly Natural Gas Storage Report",
URL https://www.eia.gov/naturalgas/storage/. Supplemental EIA natural-gas
consumer/use material documents weather-sensitive heating demand. Sources are
used only for structural lineage; the EA uses Darwinex MT5 OHLC at runtime.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest or `T_Live` file is touched by this build.
