---
ea_id: QM5_1074
slug: as-daa-canary
type: strategy
source_id: 2df06de7-6a3a-5b06-9e6d-446d1a01fab9
sources:
  - "[[sources/allocate-smartly-strategies]]"
concepts:
  - "[[concepts/canary-momentum]]"
  - "[[concepts/tactical-asset-allocation]]"
indicators:
  - "[[indicators/weighted-momentum-score]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
card_body_incomplete: true
card_body_missing: "source_citation"
g0_approval_reasoning: "AS Keller/Keuning DAA canary (2018 SSRN) — R1 Allocate Smartly + SSRN paper attributed; R2 canary count + ranked momentum allocation deterministic; R3 SP500/NDX/WS30 + GER40 + XAUUSD testable, canary/bond legs need DWX proxy decision but ≥1 instrument testable; R4 fixed formula no ML"
---

# Allocate Smartly Defensive Asset Allocation

## Quelle
- Source: [[sources/allocate-smartly-strategies]]
- Catalogue entry: Allocate Smartly "List of Strategies", line listing "Defensive Asset Allocation" by Dr. Wouter Keller and JW Keuning, https://allocatesmartly.com/list-of-strategies/
- Paper reference: Keller and Keuning (2018), "Breadth Momentum and the Canary Universe: Defensive Asset Allocation", SSRN URL https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3212862
- Public rule summary: PortfolioDB DAA page, https://portfoliodb.co/portfolios/defensive-asset-allocation

## Mechanik

### Entry
- Timeframe: D1 (monthly canary momentum check evaluated on the D1 close of the last trading day of the month).

Monthly close evaluation:
- Risky universe per public summaries: broad global equities, REITs, commodities, gold, long and credit bonds.
- Protective universe: short/intermediate/credit bond ETFs.
- Canary universe: EEM and AGG in the common published DAA implementation.
- Compute weighted momentum score:
  `12 * (p0 / p1 - 1) + 4 * (p0 / p3 - 1) + 2 * (p0 / p6 - 1) + (p0 / p12 - 1)`.
- Count canary assets with negative momentum score: `n`.
- If `n = 0`, allocate 100% equally to the top 6 risky assets by momentum score.
- If `n = 1`, allocate 50% equally to the top 6 risky assets and 50% to the best protective asset.
- If `n = 2`, allocate 100% to the best protective asset.

DWX port:
- For G0/P1 feasibility, test a reduced CFD universe: SP500.DWX/NDX.DWX/WS30.DWX, GER40.DWX, XAUUSD.DWX, oil/commodity proxy if available.
- Canary proxies need explicit approval. Candidate approximation: broad risk canary = SP500.DWX or NDX.DWX plus defensive/rates proxy = flat/cash; mark unresolved for G0 reviewer.

### Exit
- Rebalance monthly.
- Exit sleeves whose rank drops out of the selected top set or whose canary regime allocation changes.

### Stop Loss
- Source uses monthly canary risk-off allocation, not intramonth stop.
- Framework catastrophic stop only if required.

### Position Sizing
- Original: equal-weight top 6 risky sleeves plus defensive sleeve allocation based on canary count.
- DWX implementation must use explicit slot allocation per selected sleeve or a reduced single-winner port.

### Zusätzliche Filter
- Month-end only.
- Framework spread/news filters.

## Concepts (was ist das für eine Strategie)
- [[concepts/canary-momentum]] - primary
- [[concepts/tactical-asset-allocation]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Allocate Smartly catalogue lists DAA and authors; SSRN paper and PortfolioDB implementation summary are linked. |
| R2 Mechanical | PASS | Canary count, ranked momentum, and allocation fractions are deterministic. |
| R3 Data Available | UNKNOWN | Several risky proxies are DWX-testable; canary/protective bond ETF proxies need a deterministic porting decision. |
| R4 ML Forbidden | PASS | Fixed formula and fixed monthly rebalance; no ML or adaptive online parameters. Multi-sleeve version needs explicit magic-slot allocation. |

## R3
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-16, PENDING, drafted from Allocate Smartly catalogue batch.

## Verwandte Strategien
- [[strategies/QM5_1073_as-vaa-breadth]] - VAA uses the offensive universe itself as breadth trigger.

## Lessons Learned (während Pipeline-Lauf)
- TBD

