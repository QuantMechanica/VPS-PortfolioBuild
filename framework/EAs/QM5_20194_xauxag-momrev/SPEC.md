# QM5_20194_xauxag-momrev - Strategy Spec

**EA ID:** QM5_20194
**Slug:** `xauxag-momrev`
**Strategy ID:** `BIANCHI-MOMREV-2015_XAU_XAG_S02`
**Source:** `BIANCHI-MOMREV-2015`
**Author:** Codex
**Last revised:** 2026-08-01

## 1. Strategy Logic

The EA runs one XAU/XAG D1 logical basket from `XAUUSD.DWX`. At a genuine
broker-month transition it reconstructs synchronized completed month-end
closes for both metals and calculates overlapping 12- and 18-completed-month
log returns. It buys the 12-month winner and shorts the loser only when the
18-month rank is exactly reversed. Same-rank or tied states remain flat.

The 12/18 double-sort is fixed by the approved Bianchi-Drew-Fan lineage. The
two-CFD carrier is deliberately narrow and does not inherit the source's broad
portfolio results. One month is consumed before history, signal, news,
spread, sizing, or order gates, and partial packages are flattened.

## 2. Parameters

| Parameter | Default | Authorized values | Meaning |
|---|---:|---|---|
| `strategy_momentum_months` | 12 | locked | source first-sort horizon |
| `strategy_reversal_months` | 18 | locked | source second-sort horizon |
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

- `XAUUSD.DWX`: host, traded slot 0, magic `201940000`.
- `XAGUSD.DWX`: companion, traded slot 1, magic `201940001`.
- `QM5_20194_XAU_XAG_MOMREV_D1`: logical Q02 basket symbol.

Standalone-leg testing, other symbols, or a carrier substitution is outside
this build.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Decision cadence | first tradable host D1 bar of each broker month |
| Formation | synchronized completed month-end closes at 0/12/18 months |
| Holding period | next month transition, maximum 35 calendar days |
| Warm-up | at least 18 completed months inside a 520-D1 buffer |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Packages/year | approximately 5-9; Q02 retires below five |
| Typical hold | one broker month |
| Direction | opposite XAU/XAG legs only |
| Drawdown profile | high: gaps, legging, narrow breadth, silver beta |
| Neutrality | simultaneous long/short only; not proven factor neutrality |

## 6. Source Citation

Bianchi, Robert J.; Drew, Michael E.; and Fan, John Hua (2015), "Combining
Momentum with Reversal in Commodity Futures", *Journal of Banking & Finance*
59, 423-444, DOI `10.1016/j.jbankfin.2015.07.006`.

The complete accepted-manuscript review and the bounded XAU/XAG extraction are
recorded in `strategy-seeds/sources/BIANCHI-MOMREV-2015/source.md`. Source
returns, significance, and correlations are not imported.

## 7. Risk Model

Q02 uses one aggregate `RISK_FIXED=1000` package budget,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Each leg receives half the budget
through independent `ATR(20) * 3.5` hard-stop sizing. Friday close and all news
axes are OFF for the monthly native-price baseline. The framework kill switch,
broker stops, close-before-renew, 35-day stale exit, position/deal history,
persisted attempt marker, and orphan repair remain active.

No live setfile, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, or correlation waiver is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-01 | initial approved XAU/XAG carrier | Q01/Q02 build only |
