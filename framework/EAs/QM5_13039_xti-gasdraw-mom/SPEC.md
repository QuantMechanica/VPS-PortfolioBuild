# QM5_13039_xti-gasdraw-mom - Strategy Spec

**EA ID:** QM5_13039
**Slug:** `xti-gasdraw-mom`
**Source:** `EIA-GASDRAW-XTI-MOM-2026_S01`
**Author of this spec:** Codex
**Last revised:** 2026-07-07

## 1. Strategy Logic

This EA implements a low-frequency WTI gasoline-stock pressure momentum setup
on `XTIUSD.DWX`. On each new D1 bar it inspects the previous completed D1 bar,
requiring that bar to be Wednesday or Thursday in broker time, proxying the
normal EIA Weekly Petroleum Status Report release window. It trades only during
the May-August U.S. driving-season demand window.

Entries require a short pullback before the signal bar, a bullish ATR-sized
release-window reaction, upper-range close location, close above a rising
`SMA(50)`, and fixed single-symbol WTI scope. Positions use ATR hard stop, ATR
target, SMA trend-failure exit, seasonal invalidation, max-hold exit, standard
V5 news and Friday close handling, and no runtime external data.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_season_start_month` | 5 | fixed | First month of driving-season pressure window |
| `strategy_season_end_month` | 8 | fixed | Last month of driving-season pressure window |
| `strategy_report_start_dow` | 3 | fixed | First broker day-of-week for WPSR proxy window |
| `strategy_report_end_dow` | 4 | fixed | Last broker day-of-week for WPSR proxy window |
| `strategy_pullback_lookback` | 3 | 2-5 | Completed D1 bars used for pre-signal pullback check |
| `strategy_min_pullback_atr` | 0.35 | 0.25-0.60 | Minimum pullback before signal in ATR units |
| `strategy_sma_period` | 50 | 40-80 | D1 trend filter period |
| `strategy_sma_slope_shift` | 5 | 3-10 | Completed D1 bars used for SMA slope confirmation |
| `strategy_atr_period` | 20 | 14-30 | ATR period for signal sizing and stop/target |
| `strategy_min_range_atr` | 0.65 | 0.50-0.90 | Minimum signal-bar range in ATR units |
| `strategy_min_body_atr` | 0.20 | 0.15-0.35 | Minimum bullish signal-bar body in ATR units |
| `strategy_min_close_location` | 0.65 | 0.55-0.80 | Minimum close location within signal-bar range |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.5 | ATR stop distance |
| `strategy_atr_tp_mult` | 2.5 | 2.0-4.0 | ATR target distance |
| `strategy_max_hold_days` | 5 | 3-8 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-10.
- Direction: long only.
- Typical hold: several D1 bars, capped by ATR target/stop, SMA trend-failure,
  stale-position, and seasonal invalidation guards.
- Regime preference: driving-season weekly gasoline-stock pressure windows
  where WTI reacts upward after a short pullback.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration gasoline-stock and weekly petroleum data
pages:

- https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WGTSTUS1
- https://www.eia.gov/petroleum/supply/weekly/
- https://www.eia.gov/petroleum/data.php

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
