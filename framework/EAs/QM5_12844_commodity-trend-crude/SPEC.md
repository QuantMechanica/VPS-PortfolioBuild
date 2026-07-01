# QM5_12844_commodity-trend-crude - Strategy Spec

**EA ID:** QM5_12844
**Slug:** `commodity-trend-crude`
**Source:** `BALKE-DAVEY-SLATE-20260630`
**Author of this spec:** Codex
**Last revised:** 2026-07-01

## 1. Strategy Logic

This EA implements a low-frequency structural WTI trend sleeve on
`XTIUSD.DWX`. On each new D1 bar, it checks whether the just-closed bar broke
the prior 20-bar channel while ADX(11) is above the trend threshold. It trades
symmetrically long and short, with an ATR hard stop, ATR trailing stop,
opposite 10-bar channel exit, and max-hold time exit.

The strategy is intentionally not a duplicate of the existing WTI family:
monthly TSMOM, Abraham pullback, prior-range volatility expansion, XTI/XNG,
WTI/Brent, calendar/event, inventory, and ratio sleeves use different timing,
symbols, or signal construction. It is also distinct from the existing
multi-commodity Turtle sleeve through its crude-only universe, ADX trend gate,
ATR trail, and time exit.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_period` | 20 | 15-30 | Prior D1 channel lookback for breakout entry |
| `strategy_exit_period` | 10 | 8-15 | Prior D1 channel lookback for reverse exit |
| `strategy_adx_period` | 11 | 9-14 | ADX trend-state period |
| `strategy_adx_threshold` | 20.0 | 18.0-25.0 | Minimum closed-bar ADX for entry |
| `strategy_atr_period` | 14 | 14-20 | ATR period for hard stop and trail |
| `strategy_atr_sl_mult` | 3.0 | 2.5-3.5 | Initial ATR stop multiplier |
| `strategy_atr_trail_mult` | 3.0 | 2.5-3.5 | ATR trailing stop multiplier |
| `strategy_trail_activation_atr` | 1.0 | 0.0-1.5 | Favorable ATR move before trailing |
| `strategy_max_hold_days` | 45 | 30-65 | Calendar-day time exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0. This is the Darwinex WTI CFD proxy and gives
  the book outright crude exposure distinct from the current XAU, index, XNG,
  and ratio sleeves.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 10-30.
- Typical hold: several D1 bars through a few weeks, bounded by a 45-day time
  stop.
- Regime preference: directional WTI trends with ADX confirmation.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Source `BALKE-DAVEY-SLATE-20260630`: local approved research slate
`docs/research/YOUTUBE_STRATEGY_SYNTHESIS_2026-06-30.md`, B1 "Commodity Trend
/ Breakout - Crude & Gold", which specifies Donchian+ADX+ATR-trail commodity
breakout logic with crude first. Supplemental source: Davey, Kevin J. (2014).
*Building Winning Algorithmic Trading Systems*. Wiley.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Revision History

| Version | Date | Change | Task |
|---|---|---|---|
| v1 | 2026-07-01 | Initial build from approved card | QM5_12844 |
