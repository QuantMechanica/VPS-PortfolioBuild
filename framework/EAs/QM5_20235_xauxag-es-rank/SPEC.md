# QM5_20235_xauxag-es-rank - Strategy Spec

- **EA ID:** QM5_20235
- **Strategy ID:** `YIYI-ES-2025_XAU_XAG_S03`
- **Source:** Qin et al. (2025), DOI `10.1002/fut.22559`
- **Last revised:** 2026-08-06

## 1. Strategy Logic

On the first tradable XAU D1 bar of each broker month, reconstruct timestamps
common to XAU and XAG and select simple daily returns whose ending dates belong
to exactly the prior twelve completed broker-calendar months. For each metal,
sort those returns and average the lowest `ceil(N * 0.05)` observations.

Buy the metal with the higher expected-shortfall statistic (the less negative
lower tail), short the metal with the lower statistic, split one fixed-risk
package equally, and renew at the next month transition. A tie or invalid
history consumes the month and stays flat. This is a downside-tail rank, not a
price ratio, OLS residual, oscillator, momentum rule, skewness estimator, or
one-month signed-semivariance signal.

## 2. Parameters

| Parameter | Locked value | Meaning |
|---|---:|---|
| `strategy_es_window_months` | 12 | completed broker-calendar-month window |
| `strategy_tail_probability` | 0.05 | source lower-tail probability |
| `strategy_history_bars` | 400 | bounded synchronized D1 retrieval buffer |
| `strategy_min_daily_observations` | 220 | synchronized return floor |
| `strategy_atr_period_d1` | 20 | completed D1 hard-stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen per-leg stop distance |
| `strategy_max_hold_days` | 40 | stale package guard |
| `strategy_xau_max_spread_pts` | 1500 | XAU entry spread ceiling |
| `strategy_xag_max_spread_pts` | 3000 | XAG entry spread ceiling |
| `strategy_deviation_points` | 20 | basket-order deviation |

All framework, risk, news, Friday-close, stress, and strategy values are
fail-closed against this one authorized Q02 baseline.

## 3. Symbol Universe

- Host/slot 0: `XAUUSD.DWX`, magic `202350000`.
- Traded slot 1: `XAGUSD.DWX`, magic `202350001`.
- Logical Q02 symbol: `QM5_20235_XAU_XAG_ES_D1`.
- No standalone-leg interpretation or single-leg fallback is authorized.

## 4. Timeframe And Lifecycle

The host and both return series use D1. Decisions occur only on a genuine
broker-month transition. Formation excludes the current month, requires all
twelve expected month keys, and uses only timestamps common to both metals.
One terminal-global attempt marker plus owned-deal history prevents a restart
or stopped package from creating another same-month attempt. The package
closes before monthly renewal, after 40 days, or immediately on an orphan or
invalid composition.

## 5. Expected Behaviour

- Approximately twelve packages/year after warm-up; retire below five per
  complete post-warm-up year.
- Opposite sides and equal fixed-risk halves reduce common metal direction but
  do not guarantee dollar, beta, volatility, factor, or portfolio neutrality.
- XAG gaps, legging, tail-estimator instability, and a two-name rank make the
  risk class high.
- Q02 decides density and economics; Q09 alone may establish realized book
  correlation.

## 6. Source And Non-Duplicate Boundary

Qin, Cai, Zhu, and Webb (2025), "Commodity Futures Characteristics and Asset
Pricing Models," *Journal of Futures Markets* 45(3), 176-207, DOI
https://doi.org/10.1002/fut.22559, defines expected shortfall as the average of
the worst five percent of prior-twelve-month daily returns and ranks a broad
commodity-futures universe monthly. It does not test this two-metal CFD
carrier. Its broad one-way result is weak; no source or sibling performance,
cost, or correlation result transfers.

`QM5_13143_energy-es-rank` is the disclosed same-method XTI/XNG sibling.
Existing XAU/XAG ratio, OLS, skew, RSJ, return-reversal, calendar, momentum,
idiosyncratic-volatility, and shock builds use different information objects
or clocks. `QM5_12567` is a short-horizon long-only cumulative-RSI pullback.
The carrier extension therefore remains mechanically non-identical without
claiming proven efficacy or decorrelation.

## 7. Risk Model

Q02 is locked to `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` for the complete package. Each leg receives half of the
stop-normalized loss budget and a broker-side `3.5 * ATR(20,D1)` hard stop.
News axes and Friday close are OFF for the structural monthly baseline. No
live, demo, shadow, optimization, stress, or deployment setfile is created.

## 8. Four-Module Mapping

- no_trade: exact host/ID/slots, frozen inputs, synchronized completed-month
  history, calendar coverage, observation and tail-count floors, arithmetic,
  spread, attempt, magic, and package guards.
- trade_entry: prior-twelve-month expected-shortfall rank, paired orders,
  equal fixed-risk halves, frozen hard stops, and second-leg rollback.
- trade_management: next-month close, stale guard, composition validation,
  and orphan cleanup.
- trade_close: framework close helper, broker hard stops, and kill switch.

## 9. Safety Boundary

No live/demo/shadow setfile, manual backtest, T_Live change, AutoTrading
action, deploy manifest, portfolio gate change, admission artifact, external
runtime data, banned indicator, or ML is authorized.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-06 | initial approved XAU/XAG expected-shortfall carrier build |
| v1.1 | 2026-08-06 | strict compile and full V5 build check PASS with zero warnings |
| v1.2 | 2026-08-06 | Q02 enqueue withheld at the binding 8-of-7 factory-terminal CPU ceiling |
