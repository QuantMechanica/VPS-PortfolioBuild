# QM5_41056_energy-rev18 - Strategy Spec

**EA ID:** QM5_41056
**Slug:** `energy-rev18`
**Strategy ID:** `BIANCHI-MOMREV-2015_XTI_XNG_S04`
**Source:** `BIANCHI-XTIXNG-REV18-2026`
**Author:** Codex
**Last revised:** 2026-08-18

## 1. Strategy Logic

The EA runs one XTI/XNG D1 logical basket from `XTIUSD.DWX`. At a genuine
broker-month transition it reconstructs synchronized completed month-end
closes for both energies and calculates each leg's 18-completed-month log
return. It buys the long-horizon loser and shorts the winner. A rank
difference with absolute value at or below `1e-12` consumes the month and
remains flat.

This is the pure long-term reversal information object from the approved
Bianchi-Drew-Fan lineage. It does not calculate or gate on the sibling
12-month momentum rank, a price-ratio z-score, a weekday, an event, or an
inventory input. One month is consumed before history, signal, news, spread,
sizing, or order gates, and partial packages are flattened.

## 2. Parameters

| Parameter | Default | Authorized values | Meaning |
|---|---:|---|---|
| `strategy_reversal_months` | 18 | locked | source reversal horizon |
| `strategy_history_bars` | 520 | locked | bounded D1 endpoint buffer |
| `strategy_max_boundary_gap_days` | 10 | locked | boundary freshness |
| `strategy_atr_period_d1` | 20 | locked | completed stop volatility |
| `strategy_atr_sl_mult` | 3.5 | locked | frozen stop distance |
| `strategy_max_hold_days` | 35 | locked | stale package guard |
| `strategy_xti_max_spread_pts` | 1500 | locked | XTI spread cap |
| `strategy_xng_max_spread_pts` | 3000 | locked | XNG spread cap |
| `strategy_deviation_points` | 20 | locked | order deviation |

There is no Q02 parameter sweep.

## 3. Symbol Universe

- `XTIUSD.DWX`: host, traded slot 0, magic `410560000`.
- `XNGUSD.DWX`: companion, traded slot 1, magic `410560001`.
- `QM5_41056_ENERGY_REV18_D1`: logical Q02 basket symbol.

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
| Packages/year | approximately 11-12 non-tied signals; Q02 retires below five |
| Typical hold | one broker month |
| Direction | long 18-month loser, short winner |
| Drawdown profile | high: gaps, legging, narrow breadth, persistent relative trends |
| Regime preference | long-horizon cross-energy reversal |
| Neutrality | simultaneous long/short only; not proven dollar, beta, or factor neutrality |

## 6. Source Citation

Bianchi, Robert J.; Drew, Michael E.; and Fan, John Hua (2015), "Combining
Momentum with Reversal in Commodity Futures", *Journal of Banking & Finance*
59, 423-444, DOI `10.1016/j.jbankfin.2015.07.006`.

The complete accepted-manuscript review is recorded in
`strategy-seeds/sources/BIANCHI-MOMREV-2015/source.md`; the bounded energy
carrier extraction is in
`strategy-seeds/sources/BIANCHI-XTIXNG-REV18-2026/source.md`. R1 lineage is
recorded and R2-R4 are approved in the Strategy Card. Source returns,
significance, correlations, and broad-portfolio properties are not imported.

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
portfolio admission, neutrality claim, decorrelation claim, or correlation
waiver is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-18 | initial build from approved card | source `72bf6148c`; registry `0ceacf790`; magic `11cabe252`; G0 approved |
| v2 | 2026-08-18 | Q01 implementation and validation | build `3817b1177`; strict compile/build/P1 PASS; Q02 stopped before enqueue at tester and CPU ceilings |
