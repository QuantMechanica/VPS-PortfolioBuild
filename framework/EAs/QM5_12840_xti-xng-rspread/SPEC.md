# QM5_12840_xti-xng-rspread - Strategy Spec

**EA ID:** QM5_12840
**Slug:** `xti-xng-rspread`
**Source:** `SRC05_S01_XTI_XNG_RSPREAD_2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-01

## 1. Strategy Logic

This EA implements a low-frequency market-neutral energy basket on
`XTIUSD.DWX` and `XNGUSD.DWX`. On each new D1 host bar it computes a rolling
return spread:

`log(XTI[t] / XTI[t-L]) - beta * log(XNG[t] / XNG[t-L])`

The current return spread is standardized against its recent D1 history. A high
positive z-score means WTI has outperformed natural gas over the fixed return
window, so the basket sells WTI and buys natural gas. A high negative z-score
buys WTI and sells natural gas. The package exits when the z-score reverts near
zero, when max hold expires, on Friday close, or through per-leg ATR stops.

This is not a duplicate of the existing XTI/XNG price-level log-ratio reversion,
price-ratio breakout, monthly cross-sectional momentum, fixed seasonal energy
switch, or commodity RSI pullback sleeves. It trades temporary D1 return
divergence between the two energy legs, not their absolute price ratio, generic
trend, RSI, or calendar ownership.

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
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | WTI spread cap |
| `strategy_xng_max_spread_pts` | 2500 | 1500-3500 | Natural-gas spread cap |

## 3. Symbol Universe

- Logical basket symbol: `QM5_12840_XTI_XNG_RSPREAD_D1`.
- Host symbol: `XTIUSD.DWX`, magic slot 0.
- Second leg: `XNGUSD.DWX`, magic slot 1.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()` on the `XTIUSD.DWX` host chart.

## 5. Expected Behaviour

- Expected package frequency: about 8-16 paired packages/year before Q02 proves
  or rejects the hypothesis.
- Typical hold: several D1 bars to a few weeks.
- Regime preference: short-lived relative energy return dislocations where one
  leg has overreacted versus the other.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Chan, Ernest P. (2013). *Algorithmic Trading: Winning Strategies and Their
Rationale*. Wiley. Local source packet: `strategy-seeds/sources/SRC05/`.
Primary lineage: Chapter 3, Example 3.2 pair-spread Bollinger-style mean
reversion, adapted mechanically to a D1 XTI/XNG return spread.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, AutoTrading setting, portfolio admission file,
or portfolio gate file is touched by this build.
