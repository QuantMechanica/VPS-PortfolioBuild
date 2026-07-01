# QM5_12848_wti-brent-brk - Strategy Spec

**EA ID:** QM5_12848
**Slug:** `wti-brent-brk`
**Source:** `CME-WTI-BRENT-SPREAD-2026_S02`
**Author of this spec:** Codex
**Last revised:** 2026-07-01

## 1. Strategy Logic

This EA implements a low-frequency market-neutral crude benchmark basket on
`XTIUSD.DWX` and `XBRUSD.DWX`. On each new D1 host bar it computes:

`log(XBR[t]) - beta * log(XTI[t])`

It opens a continuation basket when the just-completed spread breaks out of a
long Donchian channel. Upside spread breakout buys Brent and sells WTI; downside
spread breakout sells Brent and buys WTI. The package exits on a shorter
opposite-channel break, max hold, Friday close, broken-package repair, or
per-leg ATR stops.

This is not a duplicate of `QM5_12843_wti-brent-spread`: that EA fades z-score
extremes, while this one follows completed-bar channel breakouts.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_lookback_d1` | 120 | 90-252 | D1 bars in the entry channel |
| `strategy_exit_lookback_d1` | 40 | 20-60 | D1 bars in the opposite-channel exit |
| `strategy_beta` | 1.0 | 0.8-1.2 | WTI log-spread multiplier and risk weight proxy |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period for each leg |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | Per-leg hard stop distance |
| `strategy_max_hold_days` | 45 | 30-60 | Calendar-day stale package exit |
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | WTI spread cap |
| `strategy_xbr_max_spread_pts` | 1500 | 1000-2500 | Brent spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Basket market-order deviation |

## 3. Symbol Universe

- Logical basket symbol: `QM5_12848_WTI_BRENT_BRK_D1`.
- Host symbol: `XTIUSD.DWX`, magic slot 0.
- Second leg: `XBRUSD.DWX`, magic slot 1.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()` on the `XTIUSD.DWX` host chart.

## 5. Expected Behaviour

- Expected package frequency: about 4-10 paired packages/year before Q02 proves
  or rejects the hypothesis.
- Typical hold: several D1 bars to several weeks.
- Regime preference: persistent Brent-WTI benchmark basis expansion or
  compression without requiring outright crude direction.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Source packet: `strategy-seeds/sources/CME-WTI-BRENT-SPREAD-2026/`.

Primary references are CME WTI-Brent Financial Futures, ICE Brent/WTI Futures
Spread, and EIA Brent-WTI spread market-structure analysis. The source is used
only to establish that the Brent-WTI spread is a structural, exchange-recognized
crude benchmark relationship. All performance validation belongs to Q02 and
later phases.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, AutoTrading setting, portfolio admission file,
or portfolio gate file is touched by this build.
