# EURGBP/AUDJPY Cointegration G0 Review Handoff

**Date:** 2026-07-10  
**Branch:** `agents/board-advisor`  
**Candidate:** `EURGBP.DWX` / `AUDJPY.DWX`, D1  
**Card:** `strategy-seeds/cards/eurgbp-audjpy_card.md`

## Outcome

The existing non-duplicate EURGBP/AUDJPY draft is submitted for OWNER +
Quality-Business G0 review. It is the highest-ranked strict all-sign row from
the OWNER-requested 66-pair scan that does not already have an EA build.

No EA ID was allocated and no build or Q02 row was created. The card remains
blocked from Development until G0 is OWNER-approved and Development allocates
the ID through the deterministic registry.

## Reproduction

The checked-in scan now exposes the sign-aware extension explicitly while
preserving its original positive-hedge default:

```powershell
python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges
```

The command uses the same fixed inputs documented by the source:

- Darwinex `.DWX` D1 exports under `D:/QM/mt5/T_Export/MQL5/Files`.
- DEV before 2023-01-01 and OOS from 2023-01-01.
- Fixed DEV beta, 60-bar spread z-score, entry at `|z| > 2`, exit at
  `|z| < 0.5`, and approximate `0.8 bp/leg` round-trip cost.
- Strict screen: DEV net Sharpe above zero, OOS net Sharpe above 0.8, and at
  least four OOS state changes.

Reproduced EURGBP/AUDJPY row:

| Metric | Value |
|---|---:|
| DEV net Sharpe | 0.4168335930 |
| OOS net Sharpe | 0.8918614046 |
| OOS return | 4.475153414% |
| OOS state changes | 20 |
| Fixed DEV beta | -0.1220286930 |
| Half-life | 36.83805248 D1 bars |

The primary empirical lineage is the OWNER-requested in-house scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. The method supplement
is Ernest Chan, *Quantitative Trading* (Wiley, 2009), Example 3.6 and Chapter
7, whose approved local extraction is
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`.

## Review Risks

- The fitted beta is negative, so long-spread and short-spread packages put
  both legs in the same direction. Regression neutrality does not imply
  currency, carry, or portfolio neutrality.
- The absolute beta is small, concentrating package exposure in EURGBP.
- OOS Sharpe clears the research threshold narrowly, and swap was not modeled.
- These risks must be judged at G0; they do not authorize a new filter,
  adaptive refit, or parameter change.

## Structural Contract If Approved

- One logical two-leg basket EA with `basket_manifest.json`.
- Closed-bar D1 logic, fixed beta, fixed z-score thresholds, atomic package
  entry, ATR hard stops, and broken-package cleanup.
- Canonical logical backtest setfile with `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
- No ML, banned indicators, grid, martingale, pyramiding, or live setfile.

## Capacity And Safety

At handoff the paced farm had seven active Q02 jobs, equal to the current CPU
ceiling used by this mission. No MT5 process was launched. No `T_Live`,
AutoTrading, deploy manifest, portfolio gate, `portfolio_admission`, portfolio
KPI, or Q08 contribution path was touched.
