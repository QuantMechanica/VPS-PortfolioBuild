# QM5_12737_eia-wti-drive - Strategy Spec

**EA ID:** QM5_12737
**Slug:** `eia-wti-drive`
**Source:** `EIA-WTI-DRIVE-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-28

## 1. Strategy Logic

This EA implements a low-frequency structural WTI sleeve on `XTIUSD.DWX`.
It trades long-only D1 channel breakouts during the gasoline driving-season
window from April 15 through August 31. It exits outside that date window, on a
D1 channel breakdown, on a max-hold timeout, or via the framework Friday close.

The strategy is intentionally not a duplicate of `QM5_12576_eia-wti-season`:
that EA uses a broad monthly two-sided WTI SMA/ROC season map. This EA uses a
narrow driving-season channel breakout and never shorts.

It is also not `QM5_12583_eia-distillate-winter`, which applies the same V5
calendar-breakout pattern to the winter distillate/heating window. This build
isolates the gasoline demand window backed by EIA gasoline-seasonality lineage.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_start_month` | 4 | fixed | Driving-season start month |
| `strategy_start_day` | 15 | 1-15 | Driving-season start day |
| `strategy_end_month` | 8 | fixed | Driving-season end month |
| `strategy_end_day` | 31 | 15-31 | Driving-season end day |
| `strategy_entry_channel` | 30 | 20-55 | Previous-bar channel for long breakout |
| `strategy_exit_channel` | 15 | 10-20 | Previous-bar channel for exit breakdown |
| `strategy_atr_period` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | Stop distance multiplier |
| `strategy_max_hold_days` | 20 | 10-30 | Calendar-day time exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-9.
- Typical hold: days to several weeks, segmented by Friday close when applicable.
- Regime preference: WTI upside breakouts during the gasoline driving season.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration gasoline price fluctuation source packet
captured under `EIA-WTI-DRIVE-2026`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, portfolio-admission artifact, or live-terminal file is touched by this build.
