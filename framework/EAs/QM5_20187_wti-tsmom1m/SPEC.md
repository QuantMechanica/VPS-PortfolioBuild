# QM5_20187_wti-tsmom1m — Strategy Spec

**EA ID:** QM5_20187

**Slug:** `wti-tsmom1m`

**Source:** `MOP-TSMOM-2012`

**Author:** Codex

**Last revised:** 2026-07-31

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of every broker-calendar month,
reconstruct the two latest consecutive completed month-end closes. Buy WTI
when the resulting one-month log return is positive and short WTI when it is
negative. Equality or invalid history stays flat for the consumed month.

Close the prior package at the next month boundary. Persist the month before
fallible gates so a blocked, flat, or failed attempt cannot retry after a
restart. Use one frozen `3.5 * ATR(20,D1)` hard stop, no profit target, and a
forty-day stale guard. Friday close is disabled because the source hold is a
full month.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_history_bars` | 80 | Bounded D1 endpoint reconstruction |
| `strategy_atr_period` | 20 | Completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 3.5 | Frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | Monthly stale guard |
| `strategy_max_spread_points` | 1500 | Maximum entry spread |

No baseline parameter sweep is authorized.

## 3. Symbol Universe

- Exact symbol: `XTIUSD.DWX`.
- Magic slot: 0 (`201870000`).
- No cross-symbol or external runtime dependency.

## 4. Timeframe

- Exact timeframe: D1.
- Entry clock: first tradable D1 bar of a new broker month.
- Bar gate: framework `QM_IsNewBar()`.

## 5. Expected Behaviour

Expected cadence is approximately twelve completed packages per full
post-warm-up year; Q02 retires below five/year. Exposure normally spans one
broker month. Primary risks are WTI trend reversal, monthly gaps, CFD
roll/basis, financing, stop-outs, source decay, and realized book correlation.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), “Time Series
Momentum,” *Journal of Financial Economics* 104(2), 228–250, DOI
`10.1016/j.jfineco.2011.11.003`.

The governed complete-read packet is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; the approved card is
`strategy-seeds/cards/approved/QM5_20187_wti-tsmom1m_card.md`.

The paper supplies the one-month-lookback, one-month-hold commodity-futures
sign family, not a WTI-only CFD result. Close-to-close CFD log returns,
fixed-risk sizing, and ATR stops are explicit QM translations.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both news axes are OFF. There is no live setfile, live
authorization, deploy manifest, portfolio admission, or portfolio-gate change.

## Revision history

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-31 | Initial build from approved G0 card | Q01 PASS: strict compile and V5 build check, 0 errors/warnings |
| v2 | 2026-07-31 | Paced pipeline handoff | Q02 work item `402dc257-b6bc-4ad5-b359-2156441513f0` enqueued; baseline pending |
