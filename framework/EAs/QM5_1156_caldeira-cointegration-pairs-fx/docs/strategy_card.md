---
ea_id: QM5_1156
slug: caldeira-cointegration-pairs-fx
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
sources:
  - "[[sources/ssrn-financial-economics-network]]"
concepts:
  - "[[concepts/statistical-arbitrage]]"
  - "[[concepts/cointegration-pair-spread]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/rolling-ols-regression]]"
  - "[[indicators/engle-granger-adf]]"
  - "[[indicators/spread-z-score]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "R1 PASS SSRN/paper attribution; R2 PASS fixed cointegration/z-score entry-exit rules; R3 PASS FX DWX pairs testable; R4 PASS no ML/grid/martingale, 1-pos-per-pair-magic."
---

# QM5_1156 Caldeira-Moura Cointegration-Pairs (FX Port)

## Quelle
- Primary: SSRN 2196391 — Caldeira, J.F., Moura, G.V. (2013) "Selection
  of a Portfolio of Pairs Based on Cointegration: A Statistical
  Arbitrage Strategy." Brazilian Review of Finance / published version in
  Journal of International Financial Markets, Institutions and Money.
  https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2196391
- Reported result: cointegration-selected pairs (Engle-Granger
  two-step) traded with z-score thresholds outperform distance-based
  pairs (Gatev et al 2006) net of costs; Sharpe ratio ~1.5 on Brazilian
  equity universe 2005-2011, robust under reasonable transaction-cost
  assumptions.
- Lineage: extends Engle-Granger 1987 cointegration framework
  (Nobel-laureate methodology) into pair-selection. Related to
  Vidyamurthy (2004 "Pairs Trading" book), Krauss (2017 SSRN 2967523
  review). Distinct from Gatev-Goetzmann-Rouwenhorst distance-pairs
  (QM5_1129) — that paper ranks by minimum sum-of-squared-distances on
  normalized price series; this paper ranks by cointegration test
  p-value, yielding more statistically grounded long-run-equilibrium
  pairs.

## Mechanik

### Entry
- **Universe**: 6 G10 USD-crosses on DXZ — EURUSD, GBPUSD, USDJPY,
  USDCHF, AUDUSD, NZDUSD.
- **Pair formation**: enumerate all `C(6,2) = 15` candidate ordered
  pairs (X, Y).
- **Cointegration test (weekly re-estimation, Friday close)**: for each
  pair run rolling 60-day OLS `Y_t = α + β · X_t + ε_t` on D1 log
  prices. Apply Engle-Granger augmented Dickey-Fuller (ADF) test on
  residual `ε_t`. Pair is "active" if ADF p-value < 0.05.
- **Spread z-score (daily, on active pairs)**: compute residual
  `ε_t = log(Y_t) - α - β · log(X_t)` using latest weekly-estimated
  `α, β`. Standardize over last 60 daily residuals →
  `z_t = (ε_t - μ_60) / σ_60`.
- **Entry trigger**:
  - if `z_t > +2.0` → short Y, long `β` units of X (spread
    overvalued, mean-reverts down)
  - if `z_t < -2.0` → long Y, short `β` units of X (spread
    undervalued, mean-reverts up)
- One position per pair-magic at a time (HR4 1-pos-per-magic).

### Exit
- Profit-target: close pair when `|z_t| < 0.5` (full mean reversion).
- Hard time-stop: close pair after 30 trading days regardless of z
  (avoids stale positions when cointegration breaks).
- Cointegration-loss exit: if weekly re-estimation finds pair's ADF
  p-value rises above 0.10, force-close any open position on that
  pair next session and remove from active set until p-value
  re-crosses 0.05.

### Stop Loss
- Spread divergence stop: close pair when `|z_t| > 4.0` (regime
  change suspected; cointegration probably broken intra-week before
  re-estimation catches it).
- Per-leg ATR(D1,14) × 3 hard stop on each leg independently as
  catastrophic-fail safety net.
- Portfolio MAX_DD 20 % trip (HR3/5 mandatory).

### Position Sizing
- V5 standard: `RISK_FIXED = $1,000` per pair-magic for P2 baseline,
  `RISK_PERCENT` for live (HR4).
