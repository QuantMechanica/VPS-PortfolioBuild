# USDJPY/EURGBP Cointegration G0 Authorization

Date: 2026-08-06

Authority: OWNER forex-portfolio mission delivered to Codex on the
`agents/board-advisor` branch: mechanize one concrete next-best unbuilt pair
from the frozen 66-pair FX cointegration scan, prefer repair of QM5_12532 or
QM5_12533 only if either remains blocked at Q02, use structural low-frequency
logic and a `RISK_FIXED` baseline, and enqueue Q02 without touching live or
portfolio-gate state.

## Decision

Approve one bounded V5 Strategy Card for the first relationship not already
mechanized by either a dedicated sleeve or an explicit pair slot in an
umbrella cointegration EA: `USDJPY.DWX` / `EURGBP.DWX`, D1. Development may
request exactly one deterministic EA ID, register two traded magic slots,
build one frozen-beta two-leg basket with a `basket_manifest.json`, compile it
strictly, and enqueue one logical Q02 baseline after Q01 PASS.

This approval is a one-shot falsification test. It does not assert that the
pair is profitable, stationary out of sample, currency-neutral, uncorrelated
to the certified book, or eligible for portfolio admission.

## Anchor triage

Canonical Strategy Farm history resolves the requested repair priority:

- `QM5_12532` has a logical-basket Q02 PASS and Q04 PASS, followed by Q05 FAIL.
- `QM5_12533` has a logical-basket Q02 PASS, followed by Q04 FAIL.
- Neither anchor has an open ONINIT or NO_HISTORY Q02 blocker.

Changing or re-enqueueing either anchor would duplicate completed funnel work.

## Source and scan boundary

The reputable structural source is the OWNER-ratified Tier-A extraction of
Ernest P. Chan, *Quantitative Trading* (Wiley, 2009), Examples 3.6, 7.2, 7.3,
and 7.5, preserved at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. It supplies
the fitted spread, standardized-deviation entry, mean-reach exit,
cointegration-versus-correlation discipline, and low-frequency daily
implementation. Chan makes no USDJPY/EURGBP performance claim.

Pair selection comes only from the OWNER-requested frozen Darwinex D1 scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, reproduced with:

```powershell
python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges
```

The exact rank-60 row is:

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| USDJPY / EURGBP | 0.252701098850 | -0.456864966287 | -6.371810072221% | 13 | -1.281773609960 | 132.813394758594 D1 bars |

The negative OOS result, roughly 133-bar half-life, and sub-floor inferred
cadence are adverse findings, not parameters to repair. A terminal Q02
economic or cadence failure retires the exact sleeve.

## Non-duplicate decision

The deterministic research check found no exact slug or strategy-ID collision
across 4,303 registry rows and 420 direct cards. Two fuzzy hits were manually
resolved as sibling relationships with different first or second legs. A
separate review of tracked basket manifests found no exact USDJPY/EURGBP
two-leg relationship.

Rank 58 (`GBPUSD.DWX` / `USDJPY.DWX`) is already pair slot 5 in
`QM5_1156_caldeira-cointegration-pairs-fx`; rank 59 is the dedicated
`QM5_20240_usdchf-gbpjpy` sleeve. The Caldeira umbrella's six-symbol universe
does not contain EURGBP. Broad baskets that merely contain both symbols as
unrelated universe members do not implement this fixed D1 residual.

## Structural and kill boundary

- Fixed spread: `ln(USDJPY) - (-1.281773609960) * ln(EURGBP)`.
- Closed D1 bars; strictly prior 60-bar z-score window.
- Entry at `abs(z) > 2.0`; package exit at `abs(z) < 0.5`.
- Negative-beta long spread buys both legs; short spread sells both legs.
- Two ATR(20) x 2.0 hard stops, atomic package entry, partial-entry rollback,
  and orphan cleanup.
- `GBPUSD.DWX` and `EURUSD.DWX` are conversion-history-only; neither receives
  an order or magic slot.
- Backtest risk only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Retire below the binding Q02 frequency floor or on terminal economic fail.
- No beta refit, rescue filter, parameter substitution, learned model, banned
  indicator, grid, martingale, pyramiding, live setfile, or deployment action.

## Capacity and safety boundary

The path-aware sample at `2026-08-06T09:45:58Z` observed five factory
terminals (`T2`, `T3`, `T4`, `T5`, and `T6`), below the binding ceiling of
seven. `T_Live` and an unrelated FTMO terminal were observed separately and
excluded; neither was controlled.

No manual tester or smoke run is authorized. This decision excludes `T_Live`,
AutoTrading, deploy or live manifests, portfolio admission, portfolio KPI,
Q08 contribution paths, correlation waivers, and downstream promotion.
