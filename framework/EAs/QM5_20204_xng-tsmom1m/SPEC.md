# QM5_20204_xng-tsmom1m - Strategy Spec

**EA ID:** QM5_20204

**Slug:** `xng-tsmom1m`

**Source:** `MOP-TSMOM-2012`

**Author:** Codex

**Last revised:** 2026-08-02

## 1. Strategy Logic

On the first tradable `XNGUSD.DWX` D1 bar of every broker-calendar month,
reconstruct the two latest consecutive completed month-end closes. Buy natural
gas when the resulting one-month log return is positive and short it when the
return is negative. Equality or invalid history stays flat for the consumed
month.

Close the prior package at the next month boundary. Persist the month before
fallible gates so a blocked, flat, stopped, or failed attempt cannot retry
after restart. Use one frozen `3.5 * ATR(20,D1)` hard stop, no profit target,
and a forty-day stale guard. Friday close is disabled because the source hold
is a full month.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_history_bars` | 80 | Bounded D1 completed-month reconstruction |
| `strategy_atr_period` | 20 | Completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 3.5 | Frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | Monthly stale repair |
| `strategy_max_spread_points` | 3000 | XNG entry spread ceiling |

All Q02 values are locked. No baseline parameter sweep is authorized.

## 3. Symbol Universe

- Exact symbol: `XNGUSD.DWX`.
- Magic slot: 0 (`202040000`).
- No cross-symbol or external runtime dependency.

## 4. Timeframe

- Exact timeframe: D1.
- Entry clock: first tradable D1 bar of a new broker month.
- Bar gate: framework `QM_IsNewBar()`.
- Formation uses completed broker-month endpoints, not a fixed D1-bar proxy.

## 5. Expected Behaviour

Expected cadence is approximately twelve completed packages per full
post-warm-up year; Q02 retires below five/year. Exposure normally spans one
broker month. Primary risks are natural-gas reversal, gaps, CFD roll/basis,
financing, stop-outs, source decay, and realized correlation with the
certified XNG RSI-pullback sleeve.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

The governed complete-read packet is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; the approved card is
`strategy-seeds/cards/approved/QM5_20204_xng-tsmom1m_card.md`.

The paper supplies the one-month-lookback, one-month-hold pooled commodity-
futures sign family, not a natural-gas-only CFD result. Close-to-close CFD log
returns, fixed-risk sizing, the XNG spread ceiling, and ATR stop are disclosed
QM translations.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both news axes are OFF. There is no live, demo, or
shadow setfile; live authorization; deploy manifest; portfolio admission;
portfolio-gate change; or AutoTrading action.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-02 | Initial build from approved G0 card | Q01 PASS; Q02 not queued because the path-anchored tester count reached the 7/7 CPU ceiling |
