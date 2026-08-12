# QM5_20202_xauxag-rev18 - Strategy Spec

**EA ID:** QM5_20202
**Slug:** `xauxag-rev18`
**Strategy ID:** `BIANCHI-MOMREV-2015_XAU_XAG_S03`
**Source:** `BIANCHI-MOMREV-2015`
**Author:** Codex
**Last revised:** 2026-08-09

## 1. Strategy Logic

The EA runs one XAU/XAG D1 logical basket from `XAUUSD.DWX`. At a genuine
broker-month transition it reconstructs synchronized completed month-end
closes for both metals and calculates each leg's 18-completed-month log
return. It buys the long-horizon loser and shorts the winner. A rank
difference with absolute value at or below `1e-10` consumes the month and
remains flat.

This is the pure long-term reversal leg of the approved
Bianchi-Drew-Fan lineage. It does not calculate or gate on the 12-month rank,
the 60-D1 ratio z-score, or the 120-D1 rolling-regression residual used by
existing XAU/XAG builds. One month is consumed before history, signal, news,
spread, sizing, or order gates, and partial packages are flattened.

## 2. Parameters

| Parameter | Default | Authorized values | Meaning |
|---|---:|---|---|
| `strategy_reversal_months` | 18 | locked | source reversal horizon |
| `strategy_history_bars` | 520 | locked | bounded D1 endpoint buffer |
| `strategy_max_boundary_gap_days` | 10 | locked | boundary freshness |
| `strategy_atr_period_d1` | 20 | locked | completed stop volatility |
| `strategy_atr_sl_mult` | 3.5 | locked | frozen stop distance |
| `strategy_max_hold_days` | 35 | locked | stale package guard |
| `strategy_xau_max_spread_pts` | 1500 | locked | XAU spread cap |
| `strategy_xag_max_spread_pts` | 3000 | locked | XAG spread cap |
| `strategy_deviation_points` | 20 | locked | order deviation |

There is no Q02 parameter sweep.

## 3. Symbol Universe

- `XAUUSD.DWX`: host, traded slot 0, magic `202020000`.
- `XAGUSD.DWX`: companion, traded slot 1, magic `202020001`.
- `QM5_20202_XAU_XAG_REV18_D1`: logical Q02 basket symbol.

Standalone-leg testing, other symbols, or a carrier substitution is outside
this build.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Decision cadence | first tradable host D1 bar of each broker month |
| Formation | synchronized completed month-end closes at 0 and 18 months |
| Holding period | next month transition, maximum 35 calendar days |
| Warm-up | at least 18 completed months inside a 520-D1 buffer |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Packages/year | approximately 12 non-tied signals; Q02 retires below five |
| Typical hold | one broker month |
| Direction | long 18-month loser, short winner |
| Drawdown profile | high: gaps, legging, narrow breadth, persistent trends |
| Neutrality | simultaneous long/short only; not proven factor neutrality |

## 6. Source Citation

Bianchi, Robert J.; Drew, Michael E.; and Fan, John Hua (2015), "Combining
Momentum with Reversal in Commodity Futures", *Journal of Banking & Finance*
59, 423-444, DOI `10.1016/j.jbankfin.2015.07.006`.

The complete accepted-manuscript review and bounded pure-reversal extraction
are recorded in `strategy-seeds/sources/BIANCHI-MOMREV-2015/source.md`. Source
returns, significance, correlations, and broad-portfolio properties are not
imported.

## 7. Risk Model

Q02 uses one aggregate `RISK_FIXED=1000` package budget,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Each leg receives half the budget
through independent `ATR(20) * 3.5` hard-stop sizing. Both leg requests,
including their frozen stops and half-budget lots, must validate before the
first order is sent; any second-leg or composition failure closes the package.
Friday close and all news axes are OFF for the monthly native-price baseline.
Both registered magics participate in the framework kill switch, MAE tracking,
position/deal history, persisted attempt marker, and orphan repair.

No live setfile, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, or correlation waiver is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-02 | initial approved pure 18-month reversal carrier | Q01/Q02 build only |
| v1.1 | 2026-08-09 | approved-card conformance build | task `f505c697-5956-41ef-8341-e79c4af92ef4`; exact tie epsilon, pre-sized atomic legs, dual-magic registration |
