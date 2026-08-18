# QM5_41059_wti-samecal-hit - Strategy Spec

EA ID: `QM5_41059`

Slug: `wti-samecal-hit`

Strategy ID: `KELOHARJU-PAPAILIAS-WTI-SAMECALHIT-2026_S01`

Source: `KELOHARJU-PAPAILIAS-WTI-SAMECALHIT-2026`

Author: Codex

Last revised: 2026-08-18

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 tick of each genuine normalized broker
month, reconstruct up to ten prior completed occurrences of that same calendar
month, requiring at least five valid log returns. Map every non-negative return
to one and every negative return to zero. Buy when the equal-weight positive
frequency is at least the source-defined `0.40`; sell otherwise.

Return magnitudes, recent contiguous momentum, fitted coefficients, and
current-month prices never enter the signal. One slot-0 WTI position carries a
frozen `3.5 * ATR(20,D1)` hard stop, no target, and closes at the next
normalized month boundary. A 35-calendar-day guard repairs stale exposure.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_lookback_years` | 10 | exact prior-year cap |
| `strategy_min_observations` | 5 | valid matching-month sample floor |
| `strategy_positive_threshold` | 0.40 | source-defined hit-rate boundary |
| `strategy_atr_period_d1` | 20 | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 35 | stale-position guard |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | preserve monthly identity |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `410590000`.
- No companion, read-only symbol, alias, or external market series.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Decision cadence: one consumed attempt per normalized broker month.
- Formation: exact completed same-calendar-month returns in years `Y-1`
  through `Y-10`.
- Hold: to the next normalized month boundary, with 35-day stale repair.

## 5. Expected Behaviour

- Approximately twelve completed positions per full post-warm-up year when
  matching-month history is valid; invalid-history months remain flat.
- Symmetric structural WTI seasonality with magnitude-free sign counting.
- One fixed-risk position at a time and no same-month retry.
- Q02 retires below five completed positions per full year.

## 6. Source Citation

Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities," *The
Journal of Finance* 71(4), 1557-1590, DOI `10.1111/jofi.12398`; and Papailias,
Liu, and Thomakos (2021), "Return Signal Momentum," *Journal of Banking &
Finance* 124, 106063, DOI `10.1016/j.jbankfin.2021.106063`.

Canonical bounded source packet:
`strategy-seeds/sources/KELOHARJU-PAPAILIAS-WTI-SAMECALHIT-2026/source.md`.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
Position sizing uses the frozen completed-bar ATR stop through the V5 risk
helper. Signal frequency never scales risk. Both news axes are OFF. Framework
Friday close is disabled. The kill switch, broker hard stop, malformed-state
repair, later-month repair, and stale guard remain active.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio admission, decorrelation claim,
correlation waiver, portfolio-gate change, external feed, retry, scale-in,
grid, martingale, pyramid, target, trail, or partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-18 | approved build directory identity | source approval `cd8ab88a1`; registry allocation `36a5d38ba` |
| v1-q40 | 2026-08-18 | pre-build identity correction | rejected median-equivalent majority; amendment `decisions/2026-08-18_qm5_41059_q40_identity_amendment.md` |
| v1-build | 2026-08-18 | deterministic V5 implementation | exact same-calendar q40 WTI hit-rate renewal; strict Q01 PASS |
