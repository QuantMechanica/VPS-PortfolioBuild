# QM5_12844_commodity-trend-crude - Strategy Spec

**EA ID:** QM5_12844
**Slug:** `commodity-trend-crude`
**Source:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12844_commodity-trend-crude.md`
**Author of this spec:** Codex
**Last revised:** 2026-07-01

## 1. Strategy Logic

This EA implements a low-frequency commodity trend sleeve using the
OWNER-approved card of record. On each new D1 bar, it places buy-stop and
sell-stop orders at the last N-bar Donchian extremes when ADX(11) is above the
trend threshold. It trades symmetrically long and short, with an ATR hard stop,
ATR trailing stop, stop-and-reverse on the opposite Donchian signal, and
optional time exit.

The strategy is intentionally not a duplicate of the existing WTI family:
monthly TSMOM, Abraham pullback, prior-range volatility expansion, XTI/XNG,
WTI/Brent, calendar/event, inventory, and ratio sleeves use different timing,
symbols, or signal construction. It is also distinct from the existing
multi-commodity Turtle sleeve through its crude-only universe, ADX trend gate,
ATR trail, and time exit.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `donchian_lookback` | 20 | 15-30 | D1 channel lookback for buy-stop/sell-stop entry |
| `adx_period` | 11 | 9-14 | ADX trend-state period |
| `adx_min` | 20.0 | 18.0-25.0 | Minimum closed-bar ADX for entry |
| `atr_period` | 14 | 14-20 | ATR period for hard stop and trail |
| `atr_trail_mult` | 3.0 | 2.5-3.5 | ATR hard-stop and trailing multiplier |
| `time_exit_bars` | 0 | 0+ | D1-bar time exit; 0 disables it |
| `use_stop_and_reverse` | true | true/false | Opposite Donchian signal can reverse on the same bar |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- Primary target: `XTIUSD.DWX`; use the registered symbol magic slot. The EA does not hardcode the
  symbol so the card-mandated multi-market baseline can run on other approved
  commodity symbols without a rebuild.

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
| v1 | 2026-07-01 | Initial build from divergent local card | QM5_12844 |
| v2 | 2026-07-02 | Realigned to OWNER-approved card of record; stop orders, same-bar reverse, no hardcoded XTI/D1 gate | 49a19ccb |
