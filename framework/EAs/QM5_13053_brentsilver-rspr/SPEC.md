# QM5_13053_brentsilver-rspr - Strategy Spec

**EA ID:** QM5_13053
**Slug:** `brentsilver-rspr`
**Source:** `CME-OIL-GOLD-RATIO-2024`
**Author of this spec:** Codex
**Last revised:** 2026-07-02

## 1. Strategy Logic

This EA implements a low-frequency market-neutral Brent/Silver basket on
`XBRUSD.DWX` and `XAGUSD.DWX`. On each new D1 host bar it computes a rolling
return spread:

`log(xbr[t] / xbr[t-L]) - beta * log(XAG[t] / XAG[t-L])`

The current return spread is standardized against recent D1 history. A high
positive z-score means Brent has outperformed silver over the fixed return window,
so the basket sells Brent and buys silver. A high negative z-score buys Brent and
sells silver. The package exits when the z-score reverts near zero, max hold
expires, Friday close fires, an orphan leg appears, or a per-leg ATR stop is hit.

This is not a duplicate of `QM5_12863_oilsilver-rspread`, which uses WTI as the
oil leg. It is also not `QM5_12604_cme-oilsilver-ratio`, which fades the absolute
WTI/XAG log price ratio, or `QM5_12605_cme-oilsilver-brk`, which follows a
ratio-level breakout. This EA trades temporary D1 relative-return dislocation
between Brent and silver.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_return_lookback_d1` | 10 | 5-20 | D1 return window for both legs |
| `strategy_z_lookback_d1` | 120 | 80-180 | History length for return-spread z-score |
| `strategy_beta` | 1.0 | 0.8-1.2 | Silver return multiplier and risk weight proxy |
| `strategy_entry_z` | 2.0 | 1.7-2.3 | Absolute z-score required for entry |
| `strategy_exit_z` | 0.4 | 0.25-0.6 | Mean-reversion exit band |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period for each leg |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | Per-leg hard stop distance |
| `strategy_max_hold_days` | 20 | 10-30 | Calendar-day stale package exit |
| `strategy_xbr_max_spread_pts` | 1000 | 700-1500 | Brent spread cap |
| `strategy_xag_max_spread_pts` | 500 | 300-800 | Silver spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |

## 3. Symbol Universe

- Logical basket symbol: `QM5_13053_XBR_XAG_RSPREAD_D1`.
- Host symbol: `XBRUSD.DWX`, magic slot 0.
- Second leg: `XAGUSD.DWX`, magic slot 1.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()` on the `XBRUSD.DWX` host chart.

## 5. Expected Behaviour

- Expected package frequency: about 6-14 paired packages/year before Q02 proves
  or rejects the hypothesis.
- Typical hold: several D1 bars to a few weeks.
- Regime preference: short-lived relative return dislocations between Brent and
  silver where one leg has overrun the other.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

CME Group, "Through the Lens of Silver", 2024, URL
https://www.cmegroup.com/articles/2024/through-the-lens-of-silver.html.

The source frames crude oil through silver as a relative-value lens. The EA uses
that lineage to define the XBR/XAG pair, with Brent as the crude-oil benchmark
leg, and tests a fixed-window return-spread mechanization using Darwinex OHLC
only. No source performance claim is imported.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, AutoTrading setting, portfolio admission file,
or portfolio gate file is touched by this build.
