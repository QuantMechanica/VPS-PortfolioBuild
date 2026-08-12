# QM5_20054_xng-1m-contr - Strategy Spec

**EA ID:** QM5_20054
**Slug:** `xng-1m-contr`
**Source:** `MISHRA-SMYTH-XNG-PRED-2016`
**Strategy ID:** `MISHRA-SMYTH-XNG-1M-2016_S02`
**Author of this spec:** Codex
**Last revised:** 2026-07-20

## 1. Strategy Logic

On the first D1 bar of each odd-numbered broker month, reconstruct the latest
two completed XNG month-end closes. Buy when the just-completed close is below
the close one months earlier and sell when it is above. Exact equality retains
the prior position; otherwise the expired package is closed before the next
fixed one-month package is opened, including a same-direction renewal.

This is an unconditional, fixed-horizon time-series sign contrarian. It is not
RSI, a return-magnitude event, a volatility-conditioned reversal, a moving-
average deviation, a calendar seasonal estimate or a cross-sectional rank.

## 2. Parameters

| Parameter | Default | Authorized values | Meaning |
|---|---:|---|---|
| `strategy_holding_months` | 1 | 1 | Source-selected fixed holding/trading frequency |
| `strategy_history_bars` | 120 | 120 | Bounded D1 history for completed month ends |
| `strategy_rebalance_month_parity` | 1 | 1 | every broker-month decision epoch |
| `strategy_atr_period` | 20 | 20 | D1 ATR period for the frozen hard stop |
| `strategy_atr_sl_mult` | 4.0 | 4.0 | ATR multiple for the initial stop |
| `strategy_max_hold_days` | 70 | 70 | Stale safety override around one-month renewal |
| `strategy_max_spread_points` | 3000 | 3000 | Entry spread cap; zero modeled spread remains valid |

All signal and cadence parameters are locked for Q02. The source does not state
the calendar epoch, so the monthly anchor is frozen before testing rather
than exposed as an optimization.

## 3. Symbol Universe

**Designed only for:**

- `XNGUSD.DWX` (slot 0), the registered Darwinex natural-gas CFD carrier.

The carrier is not identical to the paper's Henry Hub spot or fixed-maturity
futures series. Futures/spot-to-CFD basis, roll, financing and execution costs
remain falsification risks.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none; completed month ends are reconstructed from D1 |
| Bar gating | one framework `QM_IsNewBar()` consume on the D1 host |
| Decision cadence | first D1 bar of broker months |

The EA does not depend on `.DWX` MN1 tester bars.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Decisions / year | six |
| Completed trades / year | approximately twelve; exact equality, history/spread failure, or stop/no-reentry can reduce this |
| Typical hold time | two broker months, capped at 40 calendar days |
| Expected drawdown profile | high XNG gap/CFD-basis risk bounded by fixed dollar risk and a broker stop |
| Regime preference | natural-gas mean reversion at a fixed one-month horizon |

## 6. Source Citation

Mishra, V. and Smyth, R. (2016), "Are Natural Gas Spot and Futures Prices
Predictable?", *Economic Modelling*, 54, 178-186, DOI
`10.1016/j.econmod.2015.12.034`. The exact rule is on printed manuscript page
18; see `strategy-seeds/sources/MISHRA-SMYTH-XNG-PRED-2016/source.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02-Q10) | `RISK_FIXED` | $1,000 per trade (HR4) |
| Live burn-in (Q13) | `RISK_PERCENT` | Min-lot equivalent only under a later OWNER manifest |
| Full live (post-Q13 PASS) | `RISK_PERCENT` | Allocated by the later portfolio process |

ENV-to-mode validation is enforced by `QM_FrameworkInit`. This build creates
no live setfile and does not touch T_Live, AutoTrading, deployment manifests,
portfolio admission or the portfolio gate.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-20 | Initial source-backed one-month XNG contrarian build | Q01 PASS; Q02 work item `5b880ae3-30d8-47ea-9708-dd21a699933d` pending |
