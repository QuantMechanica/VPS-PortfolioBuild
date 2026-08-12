# QM5_20254_xauxag-vr-fade - Strategy Spec

**EA ID:** QM5_20254

**Slug:** `xauxag-vr-fade`

**Sources:** `CME-MEHLITZ-XAUXAG-VRFADE-2026`

**Author:** Research+Development

**Last revised:** 2026-08-06

## 1. Strategy Logic

On each new `XAUUSD.DWX` D1 bar, reconstruct 33 synchronized completed month
ends for XAU and XAG and require the 32 relative monthly returns to exhibit a
significantly negative heteroskedasticity-robust `q=2` variance-ratio state.
Only then standardize 60 completed D1 gold/silver log ratios and fade a
displacement beyond `+/-1.5` with one opposite-direction two-leg package.

One package risk budget is split equally across frozen
`3.5*ATR(20,D1)` hard stops. Close both legs when the completed-D1 ratio
z-score enters `+/-0.25`, at the next broker-month boundary, after 35 calendar
days, or immediately on an orphan or malformed package. One qualified attempt
is permitted per broker month; Friday close is disabled because the package
may span a weekend.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_vr_window_months` | 32 | Relative-return memory sample |
| `strategy_vr_q` | 2 | Locked short-memory order |
| `strategy_significance_z` | 1.64485362695147 | Two-sided 10% boundary |
| `strategy_ratio_lookback_d1` | 60 | Completed-D1 log-ratio sample |
| `strategy_ratio_entry_z` | 1.5 | Absolute ratio displacement entry |
| `strategy_ratio_exit_z` | 0.25 | Absolute ratio convergence exit |
| `strategy_history_bars` | 1200 | Bounded D1 month-end reconstruction |
| `strategy_atr_period_d1` | 20 | Completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 3.5 | Frozen per-leg hard-stop distance |
| `strategy_max_hold_days` | 35 | Monthly stale guard |
| `strategy_xau_max_spread_pts` | 1500 | Maximum XAU entry spread |
| `strategy_xag_max_spread_pts` | 3000 | Maximum XAG entry spread |
| `strategy_deviation_points` | 20 | Order deviation |

All values are locked for Q02. No baseline parameter sweep is authorized.

## 3. Symbol Universe

- Logical basket: `QM5_20254_XAU_XAG_VRFADE_D1`.
- Host/slot 0: `XAUUSD.DWX`, magic `202540000`; registered liquid gold CFD
  carrier and ratio numerator.
- Companion/slot 1: `XAGUSD.DWX`, magic `202540001`; registered liquid silver
  CFD carrier and ratio denominator.
- Exactly one opposite-direction package; standalone-leg evaluation is
  invalid.

## 4. Timeframe

- Exact host timeframe: D1.
- Memory formation: 33 synchronized consecutive completed month ends.
- Ratio formation and convergence: 60 synchronized completed D1 bars.
- Lifecycle: at most one persisted qualified attempt per broker month.

## 5. Expected Behaviour

Expected cadence is 5-9 complete packages per full post-warm-up year; Q02
retires below five. Typical holding time is several D1 bars but never beyond
the next broker-month transition or 35 calendar days. The intended regime is a
statistically anti-persistent relative-return state with an extreme
gold/silver ratio displacement. Principal risks are state sparsity, legging,
financing, lot granularity, CFD-to-futures basis, common precious-metal and
USD factors, silver industrial beta, and realized overlap with the incumbent
XAU sleeve.

## 6. Source Citation

Mehlitz, J. S., and Auer, B. R. (2024), "Memory-enhanced momentum in commodity
futures markets," *The European Journal of Finance* 30(8), 773-802, DOI
`10.1080/1351847X.2023.2220118`.

Schweikert, K. (2018), "Are gold and silver cointegrated? New evidence from
quantile cointegrating regressions," *Journal of Banking & Finance* 88, 44-51,
DOI `10.1016/j.jbankfin.2017.11.010`; CME Group, "Gold & Silver Ratio Spread."

R1 lineage and R2-R4 PASS are recorded in
`strategy-seeds/cards/approved/QM5_20254_xauxag-vr-fade_card.md` and the
governed source packet
`strategy-seeds/sources/CME-MEHLITZ-XAUXAG-VRFADE-2026/source.md`. No source
tests the exact combined rule or Darwinex CFD carrier.

## 7. Risk Model

| Environment | Active risk input | Inactive risk input | Portfolio weight |
|---|---|---|---|
| Backtest | `RISK_FIXED=1000` | `RISK_PERCENT=0` | `1.0` |
| Live | `RISK_PERCENT>0` | `RISK_FIXED=0` | manifest-governed |

The Q02 logical-basket setfile uses the backtest row. Both legs split that one
fixed budget equally by hard-stop risk. Opposing directions do not guarantee
dollar, beta, volatility, factor, or portfolio neutrality.

There is no manual backtest, live/demo/shadow setfile, AutoTrading action,
`T_Live` access, deploy manifest, portfolio admission, or portfolio-gate
change.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-06 | Initial build from approved card | Q01 strict build/compile PASS: 0 failures, warnings, errors, or compiler warnings |
| v1-q02 | 2026-08-06 | Paced baseline handoff | One logical-basket Q02 work item enqueued; no manual test or dispatch |
