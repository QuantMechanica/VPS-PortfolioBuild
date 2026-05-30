---
ea_id: QM5_1257
slug: lemishko-fx-cointpair
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
sources:
  - "[[sources/ssrn-financial-economics-network]]"
concepts:
  - "[[concepts/pairs-trading]]"
  - "[[concepts/cointegration]]"
indicators:
  - "[[indicators/cointegration-test]]"
  - "[[indicators/z-score]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "SSRN Lemishko-Landi-Caicedo 2024 (abstract 4771108) R1-R4 PASS: named authors+SSRN URL, Engle-Granger coint + frozen monthly OLS hedge ratio (no online adaptation), 7-pair major FX DWX universe, no ML"
---

# Lemishko-Landi-Caicedo Forex Cointegration Pair

## Quelle
- Source: [[sources/ssrn-financial-economics-network]]
- Paper: Tetiana Lemishko, Alexandre Landi, Juliana Caicedo-Llano, "Cointegration-Based Strategies in Forex Pairs Trading", SSRN, posted 2024-04-15, revised 2024-12-18.
- URL: https://ssrn.com/abstract=4771108
- Location: SSRN abstract proposes applying cointegration-based pair trading to Forex markets and focuses on deviations from long-term equilibrium relationships.

## Mechanik

### Entry
- Monthly, evaluate candidate DWX FX pairs from the major FX universe: `EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX`, `NZDUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `USDCAD.DWX`.
- For each candidate pair-of-pairs, run an Engle-Granger cointegration test on the prior 252 daily closes.
- Keep only combinations with p-value <= 0.05 and positive spread half-life between 2 and 30 trading days.
- Estimate hedge ratio by ordinary least squares on the same 252-day window; freeze it until the next monthly selection.
- Compute spread z-score on H1 bars using a 60-bar rolling mean and standard deviation.
- Enter long spread when z-score <= -2.0: long underpriced leg, short overpriced leg by frozen hedge ratio.
- Enter short spread when z-score >= +2.0: short overpriced leg, long underpriced leg by frozen hedge ratio.

### Exit
- Close when spread z-score crosses 0.
- Time stop: close after 10 trading days.
- Structural stop: close immediately if daily z-score exceeds +/-3.5 against the position.

### Stop Loss
- Combined pair stop at 1.5R.
- If either leg cannot be priced or traded, close the other leg immediately.

### Position Sizing
- P2 baseline: fixed combined pair risk USD 1,000.
- Leg notionals follow frozen hedge ratio, capped so neither leg carries more than 70% of gross notional.

### Zusaetzliche Filter
- One active pair per magic number.
- Skip if pair spread cost exceeds 20% of the expected z-score reversion distance.
- Do not re-estimate hedge ratio intramonth; this avoids online parameter adaptation.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/pairs-trading]] - primary
- [[concepts/cointegration]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | Named authors and SSRN URL: Tetiana Lemishko, Alexandre Landi, Juliana Caicedo-Llano, https://ssrn.com/abstract=4771108. |
| R2 Mechanical | PASS | Fixed monthly cointegration screen, frozen hedge ratio, z-score entry and mean-reversion exit. |
| R3 Data Available | PASS | Uses only major DWX FX OHLC prices. |
| R4 ML Forbidden | PASS | Cointegration and OLS are deterministic statistical transforms; no ML, neural net, online learning, martingale, or adaptive intramonth parameter update. |

## Pipeline-Verlauf
- G0: 2026-05-18, PENDING.

## Verwandte Strategien
- [[strategies/QM5_1129_gatev-distance-pairs]] - distance-based pairs; this card uses cointegration and Forex pairs.
- [[strategies/QM5_1227_neely-fx-channel]] - FX technical trend-following, not pair mean reversion.

## Lessons Learned (waehrend Pipeline-Lauf)
- TBD

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
