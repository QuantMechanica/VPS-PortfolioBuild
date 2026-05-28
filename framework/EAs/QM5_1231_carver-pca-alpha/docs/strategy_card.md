---
ea_id: QM5_1231
slug: carver-pca-alpha
type: strategy
source_id: 2a380bee-1ec4-50d1-a348-b10fac642c7a
sources:
  - "[[sources/rob-carver-blog]]"
concepts:
  - "[[concepts/cross-sectional-alpha]]"
  - "[[concepts/pca-factor-model]]"
  - "[[concepts/diversifying-factor]]"
indicators:
  - "[[indicators/normalised-return]]"
  - "[[indicators/pca-factor]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
expected_trades_per_year_per_symbol: 12
g0_approval_reasoning: "R1 source URL/attribution present; R2 deterministic PCA/regression monthly entry and exit; R3 testable on DWX FX/index baskets; R4 fixed statistical transforms, no ML/grid/martingale, bounded one-position slots."
---

# QM5_1231 Carver PCA Alpha Persistence

## Quelle
- Source: [[sources/rob-carver-blog]]
- Primary URL: https://qoppac.blogspot.com/2025/09/
- Author: Rob Carver. The September 2025 post tests futures PCA factors and finds a modest positive effect from buying instruments with positive factor-model alpha while rejecting the residual mean-reversion branch.

## Mechanik

Monthly cross-sectional alpha-persistence factor. It estimates broad latent factors from volatility-normalised returns, regresses each instrument on the factors, and buys positive intercepts while selling negative intercepts for the next month.

### Entry
- Universe: one DWX group at a time, starting with FX majors and liquid indices. Require at least `8` valid symbols for the PCA variant; otherwise skip.
- On the first tradable D1 bar of each month:
  - Compute daily volatility-normalised returns for each symbol over the previous `252` bars.
  - Build a return matrix with common dates and z-score each symbol's return series.
  - Fit PCA on the prior `252` bars.
  - Default: keep `NumPC=3`; P3 variant `NumPC=1`.
  - For each symbol, regress its normalised returns on the retained PC return series over the same 252-bar window.
  - Store the regression intercept `alpha_i`.
  - Cross-sectionally winsorise alphas at the 10th/90th percentile.
  - `forecast_i = clamp(20 * alpha_i / MedianAbs(alpha), -20, +20)`.
- LONG symbols where `forecast_i > +5`.
- SHORT symbols where `forecast_i < -5`.
- Slot cap: at most `2` longs and `2` shorts per group, choosing the largest absolute forecasts.

### Exit
- Hold until the next monthly rebalance unless an emergency stop is hit.
- At rebalance, close positions no longer selected or whose forecast crosses zero.
- Flip only at monthly rebalance.

### Stop Loss
- Emergency stop: `2.5 * ATR(20, D1)`.
- Optional P3 variants: `2.0`, `2.5`, `3.0` ATR.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.5%`.
- Size from emergency stop distance. One position per symbol/magic.

### Zusätzliche Filter
- No residual mean-reversion branch; Carver reports that residual trading was weak with the wrong sign in the base test.
- Require at least `252` valid bars for every group member used in the PCA window.
- Spread cap: skip new entries when spread exceeds `2 * MedianSpread(20D)`.
- Rebalance monthly only to control turnover.

## Concepts
- [[concepts/cross-sectional-alpha]] - primary
- [[concepts/pca-factor-model]] - primary
- [[concepts/diversifying-factor]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named author and exact qoppac URL for the PCA alpha-persistence test and rejected residual branch. |
| R2 Mechanical | PASS | PCA window, regression alpha, forecast scaling, monthly rebalance, exits, and slot caps are deterministic. |
| R3 DWX-testbar | PASS | Uses only daily close-derived returns across DWX baskets; portable to FX and index groups with enough symbols. |
| R4 No ML | PASS | PCA/regression are fixed statistical transforms, not online learning or adaptive PnL parameters; slots are bounded. |

## R3 - T6 Live-Promotion-Caveat
N/A - proposed universe uses broker-routable DWX symbols only. SP500.DWX is not required.

## Pipeline-Verlauf
- G0: 2026-05-18 - drafted from Rob Carver blog fourth batch, PENDING.

## Verwandte Strategien
- [[strategies/QM5_1218_carver-relmomentum]] - cross-sectional return factor cousin.
- [[strategies/QM5_1209_carver-mrinasset]] - cross-sectional mean-reversion cousin.

## Lessons Learned (wahrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`.*
