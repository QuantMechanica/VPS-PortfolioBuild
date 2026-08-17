# QM5_41036_wti-mflow-dom - Strategy Spec

**EA ID:** QM5_41036  
**Slug:** `wti-mflow-dom`  
**Strategy ID:** `WILLIAMS-MOP-WTI-MFLOWDOM-2026_S01`  
**Source:** `WILLIAMS-MOP-WTI-MFLOWDOM-2026`  
**Author:** Codex  
**Last revised:** 2026-08-17

## 1. Strategy Logic

At the first executable `XTIUSD.DWX` D1 tick of a new normalized broker month,
the EA reconstructs every completed session in the immediately prior month
plus the preceding month-end anchor. It separately sums prior-close-to-open
and open-to-close log returns. It enters only when the two sums have strictly
opposite signs and their total reconciles to the completed month return. It
follows whichever component has larger absolute magnitude: positive dominant
flow buys and negative dominant flow sells. Equal magnitude, agreement, or
exact zero consumes the month flat. Magnitude selects direction only.

The month attempt is persisted before fallible signal and execution gates. A
position receives a frozen `3.5 * ATR(20,D1)` hard stop, no target, and closes
at the first observed next-month boundary. Friday close is disabled to
preserve the authorized month hold.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_min_prior_month_bars` | 15 | minimum complete-month sessions |
| `strategy_max_prior_month_bars` | 25 | maximum complete-month sessions |
| `strategy_entry_grace_minutes` | 180 | first-new-month restart boundary |
| `strategy_history_bars` | 90 | bounded month/anchor scan |
| `strategy_reconcile_tolerance` | 1e-10 | telescoping arithmetic tolerance |
| `strategy_atr_period` | 20 | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale-position guard |
| `strategy_max_spread_points` | 1500 | entry spread ceiling |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- `XTIUSD.DWX` only.
- Magic slot 0, magic `410360000`.
- No secondary symbol, logical basket, or runtime symbol substitution.

## 4. Timeframe

- Host and signal timeframe: D1.
- Decision cadence: one consumed attempt per normalized broker month.
- Formation: every completed session of the immediately prior month, anchored
  at the preceding month-end close.
- Hold: current broker month through the first observed next-month boundary.

## 5. Expected Behaviour

- Approximately 5-8 positions per full post-warm-up year after strict
  information-flow opposition.
- Symmetric absolute-dominance long/short direction; agreement, equal
  magnitude, and exact zero remain flat.
- One fixed-risk backtest position at a time.
- Q02 retires below five completed positions per full year.

## 6. Source Citation

Williams, Larry R. (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
Trading; and Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje
(2012), "Time Series Momentum," *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`.

The governed complete-read lineages are
`strategy-seeds/sources/SRC03/source.md` and
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; the bounded composite packet
is `strategy-seeds/sources/WILLIAMS-MOP-WTI-MFLOWDOM-2026/source.md`.

## 7. Risk Model

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The hard stop is the only lot-sizing distance. Signal
magnitude never scales risk. Both news axes and framework Friday close are OFF
for the native-price month carrier; the kill switch, broker stop, next-month
exit, and stale repair remain active.

No live setfile, AutoTrading, T_Live, deploy manifest, portfolio admission,
correlation waiver, portfolio-gate change, or live-manifest change is
authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-17 | approved build | source/G0/card and deterministic identities complete |
| v1-build | 2026-08-17 | deterministic implementation | Q01 PASS: 20 fixtures; strict compile/build gate 0 errors, warnings, or failures |
| v1-q02 | - | paced target-only handoff | Q02 NOT_ENQUEUED |
