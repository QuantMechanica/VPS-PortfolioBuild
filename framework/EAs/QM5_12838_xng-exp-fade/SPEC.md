# QM5_12838_xng-exp-fade - Strategy Spec

**EA ID:** QM5_12838
**Slug:** `xng-exp-fade`
**Source:** `CME-XNG-EXPIRY-BRK-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-01

## 1. Strategy Logic

This EA implements a low-frequency structural natural-gas sleeve on
`XNGUSD.DWX`. It approximates the monthly Henry Hub Natural Gas futures last
trading day as the third business day before the first calendar day of the next
delivery month, then trades only failed D1 channel breakouts inside that window.

Long entries fade downside failed breaks: the signal bar trades below the prior
channel low, closes back above that channel, and closes in the upper half of its
range while still below the SMA mean. Short entries mirror the rule after an
upside failed break. Exits occur on expiry-window end, mean reversion to the D1
SMA, short channel normalization, max hold, Friday close, or ATR hard stop.

This is not a duplicate of `QM5_12567_cum-rsi2-commodity`, which is a
short-horizon RSI pullback sleeve. It is also distinct from `QM5_12830_xng-exp-brk`
because this EA fades failed expiry-window breakouts instead of following
confirmed channel breakouts.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_channel` | 12 | 8-20 | Previous-bar D1 channel for failed-breakout trigger |
| `strategy_exit_channel` | 6 | 4-10 | Previous-bar D1 channel for normalization exit |
| `strategy_mean_period` | 34 | 21-55 | D1 SMA mean-reversion target |
| `strategy_atr_period` | 20 | 14-30 | ATR stop and range period |
| `strategy_min_range_atr` | 0.85 | 0.65-1.10 | Minimum signal-bar range versus ATR |
| `strategy_reentry_close_location` | 0.55 | 0.55-0.70 | Close-back-inside strength threshold |
| `strategy_atr_sl_mult` | 3.0 | 2.50-4.00 | Stop distance multiplier |
| `strategy_max_hold_days` | 5 | 3-7 | Calendar-day time exit |
| `strategy_expiry_pre_days` | 4 | 3-6 | Days before approximate expiry eligible for entry |
| `strategy_expiry_post_days` | 2 | 1-3 | Days after approximate expiry eligible for entry/hold |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-8.
- Typical hold: several days, segmented by Friday close when applicable.
- Regime preference: failed liquidity/roll-flow spikes around the Henry Hub
  front-contract expiration window.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

CME Group, "Chapter 220 Henry Hub Natural Gas Futures", plus CME Henry Hub
Natural Gas futures contract specs and CME futures expiration/contract-roll
education. Sources are used only for structural lineage; runtime uses Darwinex
MT5 OHLC and broker calendar only.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, AutoTrading setting, or portfolio gate file is
touched by this build.
