---
ea_id: QM5_1227
slug: neely-fx-channel
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
sources:
  - "[[sources/ssrn-financial-economics-network]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/adaptive-markets]]"
indicators:
  - "[[indicators/channel-breakout]]"
  - "[[indicators/moving-average]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "Neely-Weller-Ulrich FRB-StLouis 2006-046B / JFQA Adaptive Markets Hypothesis (SSRN 922345 named-author URL + FRB working-paper lineage) FX 60D channel breakout R1-R4 all PASS: 60D HH/LL entry / SMA(60) midline exit / 2.5xATR(20) stop / 90D time stop deterministic, GP+Markov variants explicitly exclu"
---

# Neely-Weller-Ulrich FX Channel Rule

## Quelle
- Source: [[sources/ssrn-financial-economics-network]]
- URL: https://ssrn.com/abstract=922345
- Named source authors: Christopher J. Neely, Federal Reserve Bank of St. Louis; Paul A. Weller, University of Iowa; Joshua Ulrich, Wells Fargo Capital Markets, "The Adaptive Markets Hypothesis: Evidence from the Foreign Exchange Market" (FRB St. Louis Working Paper No. 2006-046B / JFQA version).
- Location: SSRN abstract reports true out-of-sample tests of previously published FX technical rules and notes that less-studied rules including channel rules declined less than filter and moving-average rules.

## Mechanik

### Entry
1. Trade `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`.
2. On D1 close, compute `upper = highest_high(60)[1]`, `lower = lowest_low(60)[1]`, and `mid = SMA(Close, 60)`.
3. If flat and `Close > upper`, open LONG at next D1 open.
4. If flat and `Close < lower`, open SHORT at next D1 open.

### Exit
- Close LONG when `Close < mid`.
- Close SHORT when `Close > mid`.
- Reverse only after a full D1 close beyond the opposite 60-day channel.

### Stop Loss
- Hard stop at `2.5 * ATR(D1, 20)`.
- Time stop after 90 D1 bars if neither midline exit nor stop has fired.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per active symbol, max 3 simultaneous symbols.
- Live: `RISK_PERCENT = 0.25`, max 3 simultaneous symbols.

### Zusätzliche Filter
- Require 120 D1 bars before first signal.
- P3 sweep: channel lookback `{40, 60, 100}`, exit midline `{SMA(40), SMA(60), SMA(100)}`.
- Genetic-programming and Markov-rule variants discussed by the source are explicitly excluded for R4 cleanliness.

## Concepts (was ist das für eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/adaptive-markets]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Verifiable SSRN URL with named authors and FRB/JFQA publication lineage. |
| R2 Mechanical | UNKNOWN | Channel breakout, midline exit, stop, time stop, and sweeps are deterministic. |
| R3 Data Available | UNKNOWN | Uses major DWX FX pairs only. |
| R4 ML Forbidden | UNKNOWN | Fixed channel rule only; source's genetic-programming and Markov variants are excluded. |

## Pipeline-Verlauf
- G0: 2026-05-18, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1224_white-okunev-fx-xmom]] - cross-sectional moving-average momentum rather than per-pair channel breakout.
- [[strategies/QM5_1217_zarattini-donchian-ensemble]] - multi-lookback Donchian ensemble on a broader basket.

## Lessons Learned (während Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`.*
