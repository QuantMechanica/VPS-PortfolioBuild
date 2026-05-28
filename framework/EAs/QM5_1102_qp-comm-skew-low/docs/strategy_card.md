---
ea_id: QM5_1102
slug: qp-comm-skew-low
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
sources:
  - "[[sources/quantpedia-encyclopedia]]"
concepts:
  - "[[concepts/commodity-skewness]]"
  - "[[concepts/cross-sectional-ranking]]"
indicators:
  - "[[indicators/rolling-return-skewness]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "Quantpedia Fernandez-Perez/Frijns/Fuertes/Miffre 2018 commodity-skewness low-minus-high R1-R4 PASS: R1 verifiable Quantpedia URL + named JBF 2018 paper; R2 deterministic 252-bar third-moment rank + monthly rebalance; R3 4 DWX commodities (XAUUSD/XAGUSD/XTIUSD/XNGUSD) enable top/bottom-2 cross-sectio"
---

# Quantpedia Commodity Skewness - Low Minus High

## Quelle
- Source: [[sources/quantpedia-encyclopedia]] - Quantpedia "Skewness Effect in Commodities"
- URL: https://quantpedia.com/strategies/skewness-effect-in-commodities
- Named source authors: Fernandez-Perez, Frijns, Fuertes, and Miffre, "The Skewness of Commodity Futures Returns", Journal of Banking & Finance 2018, URL: https://doi.org/10.1016/j.jbankfin.2017.10.001 (SSRN preprint 2015).

## Mechanik

### Entry
At each month-end:
1. Universe: available Darwinex commodity/metal/oil CFDs, candidate set `XAUUSD.DWX`, `XAGUSD.DWX`, `XTIUSD.DWX`, `XBRUSD.DWX`, `COPPER.DWX`, `NATGAS.DWX` if present.
2. For each symbol, compute daily log returns over the prior 252 D1 bars.
3. Compute total skewness as the third standardized moment of those returns.
4. Rank symbols ascending by skewness.
5. Open LONG positions in the lowest-skewness quintile or bottom 2 symbols.
6. Open SHORT positions in the highest-skewness quintile or top 2 symbols.

### Exit
- Close and rebalance all positions at the next month-end.
- Close any symbol that leaves its assigned skewness bucket at rebalance.

### Stop Loss
- ATR(20) hard stop at 5.0x D1 ATR from entry.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per active slot.
- Live: `RISK_PERCENT = 0.25` per slot.

### Zusaetzliche Filter
- Monthly-rebalance only.
- Require at least 270 D1 bars before a symbol is rank-eligible.
- Skip if absolute skewness calculation is unstable because fewer than 200 non-zero-return observations exist.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/commodity-skewness]] - primary
- [[concepts/cross-sectional-ranking]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Quantpedia URL is verifiable and names Fernandez-Perez, Frijns, Fuertes, and Miffre. |
| R2 Mechanical | UNKNOWN | Rolling skewness, rank buckets, monthly rebalance, and exits are deterministic. |
| R3 Data Available | UNKNOWN | Quantpedia lists CFDs, but DWX commodity breadth and symbol names need confirmation. |
| R4 ML Forbidden | UNKNOWN | Fixed moment/rank rule, no ML, no adaptive parameters, one position per magic slot. |

## R3 - T6 Live-Promotion-Caveat
N/A if implemented only on broker-routable commodity CFDs.

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1103_qp-comm-ie-low]] - related commodity lottery/asymmetry family, but uses IE tail-count asymmetry rather than third moment.

## Lessons Learned (waehrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
