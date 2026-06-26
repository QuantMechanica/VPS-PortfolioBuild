# QM5_12582_chan-ng-spring - Strategy Spec

**EA ID:** QM5_12582
**Slug:** `chan-ng-spring`
**Source:** `SRC02_S08`
**Author of this spec:** Codex
**Last revised:** 2026-06-26

## 1. Strategy Logic

This EA implements a low-frequency structural natural-gas sleeve on
`XNGUSD.DWX`. It ports Chan's annual NG spring calendar idea to the available
Darwinex custom symbol: long-only between February 25 and April 15, with a
D1 SMA confirmation filter, ATR hard stop, date-window exit, SMA failure exit,
and max-hold exit.

The V5 Friday-close guard remains enabled. That intentionally segments the
original continuous futures-calendar hold into weekly D1 packages in backtest,
avoiding a live-style weekend waiver in this build.

This is intentionally not a duplicate of `QM5_12575_eia-xng-season`, which is
a monthly two-sided winter/summer/shoulder demand-seasonality model. This EA
trades only one fixed annual spring window and never shorts.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_trend_period` | 63 | 42-126 | D1 SMA confirmation period |
| `strategy_atr_period` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.0-5.0 | Stop distance multiplier |
| `strategy_max_hold_days` | 10 | 5-15 | Calendar-day time exit, aligned with Friday-close segmentation |
| `strategy_max_spread_points` | 800 | 500-1200 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 5-8.
- Typical hold: days to one trading week, unless stopped earlier.
- Regime preference: natural-gas spring seasonal strength.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Chan, Ernest P. (2009). *Quantitative Trading: How to Build Your Own
Algorithmic Trading Business*. Wiley Trading. SRC02 records S08 as the natural
gas annual calendar trade from sidebar p. 150: enter February 25, exit April
15, original NYMEX NG June-expiry context.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest or `T_Live` file is touched by this build.
