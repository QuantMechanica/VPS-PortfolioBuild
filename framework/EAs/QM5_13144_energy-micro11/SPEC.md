# QM5_13144_energy-micro11 - Strategy Spec

**EA ID:** QM5_13144
**Slug:** energy-micro11
**Strategy ID:** FAN-MICROMOM-2014_XTI_XNG_S01
**Source:** Fan (2014), *Momentum Investing in Commodity Futures*, Chapter 3
**Last revised:** 2026-07-11

## 1. Strategy Logic

The EA runs one D1 logical basket from XTIUSD.DWX. On the first host bar of
each broker month, it obtains each energy leg's last completed D1 close before
the t-11 and t-10 month boundaries and computes the log return between them.

It buys the higher isolated-return leg and shorts the lower-return leg. Fixed
package risk is split equally, both legs receive frozen ATR(20) times 3.5 hard
stops, and the package closes at the next monthly transition, after 35 days,
or immediately on an orphan or invalid composition.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| strategy_far_boundary_months | 11 | locked | source-defined far boundary |
| strategy_near_boundary_months | 10 | locked | source-defined near boundary |
| strategy_history_bars | 420 | 380-500 | bounded D1 endpoint buffer |
| strategy_max_boundary_gap_days | 10 | 7-10 | endpoint freshness guard |
| strategy_atr_period_d1 | 20 | 14-30 | D1 hard-stop ATR |
| strategy_atr_sl_mult | 3.5 | 2.5-5.0 | frozen stop multiple |
| strategy_max_hold_days | 35 | locked | stale package guard |
| strategy_xti_max_spread_pts | 1500 | 1000-2500 | XTI spread cap |
| strategy_xng_max_spread_pts | 3000 | 2000-4500 | XNG spread cap |
| strategy_deviation_points | 20 | 10-50 | basket order deviation |

The 11/10 completed-month boundaries, isolated log return,
higher-versus-lower direction, monthly cadence, equal half-risk carrier, and
no same-month re-entry are locked.

## 3. Symbol Universe

- Logical symbol: QM5_13144_XTI_XNG_MICRO11_D1.
- Host/traded slot 0: XTIUSD.DWX, D1, magic 131440000.
- Traded slot 1: XNGUSD.DWX, D1, magic 131440001.
- No other symbol or timeframe is authorized.

## 4. Timeframe

The host and both signal legs use D1 bars. A signal forms only when the
framework D1-derived calendar key enters a new broker month and the immediately
prior host bar has a different month key. The current month and prior ten
complete months do not enter the rank.

## 5. Expected Behaviour

- Approximately twelve completed packages/year after warm-up; retire below
  five packages/year.
- Typical hold is one broker month, bounded by a 35-day stale guard.
- The carrier is opposite-side and equal fixed-risk, not guaranteed dollar or
  beta neutral.
- XNG gaps, legging, CFD rolls, and the narrow rank make risk high.
- Later portfolio gates alone may establish realized book correlation.

## 6. Source Citation And Evidence Boundary

Fan, John Hua (2014), *Momentum Investing in Commodity Futures*, PhD thesis,
Griffith University, Chapter 3 "Microscopic Momentum," pp. 62-106.

The source ranks up to 27 commodity futures on one isolated prior-month return
and uses a one-month hold. The EA narrows the test to two continuous CFDs, uses
broker D1 closes rather than collateralized futures-index excess returns, and
adds implementation risk controls. The exact rule is thesis/working-paper
evidence rather than a journal result; no source performance, significance,
drawdown, cost, or correlation statistic is imported.

## 7. Risk Model

| Environment | Active mode | Value |
|---|---|---:|
| Backtest Q02+ | RISK_FIXED | 1000 per package, split 50/50 |
| Live | not authorized | none |

The EA calls QM_LotsForRisk and applies the 0.5 package share after framework
sizing. It validates broker volume metadata and flattens a failed two-leg
entry. There is no TP, trail, break-even, partial close, scale-in, grid,
martingale, or pyramiding.

## 8. Four-Module Mapping

- No-Trade: exact host, locked endpoints, bounded history, endpoint
  freshness/order, arithmetic, spread, ATR, lot, magic, package, and
  prior-attempt guards.
- Entry: isolated t-11/t-10 return rank, paired orders, equal fixed-risk
  allocation, and frozen hard stops.
- Management: next-month close, 35-day time stop, deal-history same-month
  suppression, composition validation, and orphan cleanup.
- Close: QM_TM_ClosePosition for package exits plus broker hard stops.

## 9. Safety Boundary

No live setfile, T_Live change, AutoTrading action, deploy manifest, portfolio
gate change, admission artifact, external runtime data, banned indicator, or
ML is authorized.
