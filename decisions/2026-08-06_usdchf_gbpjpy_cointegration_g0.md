# USDCHF/GBPJPY Cointegration G0 Authorization

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
umbrella cointegration EA: `USDCHF.DWX` / `GBPJPY.DWX`, D1. Development may
request exactly one deterministic EA ID, register two traded magic slots,
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
implementation. Chan makes no USDCHF/GBPJPY performance claim.

Pair selection comes only from the OWNER-requested frozen Darwinex D1 scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, reproduced with:

```powershell
python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges
```

The exact rank-59 row is:

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| USDCHF / GBPJPY | -0.078836 | -0.429689 | -4.294957% | 15 | -0.070133022 | 95.663 D1 bars |

The negative DEV/OOS result, small absolute hedge coefficient, and roughly
96-bar half-life are adverse findings, not parameters to repair. A terminal
Q02 economic, cadence, or minimum-volume failure retires the exact sleeve.

## Non-duplicate decision

The deterministic research check scanned 4,297 registry rows and 413 direct
card candidates without an exact slug, strategy-ID, or primary-target pair
collision. A separate review of 256 tracked basket manifests found no exact
USDCHF/GBPJPY two-leg relationship.

Rank 58 (`GBPUSD.DWX` / `USDJPY.DWX`) is not eligible: it is already
mechanized as pair slot 5 in `QM5_1156_caldeira-cointegration-pairs-fx`, with
a concrete backtest setfile and rolling OLS/ADF spread logic. Broad baskets
that merely contain USDCHF and GBPJPY as unrelated universe members do not
implement this fixed D1 residual. Rank 59 is therefore the first current
relationship-level build gap.

## Structural and kill boundary

- Fixed spread: `ln(USDCHF) - (-0.070133022445) * ln(GBPJPY)`.
- Closed D1 bars; strictly prior 60-bar z-score window.
- Entry at `abs(z) > 2.0`; package exit at `abs(z) < 0.5`.
- Negative-beta long spread buys both legs; short spread sells both legs.
- Two ATR(20) x 2.0 hard stops, atomic package entry, partial-entry rollback,
  and orphan cleanup.
- `USDJPY.DWX` is conversion-history-only; it receives no order or magic slot.
- Backtest risk only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Retire below the binding Q02 frequency floor, if the small hedge leg cannot
  meet broker minimum volume, or on terminal economic fail.
- No beta refit, rescue filter, parameter substitution, learned model, banned
  indicator, grid, martingale, pyramiding, live setfile, or deployment action.

## Capacity and safety boundary

The path-aware sample at `2026-08-06T04:47:25Z` observed six factory terminals
(`T1`, `T2`, `T4`, `T5`, `T8`, and `T10`), below the binding ceiling of seven.
`T_Live` and an unrelated FTMO terminal were observed separately and excluded;
neither was controlled.

No manual tester or smoke run is authorized. This decision excludes `T_Live`,
AutoTrading, deploy or live manifests, portfolio admission, portfolio KPI,
Q08 contribution paths, correlation waivers, and downstream promotion.
