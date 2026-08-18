# QM5_41057_xauxag-wflow-agree-fade - Strategy Spec

**EA ID:** QM5_41057  
**Slug:** `xauxag-wflow-agree-fade`  
**Strategy ID:** `WILLIAMS-SCHWEIKERT-XAUXAG-WFLOWAGREEFADE-2026_S01`  
**Source:** `WILLIAMS-SCHWEIKERT-XAUXAG-WFLOWAGREEFADE-2026`  
**Author:** Codex  
**Last revised:** 2026-08-18

## 1. Strategy Logic

On the first executable synchronized XAU/XAG D1 tick of a genuine broker
Monday, the EA reconstructs the exact completed prior Monday-through-Friday
week plus the preceding Friday close anchor. For each metal it separately
sums prior-close-to-open and open-to-close log returns, subtracts silver from
gold for each component, and reconciles both metal totals and their relative
total to the frozen weekly endpoints.

It enters only when the relative overnight and session component sums have
the same strict sign. It then fades the completed relative week: positive
total sells XAU and buys XAG; negative total buys XAU and sells XAG.
Opposition, exact zero, invalid synchronization, or failed reconciliation
consumes the week flat.

The Monday attempt is persisted before fallible signal and execution gates. A
logical package targets equal absolute USD notionals, caps combined frozen-
stop risk at one fixed-dollar budget, uses per-leg `3.0 * ATR(20,D1)` hard
stops, has no target, and closes both legs at broker Friday hour 21. Later-
week and eight-day checks repair stale exposure.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion route |
| `strategy_entry_grace_minutes` | 180 | restart-safe Monday boundary |
| `strategy_reconcile_tolerance` | 1e-10 | per-metal and relative telescoping tolerance |
| `strategy_atr_period_d1` | 20 | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.0 | frozen per-leg hard-stop distance |
| `strategy_max_hold_days` | 8 | stale-package guard |
| `strategy_xau_max_spread_points` | 1500 | host entry spread ceiling |
| `strategy_xag_max_spread_points` | 1500 | companion entry spread ceiling |
| `strategy_max_notional_mismatch_pct` | 20.0 | post-rounding package guard |
| `qm_friday_close_hour_broker` | 21 | paired weekly exit clock |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Logical basket: `QM5_41057_XAU_XAG_WFLOWAGREEFADE_D1`.
- Host/traded slot 0: exact `XAUUSD.DWX`, D1, magic `410570000`.
- Companion/traded slot 1: exact `XAGUSD.DWX`, D1, magic `410570001`.
- Both legs are one package; neither leg is a standalone strategy.

## 4. Timeframe

- Host and signal timeframe: D1.
- Decision cadence: one consumed attempt per eligible broker Monday.
- Formation: exact synchronized completed prior Monday-through-Friday week,
  anchored at the preceding Friday closes.
- Hold: next Monday through broker Friday hour 21, with eight-day stale guard.

## 5. Expected Behaviour

- Approximately 15-30 completed packages per full post-warm-up year after the
  strict relative-flow agreement gate.
- Symmetric contrarian long/short package direction; component opposition and
  exact zero remain flat.
- One aggregate fixed-risk package at a time, equal-notional target, and
  immediate orphan rollback.
- Q02 retires below five completed packages per full year.

## 6. Source Citation

Williams, Larry R. (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
Trading; Schweikert, Karsten (2018), "Are gold and silver cointegrated? New
evidence from quantile cointegrating regressions," *Journal of Banking &
Finance* 88, 44-51; and CME Group, "Gold & Silver Ratio Spread."

The canonical bounded source packet is
`strategy-seeds/sources/WILLIAMS-SCHWEIKERT-XAUXAG-WFLOWAGREEFADE-2026/source.md`.

## 7. Risk Model

Q02 uses one logical `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both leg volumes are solved jointly so combined frozen-
stop risk stays within the package budget while actual absolute notionals
remain within 20%. Signal magnitude never scales risk. Both news axes are OFF;
framework Friday close is enabled at broker hour 21 as a paired-exit
fail-safe. The kill switch, broker stops, orphan repair, later-week repair,
and stale repair remain active.

No live/demo/shadow/stress/optimization setfile, AutoTrading, `T_Live`, deploy
manifest, portfolio admission, neutrality claim, correlation waiver,
portfolio-gate change, or live-manifest change is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-18 | approved build contract | source, G0 card, EA ID, and two magic slots allocated |
