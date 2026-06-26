# QM5_12583_eia-distillate-winter - Strategy Spec

**EA ID:** QM5_12583
**Slug:** `eia-distillate-winter`
**Source:** `EIA-WTI-SEASON-2024`
**Author of this spec:** Codex
**Last revised:** 2026-06-26

## 1. Strategy Logic

This EA implements a low-frequency structural WTI sleeve on `XTIUSD.DWX`.
It trades long-only D1 breakouts during the winter distillate/heating-demand
window from November 1 through February 15. It exits outside that date window,
on a D1 channel breakdown, on a max-hold timeout, or via the framework Friday
close.

The strategy is intentionally not a duplicate of `QM5_12576_eia-wti-season`:
that EA uses a broad monthly two-sided WTI SMA/ROC season map. This EA uses a
narrow winter-only channel breakout and never shorts.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_channel` | 20 | 15-40 | Previous-bar channel for long breakout |
| `strategy_exit_channel` | 10 | 7-20 | Previous-bar channel for exit breakdown |
| `strategy_atr_period` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.0-5.0 | Stop distance multiplier |
| `strategy_max_hold_days` | 15 | 10-25 | Calendar-day time exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 3-7.
- Typical hold: days to several weeks, segmented by Friday close when applicable.
- Regime preference: WTI upside breakouts during winter distillate demand.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration petroleum seasonality source packet
captured under `EIA-WTI-SEASON-2024`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest or `T_Live` file is touched by this build.
