---
ea_id: QM5_1128
slug: daniel-momentum-crash-vol-scale
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
sources:
  - "[[sources/ssrn-financial-economics-network]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/volatility-filter]]"
indicators:
  - "[[indicators/rolling-return]]"
  - "[[indicators/realized-volatility]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "Daniel/Moskowitz Momentum Crashes JFE 2016 (SSRN 2371227) 12mo TSMOM signal + realized-portfolio-vol scaling k=min(1.0, sigma_target/sigma_est) bounded scale-down only R1-R4 all PASS: R1 JFE peer-reviewed + Barroso-Santa-Clara independent confirm; R2 r12 sign + 63d realized-vol scalar + monthly reba"
---

# QM5_1128 Daniel-Moskowitz Momentum-Crash Volatility-Scaled

## Quelle
- Primary: SSRN 2371227 — "Momentum Crashes" by Kent Daniel, Tobias J.
  Moskowitz. Journal of Financial Economics 122(2), Nov 2016
  (working paper Mar 2014).
  URL: SSRN abstract 2371227
- Reported result: equity momentum suffers infrequent but catastrophic
  drawdowns ("momentum crashes" — 2009 example: -83 % in 3 months).
  Crashes are predictable ex-ante by momentum-portfolio realised
  volatility. Dynamic-scaling rule: target constant momentum-portfolio
  vol → scale gross exposure by `sigma_target / sigma_estimated`.
  Result: Sharpe rises from 0.45 (static momentum) to 0.85+ (dynamic),
  and worst-case drawdown roughly halves.
- Lineage: Barroso/Santa-Clara "Momentum Has Its Moments" (JFE 2015,
  same finding independently). Builds on Jegadeesh/Titman (1993)
  cross-sectional momentum classic.

## Mechanik

### Entry
- **Monthly** rebalance on first trading day.
- Step 1 — Momentum signal: per-instrument trailing 12-month return
  (same TSMOM signal family as QM5_1126). Sign → long/short/flat.
- Step 2 — **Vol-target scaling** (paper's key add-on):
  - Estimate own-portfolio realized vol: `sigma_est = stdev(daily_returns,
    63 bars) * sqrt(252)` (3-month rolling, annualised).
  - Target vol: `sigma_target = 0.15` (15% annualised, paper baseline).
  - Position-size scalar: `k = min(1.0, sigma_target / sigma_est)`.
  - Apply `k` to the V5 `RISK_FIXED` baseline → effective risk
    `= 1000 * k` per position. `k` is capped at 1.0 (never leverage up,
    only scale down — practitioner convention from Barroso-Santa-Clara).

### Exit
- Hold until next monthly rebalance.
- At rebalance: recompute `r12` and `sigma_est`; flip / hold / scale.
- **Intra-month vol-shock exit** (P3 variant): if `sigma_est` doubles
  intra-month, close immediately. Baseline does monthly-only checks.

### Stop Loss
The vol-scale logic *is* the paper's crash protection. V5 overlay
mandatory: per-position ATR(D1,14) * 3 hard stop AND portfolio MAX_DD
20 % trip (HR3/5).

### Position Sizing
V5 standard: `RISK_FIXED = $1,000 * k` for P2 baseline (where `k` is the
vol-scale multiplier from Step 2). `RISK_PERCENT * k` for live (HR4).
`k ∈ [0, 1]` — never leveraged up, only scaled down during high-vol
regimes.

### Zusätzliche Filter
- Skip rebalance if fewer than 63 D1 bars available for vol estimate.
- Skip if `r12` magnitude < 0.5% (zero-line noise filter, same as QM5_1126).
- V5 mandatory: news filter, MAX_DD trip.

## Concepts
- [[concepts/time-series-momentum]] -- primary signal
- [[concepts/volatility-filter]] -- the paper's key add-on (vol-targeting)

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Daniel/Moskowitz JFE 2016, ~1500 citations; independently corroborated by Barroso/Santa-Clara JFE 2015. Daniel = Columbia tenured, Moskowitz = Yale + AQR. Standard reference for momentum-crash-protection literature |
| R2 Mechanical | PASS | Two closed-form numbers per instrument per month: sign(r12) for direction, k=sigma_target/sigma_est for size. Zero discretion |
| R3 Data Available | PASS | DXZ universe supports 8-9 instruments (same as QM5_1126). Paper's original is equity-only cross-section but the vol-scaling rule ports cleanly to single-instrument TSMOM on FX/indices/commodities — Barroso-Santa-Clara explicitly extend this way |
| R4 ML Forbidden | PASS | Both formulas (12m return sign, 63-bar realized vol) are deterministic. **Watch for R4 borderline**: scaling-by-realized-vol is *constant-vol-target* (fixed sigma_target = 15%), not adaptive sigma_target. The target stays constant; only the position size adjusts. HR14 forbids parameters that change based on running PnL — this is not that. Documenting explicitly to make G0 R4 check unambiguous |

## Pipeline-Verlauf
- G0: 2026-05-17 — drafted from SSRN FEN batch 2 (autonomous wake), PENDING

## Verwandte Strategien
- Extends: QM5_1126 (moskowitz-tsmom-12m) — same TSMOM signal, this card
  adds the crash-protection vol-scaling layer. When both reach
  pipeline-end, P2 outputs will quantify whether vol-scaling is worth the
  complexity (paper claims yes; V5 confirms on own data)
- Adjacent: QM5_1127 (menkhoff-carry-fxvol-filter) — also uses realized-vol
  filter, but as **on/off gate** rather than continuous scaling. Different
  mechanism within the same vol-aware-position-sizing family

## Lessons Learned (während Pipeline-Lauf)
- *(populated as pipeline progresses)*

## Implementation Notes for Codex (P1)
- DWX symbol: **NDX.DWX primary** for P2 baseline (equity-momentum focus
  matches paper's original universe). Expand to GDAXI.DWX, WS30.DWX,
  UK100.DWX, EURUSD.DWX, XAUUSD.DWX in P3.
- Timeframe: D1.
- 12m signal: `Close[1d_ago] / Close[252_bars_ago] - 1`.
- Realized vol: `stdev(log_returns[1..63]) * sqrt(252)` (annualised).
- `k = min(1.0, 0.15 / sigma_est)` — capped at 1.0, floor at 0 (never short
  the signal direction; only scale down).
- Magic per symbol per HR4.
- P3 sweep variants: sigma_target 10% / 15% / 20%; vol-estimate window
  21d / 63d / 126d; `k` cap 1.0 vs 1.5 (allow modest scale-up?);
  intra-month vol-exit on/off.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung pipeline_phase aktualisieren + last_updated. Bei FAIL: pipeline_phase: DEAD + Lessons-Learned-Eintrag.*
