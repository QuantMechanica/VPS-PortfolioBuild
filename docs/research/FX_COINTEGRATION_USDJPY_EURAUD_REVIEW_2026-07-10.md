# USDJPY/EURAUD Cointegration G0 Review

**Date:** 2026-07-10  
**Branch:** `agents/board-advisor`  
**Candidate:** `USDJPY.DWX` / `EURAUD.DWX`, D1  
**Card:** `strategy-seeds/cards/usdjpy-euraud_card.md`

## Outcome

The final non-duplicate strict row from the sign-aware reproduction of the
OWNER-requested 66-pair scan is approved for the explicit forex-book mission.
The atomic registry allocator reserved `QM5_13119` with strategy ID
`SRC02_S10`.

The two anchor sleeves are not Q02 setup blockers: `QM5_12532` has Q02 and
Q04 PASS followed by Q05 FAIL, while `QM5_12533` has Q02 PASS followed by
Q04 FAIL. Neither has an open ONINIT or NO_HISTORY Q02 row to repair.

## Reproduction

```powershell
python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges
```

| Metric | Value |
|---|---:|
| DEV net Sharpe | 0.5059112597 |
| OOS net Sharpe | 0.8837435895 |
| OOS return | 16.014828283% |
| OOS state changes | 23 |
| Fixed DEV beta | -1.4182482312 |
| Half-life | 77.45654457 D1 bars |

The primary empirical lineage is
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. The reputable method
supplement is Ernest Chan, *Quantitative Trading* (Wiley, 2009), Example 3.6
and Chapter 7, locally extracted at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`.

## Review Risks

- The OOS Sharpe clears the research threshold narrowly.
- The negative beta makes both package legs point in the same direction.
- The long half-life makes swap and Friday flattening material.
- The cross-bloc relation has no shared currency leg and may be unstable.
- The scan used approximate costs and did not model swap.

No adaptive refit, regime filter, carry filter, grid, martingale, banned
indicator, or ML component is authorized to hide those risks. Q02 onward is
the judge.

## Structural Contract

- One logical two-leg basket with `basket_manifest.json`.
- Closed-bar D1 logic, fixed beta, fixed z-score thresholds, atomic package
  entry, ATR hard stops, and orphan cleanup.
- A logical backtest setfile with `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
- No live setfile, deployment action, or portfolio-gate change.

