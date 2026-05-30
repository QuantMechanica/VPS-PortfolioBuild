---
ea_id: QM5_1114
slug: qp-crossasset-valmom
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
sources:
  - "[[sources/quantpedia-encyclopedia]]"
concepts:
  - "[[concepts/value-momentum-combo]]"
  - "[[concepts/global-tactical-asset-allocation]]"
indicators:
  - "[[indicators/twelve-month-return-rank]]"
  - "[[indicators/one-month-return-rank]]"
  - "[[indicators/asset-class-yield-rank]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "R1 PASS Quantpedia URL and named papers; R2 PASS deterministic monthly value/momentum ranks and rebalance; R3 PASS port/test on DWX index/commodity CFDs with SP500 caveat; R4 PASS fixed rules no ML/grid/martingale."
---

# Quantpedia Cross-Asset Value Momentum Combo

## Quelle
- Source: [[sources/quantpedia-encyclopedia]] - Quantpedia "Value and Momentum Factors across Asset Classes"
- URL: https://quantpedia.com/strategies/value-and-momentum-factors-across-asset-classes
- Citation verified 2026: Quantpedia URL above; source article cites Blitz and van Vliet cross-asset allocation work.
- Named source authors: Blitz and van Vliet, "Global Tactical Cross-Asset Allocation: Applying Value and Momentum Across Asset Classes"; Quantpedia also cites Asness/Moskowitz/Pedersen, Wang, Bhansali et al., and Baz et al.

## Mechanik

### Entry
At each month-end:
1. Universe: DWX symbols mapped to broad asset-class proxies, candidate set `SP500.DWX`, `NDX.DWX`, `GER40.DWX`, `UK100.DWX`, `JPN225.DWX`, `XAUUSD.DWX`, `XAGUSD.DWX`, `XTIUSD.DWX`, and approved bond/rates proxies if available. If no bond proxies exist, run the index/commodity subset and flag R3 risk.
2. For each asset proxy, compute three ranks: 12-month price momentum, 1-month price momentum, and deterministic valuation/yield score from a versioned monthly CSV.
3. Composite score = 25% rank(12-month momentum) + 25% rank(1-month momentum) + 50% rank(value/yield).
4. Open LONG positions in the top quartile of composite scores.
5. Open SHORT positions in the bottom quartile of composite scores.

### Exit
- Close and rebalance at the next month-end.
- Close any leg that leaves its selected quartile at rebalance.

### Stop Loss
- ATR(20) hard stop at 5.0x D1 ATR from entry per leg.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per active slot.
- Live: `RISK_PERCENT = 0.25` per active slot.

### Zusaetzliche Filter
- Require at least 270 D1 bars for momentum eligibility.
- Require valuation/yield CSV to be versioned before the run; no EA web calls.
- Optional P3 sweep: long/short top-bottom quartile versus tercile, and value weight 40%/50%/60%.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/value-momentum-combo]] - primary
- [[concepts/global-tactical-asset-allocation]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Quantpedia URL is verifiable and names Blitz/van Vliet plus supporting cross-asset value/momentum papers. |
| R2 Mechanical | UNKNOWN | Composite rank, quartile selection, and monthly rebalance are deterministic once valuation inputs exist. |
| R3 Data Available | UNKNOWN | Price legs can port to DWX index/commodity CFDs, but bond/yield proxies and valuation CSV coverage need confirmation. |
| R4 ML Forbidden | UNKNOWN | Fixed linear rank weights and scheduled rebalances; no ML, online learning, grid, or martingale. |

## R3 - T6 Live-Promotion-Caveat
If SP500.DWX is an active traded leg and the EA passes P0-P9 on SP500.DWX only, T6 deploy requires parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. If SP500.DWX is omitted and only live-routable index/commodity CFDs are traded, this caveat is N/A.

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1056_moskowitz-tsmom-multiasset]] - related multi-asset momentum, but this card combines 12m momentum, 1m momentum, and valuation/yield ranks.
- [[strategies/QM5_1113_qp-country-cape-value]] - related value-factor card with narrower country-index scope.

## Lessons Learned (waehrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
