# QM5_13025_xti-psm-mom - Strategy Spec

**EA ID:** QM5_13025
**Slug:** `xti-psm-mom`
**Source:** `EIA-PSM-XTI-MOM-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-07

## 1. Strategy Logic

This EA implements a low-frequency WTI monthly petroleum supply-disposition
information window on `XTIUSD.DWX`. On each new D1 bar it inspects the previous
completed D1 bar and checks whether that bar was inside the EIA Petroleum
Supply Monthly proxy window, broker-calendar days 28 through 31 by default.

If that proxy bar is an ATR-sized directional range expansion, closes beyond
the prior Donchian high or low, and agrees with the SMA trend filter, the EA
follows next-day continuation in that direction. Positions use ATR hard stop,
ATR target, SMA trend-failure exit, max-hold exit, standard V5 news and Friday
close, and no runtime external data.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_event_start_day` | 28 | 27-29 | First broker-calendar day eligible for the PSM proxy window |
| `strategy_event_end_day` | 31 | 30-31 | Last broker-calendar day eligible for the PSM proxy window |
| `strategy_breakout_lookback` | 20 | 10-30 | Prior D1 Donchian window excluding the PSM proxy bar |
| `strategy_trend_period` | 80 | 50-120 | SMA trend filter period |
| `strategy_atr_period` | 20 | 14-30 | ATR period for event sizing and stop/target |
| `strategy_min_range_atr` | 0.85 | 0.70-1.05 | Minimum event-bar high-low range in ATR units |
| `strategy_min_body_atr` | 0.25 | 0.20-0.40 | Minimum absolute event-bar body in ATR units |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.0 | ATR stop distance |
| `strategy_atr_tp_mult` | 3.0 | 2.0-4.0 | ATR target distance |
| `strategy_max_hold_days` | 5 | 3-7 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-8.
- Typical hold: several D1 bars, capped by stale-position and SMA trend-failure
  guards.
- Regime preference: monthly U.S. petroleum supply/disposition information
  window.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration, Petroleum Supply Monthly and Petroleum
& Other Liquids data pages:

- https://www.eia.gov/petroleum/supply/monthly/
- https://www.eia.gov/petroleum/data.php

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
