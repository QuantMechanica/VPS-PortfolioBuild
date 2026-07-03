# QM5_12999_xbr-xng-rspr - Strategy Spec

**EA ID:** QM5_12999
**Slug:** `xbr-xng-rspr`
**Source:** `EIA-OILGAS-RSPREAD-2026_XBR_XNG_RSPR`
**Author of this spec:** Codex
**Last revised:** 2026-07-03

## 1. Strategy Logic

This EA implements a low-frequency market-neutral energy basket on
`XBRUSD.DWX` and `XNGUSD.DWX`. On each new D1 host bar it computes a rolling
return spread:

`log(XBR[t] / XBR[t-L]) - beta * log(XNG[t] / XNG[t-L])`

The current return spread is standardized against its recent D1 history. A high
positive z-score means Brent has outperformed natural gas over the fixed return
window, so the basket sells Brent and buys natural gas. A high negative z-score
buys Brent and sells natural gas. The package exits when the z-score reverts
near zero, max hold expires, Friday close intervenes, or per-leg ATR stops fire.

This is not a duplicate of the existing `QM5_12857_xbr-xng-vcb` volatility
breakout, `QM5_12840_xti-xng-rspread` WTI/gas return-spread reversion,
`QM5_12578_eia-oilgas-ratio` price-level log-ratio reversion, or outright XNG,
Brent, WTI, index, or metal sleeves. It trades temporary D1 return divergence
between Brent and natural gas, not price-ratio envelope expansion, calendar
ownership, RSI pullback, or a single-symbol trend/event rule.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_return_lookback_d1` | 20 | 10-40 | D1 return window for both legs |
| `strategy_z_lookback_d1` | 120 | 80-180 | History length for return-spread z-score |
| `strategy_beta` | 1.0 | 0.5-1.5 | Natural-gas return multiplier and risk weight proxy |
| `strategy_entry_z` | 1.8 | 1.5-2.4 | Absolute z-score required for entry |
| `strategy_exit_z` | 0.4 | 0.2-0.8 | Mean-reversion exit band |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period for each leg |
| `strategy_atr_sl_mult` | 3.0 | 2.25-4.0 | Per-leg hard stop distance |
| `strategy_max_hold_days` | 25 | 15-35 | Calendar-day stale package exit |
| `strategy_xbr_max_spread_pts` | 1200 | 800-1800 | Brent spread cap |
| `strategy_xng_max_spread_pts` | 2500 | 1500-3500 | Natural-gas spread cap |

## 3. Symbol Universe

- Logical basket symbol: `QM5_12999_XBR_XNG_RSPREAD_D1`.
- Host symbol: `XBRUSD.DWX`, magic slot 0.
- Second leg: `XNGUSD.DWX`, magic slot 1.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()` on the `XBRUSD.DWX` host chart.

## 5. Expected Behaviour

- Expected package frequency: about 8-16 paired packages/year before Q02 proves
  or rejects the hypothesis.
- Typical hold: several D1 bars to a few weeks.
- Regime preference: short-lived relative energy return dislocations where one
  leg has overreacted versus the other.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration, "An Analysis of Price Volatility in
Natural Gas Markets", section on the relationship between crude oil and natural
gas prices. Local source packet:
`strategy-seeds/sources/EIA-OILGAS-RSPREAD-2026/`.

Secondary implementation lineage: Ernest P. Chan, *Algorithmic Trading:
Winning Strategies and Their Rationale* (2013), pair-spread mean-reversion
mechanic as already used by the V5 return-spread basket family.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, AutoTrading setting, portfolio admission file,
or portfolio gate file is touched by this build.
