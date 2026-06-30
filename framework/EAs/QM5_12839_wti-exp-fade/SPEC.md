# QM5_12839_wti-exp-fade - Strategy Spec

**EA ID:** QM5_12839
**Slug:** `wti-exp-fade`
**Source:** `CME-WTI-EXPIRY-BRK-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-01

## 1. Strategy Logic

This EA implements a low-frequency structural WTI crude-oil expiry/roll sleeve
on `XTIUSD.DWX`. It approximates the monthly CME WTI futures termination day as
the third business day before the 25th calendar day, after moving a weekend
25th to the prior business day. Inside that narrow window it fades failed D1
channel breakouts rather than following confirmed breakouts.

Long entries fade downside failed breaks: the signal bar trades below the prior
channel low, closes back above that channel, and closes in the upper half of
its range while still below the SMA mean. Short entries mirror the rule after
an upside failed break. Exits occur on expiry-window end, mean reversion to the
D1 SMA, short channel normalization, max hold, Friday close, or ATR hard stop.

This is not a duplicate of `QM5_12600_cme-wti-exp-brk`, which follows
confirmed expiry-window breakouts. It is also distinct from WTI post-roll
fades, WPSR/event sleeves, fixed month/day calendar effects, Cushing storage
logic, XTI/FX baskets, XTI/XNG baskets, XAU/XAG baskets, and
`QM5_12567_cum-rsi2-commodity` RSI pullback logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_channel` | 12 | 8-20 | Previous-bar D1 channel for failed-breakout trigger |
| `strategy_exit_channel` | 6 | 4-10 | Previous-bar D1 channel for normalization exit |
| `strategy_mean_period` | 50 | 34-84 | D1 SMA mean-reversion target |
| `strategy_atr_period` | 20 | 14-30 | ATR stop and range period |
| `strategy_min_range_atr` | 0.75 | 0.60-1.00 | Minimum signal-bar range versus ATR |
| `strategy_reentry_close_location` | 0.55 | 0.55-0.70 | Close-back-inside strength threshold |
| `strategy_atr_sl_mult` | 3.0 | 2.25-4.00 | Stop distance multiplier |
| `strategy_max_hold_days` | 6 | 4-9 | Calendar-day time exit |
| `strategy_expiry_pre_days` | 3 | 2-5 | Days before approximate expiry eligible for entry |
| `strategy_expiry_post_days` | 2 | 1-3 | Days after approximate expiry eligible for entry/hold |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-8.
- Typical hold: several D1 bars, segmented by Friday close when applicable.
- Regime preference: failed liquidity/roll-flow spikes around the WTI
  front-contract termination window.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

CME Group, "Chapter 200 Light Sweet Crude Oil Futures", URL
https://www.cmegroup.com/rulebook/NYMEX/2/200.pdf. Supplement: CME Group,
"Understanding Futures Expiration & Contract Roll", URL
https://www.cmegroup.com/education/courses/introduction-to-futures/understanding-futures-expiration-contract-roll.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, AutoTrading setting, or portfolio gate file is
touched by this build.
