# GBPUSD/EURGBP Cointegration G0 Authorization

Date: 2026-08-05

Authority: OWNER forex-portfolio mission delivered to Codex on the
`agents/board-advisor` branch: mechanize one concrete next-best unbuilt pair
from the frozen 66-pair FX cointegration scan, prefer repair of QM5_12532 or
QM5_12533 only if either remains blocked at Q02, use structural low-frequency
logic and a `RISK_FIXED` baseline, and enqueue Q02 without touching live or
portfolio-gate state.

## Decision

Approve one bounded V5 Strategy Card for the first genuinely unbuilt pair in
the current OOS-Sharpe frontier: `GBPUSD.DWX` / `EURGBP.DWX`, D1. Development
may request exactly one deterministic EA ID, register two traded magic slots,
build one fixed-beta two-leg basket with a `basket_manifest.json`, compile it
strictly, and enqueue one logical Q02 baseline after Q01 PASS.

This approval is a one-shot falsification test. It does not assert that the
pair is profitable, stationary out of sample, currency-neutral, uncorrelated
to the certified book, or eligible for portfolio admission.

## Anchor triage

Canonical Strategy Farm work-item history resolves the requested repair
priority:

- `QM5_12532` has a logical Q02 PASS and Q04 PASS, followed by Q05 FAIL.
- `QM5_12533` has a logical Q02 PASS, followed by Q04 FAIL.
- Neither anchor has an open ONINIT or NO_HISTORY Q02 blocker.

Changing or re-enqueueing either anchor would duplicate completed funnel work.

## Source and scan boundary

The reputable structural source is the CEO-ratified Tier-A packet for Ernest
P. Chan, *Quantitative Trading* (Wiley, 2009), Examples 3.6, 7.2, 7.3, and
7.5, preserved at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. It supplies
the fitted spread, standardized-deviation entry, mean-reach exit,
cointegration-versus-correlation discipline, and low-frequency daily
implementation. Chan makes no GBPUSD/EURGBP performance claim.

Pair selection comes only from the OWNER-requested frozen Darwinex D1 scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, reproduced with:

```powershell
python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges
```

The exact rank-44 row is:

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| GBPUSD / EURGBP | -0.078883 | -0.098985 | -0.844505% | 17 | -0.399228065 | 149.505 D1 bars |

The negative DEV and OOS results, negative fitted beta, and slow half-life are
adverse findings, not parameters to repair. A terminal Q02 economic or cadence
failure retires the exact sleeve.

## Non-duplicate decision

The deterministic research dedup check returned CLEAN. Exact text and
registry searches plus unordered traded-symbol manifest reconciliation found
no dedicated two-leg GBPUSD/EURGBP fixed-beta D1 card, allocation, EA, or
logical basket. Broad FX baskets containing both symbols do not trade this
exact residual.

Rank 43 is already represented by `QM5_12766` (USDJPY/USDCHF). Rank 44 is
therefore the first current gap after the latest mechanized frontier row.

## Structural and kill boundary

- Fixed spread: `ln(GBPUSD) - (-0.399228065) * ln(EURGBP)`.
- Closed D1 bars; strictly prior 60-bar z-score window.
- Entry at `abs(z) > 2.0`; package exit at `abs(z) < 0.5`.
- Negative-beta long spread buys both legs; short spread sells both legs.
- Two ATR(20) x 2.0 hard stops, atomic package entry, partial-entry rollback,
  and orphan cleanup.
- Backtest risk only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Retire below the binding Q02 frequency floor or on terminal economic fail.
- No beta refit, rescue filter, parameter substitution, ML, banned indicator,
  grid, martingale, pyramiding, live setfile, or deployment action.

## Safety boundary

No manual tester or smoke run is authorized while the factory is CPU-bound.
This decision excludes `T_Live`, AutoTrading, deploy or live manifests,
portfolio admission, portfolio KPI, Q08 contribution paths, correlation
waivers, and downstream promotion.
