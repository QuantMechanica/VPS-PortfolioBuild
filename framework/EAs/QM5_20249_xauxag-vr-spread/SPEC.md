# QM5_20249_xauxag-vr-spread - Strategy Spec

**EA ID:** QM5_20249

**Slug:** `xauxag-vr-spread`

**Sources:** `MEHLITZ-AUER-MEM-2024` and `CME-GSR-SPREAD-2025`

**Author:** Research+Development

**Last revised:** 2026-08-06

## 1. Strategy Logic

At the first processed `XAUUSD.DWX` D1 bar of each broker month, consume that
month's only attempt and reconstruct 33 consecutive, synchronized completed
month-end closes for XAU and XAG. Form 32 chronological XAU-minus-XAG log
returns and calculate the locked heteroskedasticity-robust `q=2`
variance-ratio state.

When the state is significantly persistent, follow the latest relative
return; when significantly anti-persistent, reverse it; otherwise remain flat.
A positive direction buys XAU and sells XAG, while a negative direction sells
XAU and buys XAG.

One package risk budget is split equally across frozen
`3.5 * ATR(20,D1)` hard stops. There is no target. Close both legs at the next
month boundary, after 35 calendar days, or immediately on an orphan or invalid
package. Friday close is disabled because the holding period spans weekends.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_vr_window_months` | 32 | Relative-return memory sample |
| `strategy_vr_q` | 2 | Locked short-memory order |
| `strategy_significance_z` | 1.64485362695147 | Two-sided 10% boundary |
| `strategy_history_bars` | 1200 | Bounded D1 endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | Completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 3.5 | Frozen per-leg hard-stop distance |
| `strategy_max_hold_days` | 35 | Monthly stale guard |
| `strategy_xau_max_spread_pts` | 1500 | Maximum XAU entry spread |
| `strategy_xag_max_spread_pts` | 3000 | Maximum XAG entry spread |
| `strategy_deviation_points` | 20 | Order deviation |

All values are locked for Q02. No baseline parameter sweep is authorized.

## 3. Symbol Universe

- Logical basket: `QM5_20249_XAU_XAG_VRSPREAD_D1`.
- Host/slot 0: `XAUUSD.DWX`, magic `202490000`.
- Companion/slot 1: `XAGUSD.DWX`, magic `202490001`.
- Exactly one opposite-direction pair; standalone-leg evaluation is invalid.

## 4. Timeframe

- Exact host timeframe: D1.
- Formation: 33 synchronized consecutive completed month ends.
- Signal: exactly 32 chronological relative monthly log returns.
- Lifecycle: one persisted attempt per broker month.

## 5. Expected Behaviour

Expected cadence is 6-10 complete packages per year after warm-up; Q02 retires
below five per full post-warm-up year. Principal risks are legging and
financing, lot granularity, CFD-to-futures basis, common-metal and
industrial-silver factors, unstable memory classification, and realized
correlation with the incumbent XAU sleeve.

## 6. Source Citation

Mehlitz, J. S., and Auer, B. R. (2024), "Memory-enhanced momentum in commodity
futures markets," *The European Journal of Finance* 30(8), 773-802, DOI
`10.1080/1351847X.2023.2220118`.

CME Group, "Gold & Silver Ratio Spread."

The governed composite packet is
`strategy-seeds/sources/CME-MEHLITZ-XAUXAG-VRSPREAD-2026/source.md`; the
approved card is
`strategy-seeds/cards/approved/QM5_20249_xauxag-vr-spread_card.md`. Neither
source tests the exact relative-return variance-ratio intersection or these
continuous CFDs.

## 7. Risk Model

Backtests use one logical-basket setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Both legs share the one fixed
budget equally by hard-stop risk. Both news axes, stress rejection, and Friday
close are OFF.

There is no manual backtest, live/demo/shadow setfile, AutoTrading action,
`T_Live` access, deploy manifest, portfolio admission, or portfolio-gate
change.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-06 | Initial build from approved G0 card | Q01 strict compile PASS; 0 errors and 0 warnings |
