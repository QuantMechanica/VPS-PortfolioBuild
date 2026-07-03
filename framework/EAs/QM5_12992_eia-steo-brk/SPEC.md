# QM5_12992_eia-steo-brk - Strategy Spec

**EA ID:** QM5_12992
**Slug:** `eia-steo-brk`
**Source:** `EIA-STEO-XTI-BRK-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-03

## 1. Strategy Logic

This EA implements a low-frequency WTI monthly information-window sleeve on
`XTIUSD.DWX`. On each new D1 bar it inspects the previous completed D1 bar and
checks whether that bar was the EIA Short-Term Energy Outlook proxy date: first
Tuesday after the first Thursday of the month, with an optional Wednesday
one-day delayed-release proxy.

If that event bar is an ATR-sized directional range expansion and closes beyond
the prior Donchian high or low, the EA follows the next-day continuation in that
direction. Positions use ATR hard stop, ATR target, max-hold exit, standard V5
news and Friday close, and no runtime external data.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_breakout_lookback` | 20 | 10-30 | Prior D1 Donchian window excluding the STEO proxy bar |
| `strategy_atr_period` | 20 | 14-30 | ATR period for event sizing and stop/target |
| `strategy_min_range_atr` | 1.00 | 0.75-1.25 | Minimum event-bar high-low range in ATR units |
| `strategy_min_body_atr` | 0.35 | 0.25-0.50 | Minimum absolute event-bar body in ATR units |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.0 | ATR stop distance |
| `strategy_atr_tp_mult` | 3.0 | 2.0-4.0 | ATR target distance |
| `strategy_max_hold_days` | 5 | 3-8 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |
| `strategy_allow_wed_delay` | true | true/false | Allow the EIA delayed Wednesday proxy |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-10.
- Typical hold: several D1 bars, capped by stale-position guard.
- Regime preference: monthly crude-oil forecast information window.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration, Short-Term Energy Outlook release
schedule and global oil markets report.

- https://www.eia.gov/outlooks/steo/
- https://www.eia.gov/outlooks/steo/release_schedule.php
- https://www.eia.gov/outlooks/steo/report/global_oil.php

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
