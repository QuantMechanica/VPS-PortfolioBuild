# QM5_13129_energy-rsj - Strategy Spec

**EA ID:** QM5_13129
**Slug:** `energy-rsj`
**Strategy ID:** `KISS-RSJ-2025_XTI_XNG_S01`
**Source:** Kiss and Ferreira Batista Martins (2025), DOI `10.1016/j.frl.2025.108656`
**Last revised:** 2026-07-11

## 1. Strategy Logic

The EA runs one D1 logical basket from `XTIUSD.DWX`. On the first host bar of
a new broker month it reconstructs the immediately preceding complete month of
simple D1 close-to-close returns for XTI and XNG. For each leg it computes
upside realized semivariance, downside realized semivariance, and normalized
relative signed jump:

`RSJ = (RV_plus - RV_minus) / (RV_plus + RV_minus)`.

It buys the lower-RSJ leg and shorts the higher-RSJ leg. The fixed package risk
is split equally, each leg receives a frozen `ATR(20) * 3.5` hard stop, and the
package closes at the next month transition, after 35 days, or immediately on
an orphan or invalid composition.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| `strategy_lookback_months` | 1 | locked | completed broker month in the source RSJ window |
| `strategy_history_bars` | 80 | 60-120 | bounded D1 history buffer |
| `strategy_min_return_observations` | 15 | 15-18 | monthly return sufficiency floor |
| `strategy_atr_period_d1` | 20 | 14-30 | D1 hard-stop ATR |
| `strategy_atr_sl_mult` | 3.5 | 2.5-5.0 | frozen stop multiple |
| `strategy_max_hold_days` | 35 | locked | stale package guard |
| `strategy_xti_max_spread_pts` | 1500 | 1000-2500 | XTI spread cap |
| `strategy_xng_max_spread_pts` | 3000 | 2000-4500 | XNG spread cap |
| `strategy_deviation_points` | 20 | 10-50 | basket order deviation |

The completed-month window, exact RSJ formula, low-versus-high direction,
monthly renewal, equal half-risk carrier, and no same-month re-entry are locked.

## 3. Symbol Universe

- Logical symbol: `QM5_13129_ENERGY_RSJ_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1, magic `131290000`.
- Traded slot 1: `XNGUSD.DWX`, D1, magic `131290001`.
- No other symbol or timeframe is authorized.

## 4. Timeframe

The host and both signal legs use D1 bars. Signal formation runs only on the
first tradable host D1 bar of each broker month and excludes the current month.
The `PERIOD_MN1` reference is a calendar-key cadence, not an MN1 price read.

## 5. Expected Behaviour

- Approximately 12 completed packages/year after warm-up; retire below five.
- Typical hold is one broker month, bounded by a 35-day stale guard.
- The carrier is opposite-side and equal-risk, not guaranteed beta or dollar
  neutral.
- XNG gaps, legging, and the narrow two-asset rank make the risk class high.
- Q09 alone may establish realized correlation to the portfolio book.

## 6. Source Citation

Kiss, Tamas, and Igor Ferreira Batista Martins (2025), "Good Volatility, Bad
Volatility and the Cross Section of Commodity Returns," *Finance Research
Letters* 86, Part D, article 108656, DOI
https://doi.org/10.1016/j.frl.2025.108656.

The paper uses daily observations on 36 collateralized commodity futures,
monthly RSJ sorts, and extreme portfolios. WTI and natural gas are explicit
members. This EA narrows the test to two continuous CFDs and equal fixed-risk
legs. That cross-section and basis translation must be falsified by Q02 and
later gates; no source performance number is imported.

## 7. Risk Model

| Environment | Active mode | Value |
|---|---|---:|
| Backtest Q02+ | `RISK_FIXED` | 1000 per package, split 50/50 |
| Live | not authorized | none |

The EA calls `QM_LotsForRisk` and applies the 0.5 package share only after
framework sizing. It validates broker volume metadata and flattens a failed
two-leg entry. There is no TP, trail, break-even, partial close, scale-in, grid,
martingale, or pyramiding.

## 8. Four-Module Mapping

- **No-Trade:** exact host, parameter, bounded history, observation, arithmetic,
  spread, ATR, lot, package, and monthly-attempt guards.
- **Entry:** completed-month RSJ calculation and rank, paired orders, equal
  fixed-risk allocation, and frozen hard stops.
- **Management:** next-month close, 35-day time stop, restart-safe month check,
  composition validation, and orphan cleanup.
- **Close:** `QM_TM_ClosePosition` for package exits plus broker hard stops.

## 9. Safety Boundary

No live setfile, T_Live change, AutoTrading action, deploy manifest, portfolio
gate change, admission artifact, external runtime data, banned indicator, or ML
is authorized.
