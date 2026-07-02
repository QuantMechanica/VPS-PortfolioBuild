---
ea_id: QM5_12919
slug: amp-value-momentum-xasset
expected_trades_per_year_per_symbol: 12
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
sources:
  - "[[sources/ssrn-financial-economics-network]]"
concepts:
  - "[[concepts/cross-asset-multi-factor]]"
  - "[[concepts/value-momentum-combo]]"
indicators:
  - "[[indicators/rolling-return]]"
  - "[[indicators/long-horizon-mean-reversion]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: Single source_id present; Asness-Moskowitz-Pedersen JoF 2013 (SSRN 1363476) is a single canonical peer-reviewed attribution.
r2_mechanical: PASS
r2_reasoning: Rolling-return computations, cross-sectional Z-score, and fixed 50/50 linear combination are closed-form and fully deterministic.
r3_data_available: PASS
r3_reasoning: NDX.DWX, WS30.DWX, GDAXI.DWX, UK100.DWX and four G10 FX USD-crosses are all DWX-available with sufficient D1 history for 60-month lookback.
r4_ml_forbidden: PASS
r4_reasoning: Pure rolling-return Z-score with fixed weights, one magic slot per instrument — no ML, no adaptive coefficients.
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "Asness-Moskowitz-Pedersen 2013 JoF 68(3) SSRN 1363476 value+momentum cross-asset 50/50 Z-combo top-3 8-instrument basket; HR14 deterministic Z-rank not adaptive R1-R4 PASS"
---

# QM5_1143 Asness-Moskowitz-Pedersen Value-and-Momentum Everywhere (Cross-Asset)

## Quelle
- Primary: SSRN 1363476 — Asness, C., Moskowitz, T.J., Pedersen, L.H.
  (2013) "Value and Momentum Everywhere" Journal of Finance 68(3),
  pp. 929-985. https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1363476
- Reported result: value (mean-reverting long-horizon return) and
  momentum (medium-horizon trend) signals BOTH have positive expected
  return AND are negatively correlated with each other across 8 distinct
  markets: US, UK, Europe, Japan equities; equity-index futures; G10
  bonds; G10 FX; commodities. A simple equal-weighted combo (50/50
  value + momentum) earns higher Sharpe than either signal alone due
  to diversification.
- Lineage: synthesizes Fama-French value + Jegadeesh-Titman momentum
  into a cross-asset framework. ~2500 citations, AQR runs commercial
  strategies on this combined signal. Replicated by Israel-Moskowitz
  (2013), Geczy-Samonov (2016), Baltussen-van Vliet-van Vliet (2023).

## Mechanik

### Entry
- **Monthly** rebalance on first trading day of each calendar month.
- Universe: 8 instruments spanning two asset classes —
  - 4 equity indices: GDAXI, NDX, UK100, WS30 (DXZ live-tradable)
  - 4 G10 USD-crosses: EURUSD, GBPUSD, USDJPY, AUDUSD
- For each instrument compute two signals:
  - **Momentum signal** `M`: trailing 12-month return minus most-recent
    1-month return (per AMP convention to avoid 1m reversal contamination).
    `M = close[t-21] / close[t-273] - 1` (i.e. 252-bar return ending
    1 month ago).
  - **Value signal** `V`: long-horizon reversal proxy — negative of
    trailing 60-month return.
    `V = -1 × (close[t-21] / close[t-21-1260] - 1)` (1260 D1 bars ≈ 60m).
