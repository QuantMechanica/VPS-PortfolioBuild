# QM5_41039_xauxag-mflow-div - Strategy Spec

**EA ID:** QM5_41039  
**Slug:** `xauxag-mflow-div`  
**Strategy ID:** `WILLIAMS-SCHWEIKERT-MOP-XAUXAG-MFLOWDIV-2026_S01`  
**Source:** `WILLIAMS-SCHWEIKERT-MOP-XAUXAG-MFLOWDIV-2026`  
**Author:** Codex  
**Last revised:** 2026-08-17

## 1. Strategy Logic

At the first executable synchronized XAU/XAG D1 tick of a new broker month,
the EA reconstructs every completed session in the immediately prior month
plus the preceding month-end anchor. For each metal it separately sums prior-
close-to-open and open-to-close log returns, subtracts silver from gold for
each component, and reconciles both metal totals and their relative total to
the completed month-end returns.

It enters only when the relative component sums have strictly opposite signs:
positive session-relative flow buys XAU and sells XAG; negative session-
relative flow sells XAU and buys XAG. Direction follows session-relative flow
irrespective of the completed relative-total sign. Agreement, exact zero,
invalid synchronization, or failed reconciliation consumes the month flat.

The month attempt is persisted before fallible signal and execution gates. A
logical package targets equal absolute USD notionals, caps combined frozen-
stop risk at one fixed-dollar budget, uses per-leg `3.5 * ATR(20,D1)` hard
stops, has no target, and closes both legs at the first observed next-month
boundary. Friday close is disabled to preserve the authorized month hold.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion route |
| `strategy_min_prior_month_bars` | 15 | minimum synchronized complete-month sessions |
| `strategy_max_prior_month_bars` | 25 | maximum synchronized complete-month sessions |
| `strategy_entry_grace_minutes` | 180 | first-new-month restart boundary |
| `strategy_history_bars` | 90 | bounded month/anchor scan |
| `strategy_reconcile_tolerance` | 1e-10 | per-metal and relative telescoping tolerance |
| `strategy_atr_period_d1` | 20 | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen per-leg hard-stop distance |
| `strategy_max_hold_days` | 40 | stale-package guard |
| `strategy_xau_max_spread_points` | 1500 | host entry spread ceiling |
| `strategy_xag_max_spread_points` | 1500 | companion entry spread ceiling |
| `strategy_max_notional_mismatch_pct` | 20.0 | post-rounding package guard |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Logical basket: `QM5_41039_XAU_XAG_MFLOWDIV_D1`.
- Host/traded slot 0: exact `XAUUSD.DWX`, D1, magic `410390000`.
- Companion/traded slot 1: exact `XAGUSD.DWX`, D1, magic `410390001`.
- Both legs are one package; neither leg is a standalone strategy.

## 4. Timeframe

- Host and signal timeframe: D1.
- Decision cadence: one consumed attempt per broker month.
- Formation: every synchronized completed session of the immediately prior
  month, anchored at the preceding month-end closes.
- Hold: current broker month through the first observed next-month boundary.

## 5. Expected Behaviour

- Approximately 5-8 completed packages per full post-warm-up year after
  strict relative information-flow opposition.
- Symmetric session-relative long/short package direction; agreement and exact
  zero remain flat.
- One aggregate fixed-risk package at a time, equal-notional target, and
  immediate orphan rollback.
- Q02 retires below five completed packages per full year.

## 6. Source Citation

Williams, Larry R. (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
Trading; Schweikert, Karsten (2018), "Are gold and silver cointegrated? New
evidence from quantile cointegrating regressions," *Journal of Banking &
Finance* 88, 44-51; Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse
Heje (2012), "Time Series Momentum," *Journal of Financial Economics* 104(2),
228-250; and CME Group, "Gold & Silver Ratio Spread."

The bounded composite packet is
`strategy-seeds/sources/WILLIAMS-SCHWEIKERT-MOP-XAUXAG-MFLOWDIV-2026/source.md`.

## 7. Risk Model

Q02 uses one logical `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both leg volumes are solved jointly so combined frozen-
stop risk stays within the package budget while actual absolute notionals
remain within 20%. Signal magnitude never scales risk. Both news axes and
framework Friday close are OFF; the kill switch, broker stops, next-month
exit, orphan repair, and stale repair remain active.

No live/demo/shadow/stress/optimization setfile, AutoTrading, `T_Live`, deploy
manifest, portfolio admission, neutrality claim, correlation waiver,
portfolio-gate change, or live-manifest change is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-17 | approved build directory identity | source/G0/card and EA-ID registry complete |
| v1-build | 2026-08-17 | deterministic implementation | Q01 PENDING |
| v1-queue | 2026-08-17 | paced Q02 handoff | PENDING capacity check and enqueue |
