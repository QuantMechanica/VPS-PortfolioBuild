# QM5_12843_wti-brent-spread - Strategy Spec

**EA ID:** QM5_12843
**Slug:** `wti-brent-spread`
**Source:** `CME-WTI-BRENT-SPREAD-2026_S01`
**Author of this spec:** Codex
**Last revised:** 2026-07-01

## 1. Strategy Logic

This EA implements a low-frequency market-neutral crude benchmark basket on
`XTIUSD.DWX` and `XBRUSD.DWX`. On each new D1 host bar it computes a rolling
log-price spread:

`log(XBR[t]) - beta * log(XTI[t])`

The current spread is standardized against its recent D1 history. A high
positive z-score means Brent is rich versus WTI, so the basket sells Brent and
buys WTI. A high negative z-score buys Brent and sells WTI. The package exits
when the z-score reverts near zero, when max hold expires, on Friday close, or
through per-leg ATR stops.

This is not a duplicate of the existing XTI/XNG price-ratio, XTI/XNG return
spread, XTI/XNG breakout, XTI/XNG relative momentum, Brent weekday, WTI calendar,
XNG, XAU/XAG, or commodity RSI sleeves.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_z_lookback_d1` | 120 | 80-180 | History length for log-spread z-score |
| `strategy_beta` | 1.0 | 0.8-1.2 | WTI log-spread multiplier and risk weight proxy |
| `strategy_entry_z` | 2.0 | 1.8-2.3 | Absolute z-score required for entry |
| `strategy_exit_z` | 0.5 | 0.3-0.8 | Mean-reversion exit band |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period for each leg |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | Per-leg hard stop distance |
| `strategy_max_hold_days` | 45 | 30-60 | Calendar-day stale package exit |
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | WTI spread cap |
| `strategy_xbr_max_spread_pts` | 1500 | 1000-2500 | Brent spread cap |

## 3. Symbol Universe

- Logical basket symbol: `QM5_12843_WTI_BRENT_SPREAD_D1`.
- Host symbol: `XTIUSD.DWX`, magic slot 0.
- Second leg: `XBRUSD.DWX`, magic slot 1.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()` on the `XTIUSD.DWX` host chart.

## 5. Expected Behaviour

- Expected package frequency: about 5-12 paired packages/year before Q02 proves
  or rejects the hypothesis.
- Typical hold: several D1 bars to several weeks.
- Regime preference: temporary Brent-WTI benchmark dislocations that mean revert
  without requiring outright crude direction.
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