- Leg sizing: leg-Y notional sized to `RISK_FIXED`, leg-X notional
  scaled by hedge ratio `β` from current week's OLS estimate.
- Net dollar exposure ≈ 0 by construction.

### Zusätzliche Filter
- Skip new entries 24 h before high-impact news (NFP, FOMC, ECB)
  per V5 standard news-calendar filter.
- Skip pair if either leg has < 60 D1 bars of history.
- Maximum simultaneous active pairs: 4 (avoids over-leverage).
  Tie-break by ADF p-value (smallest = strongest cointegration).

## Concepts
- [[concepts/statistical-arbitrage]] -- primary
- [[concepts/cointegration-pair-spread]] -- mechanism
- [[concepts/mean-reversion]] -- secondary
- [[concepts/cross-asset-pair]] -- structural

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | SSRN 2196391, peer-reviewed publication (Journal of International Financial Markets 2013). Both authors academic finance (UFRGS Brazil + UFSC); cointegration methodology itself is Engle-Granger 1987 (Nobel 2003). Confirmed by Krauss (2017) review and dozens of subsequent SSRN replications across markets |
| R2 Mechanical | PASS | Rolling OLS + ADF p-value + z-score threshold + fixed exit z-cross. Every parameter (60d window, p<0.05 in, p>0.10 out, z=±2 entry, z=±0.5 exit, z=±4 stop, 30d time-stop) is a fixed constant from the paper. ADF is a statistical test, not learning. No adaptive coefficients |
| R3 Data Available | PASS | 6 G10 USD-crosses live on DXZ with full D1 history 2018-07+; pair-formation needs only 60 D1 bars warmup. Cross-section of 6 instruments yielding 15 candidate pairs is comfortable; paper used 100+ Brazilian stocks but mechanic generalises to small universes |
| R4 ML Forbidden | PASS | OLS regression is closed-form. ADF is a unit-root hypothesis test, not statistical learning. Z-score is standardisation. No neural nets, no adaptive parameters (weekly re-estimation refreshes α,β from new data but the *rule* — Engle-Granger two-step — is fixed). Hedge ratio β is a regression coefficient on observed data, not a learned model. No grids, no martingale |

## Pipeline-Verlauf
- G0: 2026-05-17 — drafted from SSRN FEN batch 4 (autonomous wake), PENDING

## Verwandte Strategien
- Sibling of QM5_1129 (gatev-distance-pairs-fx) — same universe (G10
  FX), different pair-selection criterion (cointegration p-value vs
  sum-of-squared-distances). Expected to surface different pair
  sub-sets; performance differential in P2 will indicate whether
  cointegration-based selection is worth the added compute over
  distance-based.
- Distinct from QM5_1126 (moskowitz-tsmom-12m) — TSMOM is trending,
  pairs is mean-reverting; orthogonal signal families.
- Adjacent: QM5_1142 (jegadeesh-1w-reversal-fx) — short-horizon FX
  reversal; this card is the long-horizon-equilibrium reversion
  cousin.

## Lessons Learned (während Pipeline-Lauf)
- *(populated as pipeline progresses)*

## Implementation Notes for Codex (P1)
- DWX symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX,
  AUDUSD.DWX, NZDUSD.DWX.
- Timeframe: D1 for cointegration test + z-score; M30 for execution
  on entry/exit triggers.
- Use built-in ADF test implementation (numpy.linalg + statsmodels-style
  closed-form) — embed minimum p-value table inline; no external
  package needed.
- Magic-slot allocation: 15 pair-slots (one per ordered pair) per HR4.
  Only 4 active simultaneously per "max active pairs" filter.
- P3 sweep candidates: 30d / 60d / 90d cointegration window; ADF
  p-threshold 0.01 / 0.05 / 0.10; entry z-threshold 1.5 / 2.0 / 2.5;
  exit z-threshold 0.0 / 0.5 / 1.0; with/without 30d time-stop;
  long-only vs long-short pair-side.
- Logging: persist daily z-scores + ADF p-values per pair to a CSV
  alongside trades — needed for P3 sweep analysis and P5 ablation
  visibility.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung pipeline_phase aktualisieren + last_updated. Bei FAIL: pipeline_phase: DEAD + Lessons-Learned-Eintrag.*
