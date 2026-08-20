# QM5_41067_xng-wflip-mom - Strategy Spec

**EA ID:** QM5_41067

**Slug:** `xng-wflip-mom`

**Strategy ID:** `MOP-XNG-WFLIP-MOM-2026_S01`

**Source:** `MOP-XNG-WFLIP-MOM-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-20

## 1. Strategy Logic

On the first tradable `XNGUSD.DWX` D1 bar of a new broker week, normalize the
energy session label with one uniform zero-day or `+1`-day convention and
reconstruct three consecutive completed Monday-anchored broker-week-end
closes. Compute the two adjacent non-overlapping weekly log returns.

Buy only when the return sequence changes from negative to positive; sell
only when it changes from positive to negative. Follow the newest return sign
until the next broker week. Equal signs, exact zero, invalid history, or a
late attachment consume the week flat. One restart-safe attempt is consumed
per broker week before fallible gates. The position carries a frozen
`3.5 * ATR(20,D1)` hard stop, no target, and a ten-day stale guard.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | first-week-bar execution window |
| `strategy_history_bars` | 30 | bounded D1 endpoint buffer |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale-position repair |
| `strategy_max_spread_points` | 1500 | XNG entry cost guard |
| `qm_friday_close_enabled` | false | preserve full-week ownership |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework input |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host and traded symbol: exact `XNGUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `410670000` (governed allocation commit `5258258d0`).
- No companion, read-only symbol, alias, ratio, or external market series.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: two adjacent complete broker-week returns from three endpoints.
- Trigger: strict old-to-new return-sign change at the new-week boundary.
- Hold: until the first tick of the next broker week, with ten-day repair.

## 5. Expected Behaviour

- Approximately eighteen to thirty completed positions per full post-warm-up
  year.
- Symmetric direct-XNG fresh weekly trend-handoff continuation.
- One fixed-risk position and one consumed attempt per broker week.
- Q02 retires below five completed positions per full year.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Canonical bounded source packet:
`strategy-seeds/sources/MOP-XNG-WFLIP-MOM-2026/source.md`.

The paper supplies own-return sign continuation lineage and includes natural
gas. The weekly horizon and adjacent-week sign-change condition are disclosed
QM hypotheses; no source or WTI-sibling result transfers to this standalone
CFD implementation.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
Position sizing uses a frozen completed-bar ATR stop through the V5 risk
helper. Both news axes and Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio admission, decorrelation claim,
correlation waiver, portfolio-gate change, external feed, retry, scale-in,
grid, martingale, pyramid, target, trail, break-even move, or partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-20 | approved build-directory identity | source approval `258db74a0`; deterministic registry allocation in the branch registry commit |
| v1-build | 2026-08-20 | deterministic V5 implementation and validation | 9 reference tests PASS; strict compile/build check PASS with 0 errors and 0 warnings; static P1 PASS |
| v1-q02 | 2026-08-20 | paced queue admission stopped at the host-CPU ceiling | target-only dry run eligible; no apply and no work item created |
