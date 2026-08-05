# USDCHF/NZDUSD Cointegration G0 Authorization

Date: 2026-08-05

Authority: OWNER forex-portfolio mission delivered to Codex on the
`agents/board-advisor` branch: mechanize one concrete next-best unbuilt pair
from the frozen 66-pair FX cointegration scan, prefer repair of QM5_12532 or
QM5_12533 only if either remains blocked at Q02, use structural low-frequency
logic and a `RISK_FIXED` baseline, and enqueue Q02 without touching live or
portfolio-gate state.

## Decision

Approve one bounded V5 Strategy Card for the first dedicated fixed-scan gap in
the current OOS-Sharpe frontier: `USDCHF.DWX` / `NZDUSD.DWX`, D1. Development
may request exactly one deterministic EA ID, register two traded magic slots,
build one frozen-beta two-leg basket with a `basket_manifest.json`, compile it
strictly, and enqueue one logical Q02 baseline after Q01 PASS.

This approval is a one-shot falsification test. It does not assert that the
pair is profitable, stationary out of sample, currency-neutral, uncorrelated
to the certified book, or eligible for portfolio admission.

## Anchor triage

Canonical Strategy Farm history resolves the requested repair priority:

- `QM5_12532` has logical-basket Q02 PASS and Q04 PASS, followed by Q05 FAIL.
- `QM5_12533` has logical-basket Q02 PASS, followed by Q04 FAIL.
- Neither anchor has an open ONINIT or NO_HISTORY Q02 blocker.

Changing or re-enqueueing either anchor would duplicate completed funnel work.

## Source and scan boundary

The reputable structural source is the OWNER-ratified Tier-A extraction of
Ernest P. Chan, *Quantitative Trading* (Wiley, 2009), Examples 3.6, 7.2, 7.3,
and 7.5, preserved at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. It supplies
the fitted spread, standardized-deviation entry, mean-reach exit,
cointegration-versus-correlation discipline, and low-frequency daily
implementation. Chan makes no USDCHF/NZDUSD performance claim.

Pair selection comes only from the OWNER-requested frozen Darwinex D1 scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, reproduced with:

```powershell
python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges
```

The exact rank-55 row is:

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| USDCHF / NZDUSD | 0.035539 | -0.387376 | -3.267369% | 16 | -0.270458913 | 108.268 D1 bars |

The negative OOS result, negative fitted beta, and very slow half-life are
adverse findings, not parameters to repair. A terminal Q02 economic or cadence
failure retires the exact sleeve.

## Non-duplicate decision

The deterministic research check scanned 4,289 registry rows and 405 direct
card candidates without an exact slug or strategy-ID collision. Its one fuzzy
hit was the USDJPY/NZDUSD sibling; manual review resolves that as a different
first leg, beta, residual, and logical basket. A separate review of 71 basket
manifests declaring `traded_symbols` found no exact USDCHF/NZDUSD two-leg
basket.

Two older umbrella systems expose the same unordered symbols as only one slot:
`QM5_1156` is a multi-pair M30 rolling-selection implementation, and
`QM5_1257` is a multi-pair H1 monthly Engle-Granger/refit implementation. They
do not implement this frozen rank-55 D1 residual, logical symbol, or one-shot
scan hypothesis, so the dedicated sleeve is mechanically distinct.

Ranks 51 through 54 already have dedicated builds (`QM5_12776`, `QM5_12778`,
`QM5_12781`, and `QM5_12783`), while rank 56 has `QM5_12786`. Rank 55 is the
first current dedicated-build gap.

## Structural and kill boundary

- Fixed spread: `ln(USDCHF) - (-0.270458913) * ln(NZDUSD)`.
- Closed D1 bars; strictly prior 60-bar z-score window.
- Entry at `abs(z) > 2.0`; package exit at `abs(z) < 0.5`.
- Negative-beta long spread buys both legs; short spread sells both legs.
- Two ATR(20) x 2.0 hard stops, atomic package entry, partial-entry rollback,
  and orphan cleanup.
- Both declared symbols are traded; no conversion-only symbol or magic slot.
- Backtest risk only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Retire below the binding Q02 frequency floor or on terminal economic fail.
- No beta refit, rescue filter, parameter substitution, learned model, banned
  indicator, grid, martingale, pyramiding, live setfile, or deployment action.

## Capacity and safety boundary

The path-aware sample at `2026-08-05T22:02:10Z` observed five factory
terminals (`T1`, `T3`, `T5`, `T7`, and `T8`), below the binding ceiling of
seven. `T_Live` and an unrelated FTMO terminal were observed separately and
excluded.

No manual tester or smoke run is authorized. This decision excludes `T_Live`,
AutoTrading, deploy or live manifests, portfolio admission, portfolio KPI,
Q08 contribution paths, correlation waivers, and downstream promotion.