- Standardize both signals within the universe (cross-sectional Z-score
  using the 8 instruments' values, recomputed monthly).
- **Combined score** `S = 0.5 × Z(M) + 0.5 × Z(V)`.
- Rank universe by `S` descending.
- **Long** the top-3 instruments.
- (Long-short variant in P3 sweep: also short bottom-3.)
- Equal-weight within long basket.

### Exit
- Hold until next monthly rebalance.
- At rebalance: re-score, swap positions to maintain top-3 long basket.

### Stop Loss
Per-position ATR(D1,14) × 3 hard stop. Portfolio MAX_DD 20 % trip
(HR3/5 mandatory).

### Position Sizing
V5 standard: `RISK_FIXED = $1,000` per instrument per cycle for P2
baseline, `RISK_PERCENT` for live (HR4). The paper uses constant-
vol-targeting which is excluded at baseline (P3 sweep variant only).

### Zusätzliche Filter
- Skip rebalance for any instrument with insufficient 1260-bar
  history (60m lookback is binding).
- News-calendar filter (V5 mandatory).
- Optional regime overlay (P3): require trailing 252d vol below ceiling.

## Concepts
- [[concepts/cross-asset-multi-factor]] -- primary
- [[concepts/value-momentum-combo]] -- mechanism
- [[concepts/cross-sectional-ranking]] -- structural

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Asness-Moskowitz-Pedersen JoF 2013, ~2500 citations, cornerstone cross-asset-factor reference. All three authors tenured / AQR principals; commercial strategies (AQR Style Premia) trade on this signal. Multi-decade evidence base, replicated by Israel-Moskowitz (2013), Baltussen et al (2023) |
| R2 Mechanical | PASS | Two rolling-return calculations per instrument per month + cross-sectional Z-score + linear combo. All operations are closed-form. Z-score on 8-instrument universe is standardisation, not statistical learning |
| R3 Data Available | PASS | DXZ has 4 indices + 4+ G10 USD-crosses with sufficient D1 history. 8-instrument universe is smaller than paper's 8-market-class scope but preserves the cross-asset diversification. The paper's bond + commodity legs are NOT included (DXZ bond/commodity universe too narrow); equity + FX is the testable subset |
| R4 ML Forbidden | PASS | Pure rolling-return + cross-sectional Z-score + linear combination. No ML, no adaptive coefficients (50/50 weight is fixed per paper), no online learning. Z-score is a statistical transform, not a learned model |

## Pipeline-Verlauf
- G0: 2026-05-17 — drafted from SSRN FEN batch 3 (autonomous wake), PENDING

## Verwandte Strategien
- Subsumes: QM5_1126 (moskowitz-tsmom-12m) and QM5_1141
  (debondt-thaler-3y-reversal-idx) as single-signal special cases.
  AMP combines both into one ranked portfolio. Expected to outperform
  either single-signal cousin via signal-diversification effect.
- Distinct from: QM5_1072 (as-gem-dualmom) — dual-momentum uses
  cross-sectional + absolute momentum signal combo on similar
  universe but no value (reversal) component. AMP adds the reversal
  leg.
- Adjacent: QM5_1127 (menkhoff-carry-fxvol-filter), QM5_1095
  (qp-dollar-carry-basket) — carry is a third orthogonal factor
  not included in this card's signal stack; possible future
  carry-momentum-value triple-factor card if AMP performs.

## Lessons Learned (während Pipeline-Lauf)
- *(populated as pipeline progresses)*

## Implementation Notes for Codex (P1)
- DWX symbols (8-instrument basket):
  GDAXI.DWX, NDX.DWX, UK100.DWX, WS30.DWX,
  EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX.
- Timeframe: D1 for signals, M30 for execution at monthly rebalance.
- "Monthly rebalance" — first trading session of each calendar month.
- Z-score = `(x - mean(universe)) / stdev(universe)` recomputed each
  rebalance over the 8 simultaneous values (cross-sectional, NOT
  rolling time-series).
- Magic-slot allocation: per HR4, distinct magic per instrument
  (8 slots).
- P3 sweep: 50/50 vs 30/70 vs 70/30 V/M weighting; top-2 / 3 / 4
  selection; long-only vs long-short; 12m vs 6m momentum lookback;
  36m vs 60m value lookback; with/without vol targeting.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung pipeline_phase aktualisieren + last_updated. Bei FAIL: pipeline_phase: DEAD + Lessons-Learned-Eintrag.*
