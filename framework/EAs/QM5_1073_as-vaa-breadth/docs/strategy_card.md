---
ea_id: QM5_1073
slug: as-vaa-breadth
type: strategy
source_id: 2df06de7-6a3a-5b06-9e6d-446d1a01fab9
sources:
  - "[[sources/allocate-smartly-strategies]]"
concepts:
  - "[[concepts/breadth-momentum]]"
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
g0_approval_reasoning: "AS Keller/Keuning VAA (2017 SSRN) - R1 Allocate Smartly + SSRN paper attributed; R2 weighted 1/3/6/12-mo score + breadth trigger deterministic; R3 SP500/NDX/WS30 + GER40 + XAUUSD testable, bond/EM legs flat/cash; R4 fixed formula no ML"
---

# Allocate Smartly Vigilant Asset Allocation

## Quelle
- Source: [[sources/allocate-smartly-strategies]]
- Catalogue entry: Allocate Smartly "List of Strategies", lines listing "Vigilant Asset Allocation - Aggressive" and "Vigilant Asset Allocation - Balanced" by Dr. Wouter Keller and JW Keuning, https://allocatesmartly.com/list-of-strategies/
- Rule reference: Allocate Smartly VAA test article (2017), URL https://allocatesmartly.com/vigilant-asset-allocation-dr-wouter-keller-jw-keuning/
- Paper reference: Keller and Keuning (2017), "Breadth Momentum and Vigilant Asset Allocation", SSRN id 3002624.

## Mechanik

### Entry
- Timeframe: D1 (weighted momentum score evaluated on the D1 close of the last trading day of the month).

At the close of the last trading day of each month:
- Offensive universe in source article: SPY, EFA, EEM, AGG.
- Defensive universe in source article: LQD, IEF, SHY.
- Compute momentum score for every offensive and defensive asset:
  `12 * (p0 / p1 - 1) + 4 * (p0 / p3 - 1) + 2 * (p0 / p6 - 1) + (p0 / p12 - 1)`.
- If all offensive assets have positive scores, select the offensive asset with the highest score and allocate 100%.
- If any offensive asset has a negative score, select the defensive asset with the highest score and allocate 100%.

DWX port:
- Offensive proxies: SP500.DWX / NDX.DWX / WS30.DWX for US equity, GER40.DWX or EU index proxy for foreign equity, optional emerging-market proxy unavailable unless approved, AGG leg defaults to flat/cash or approved defensive proxy.
- Defensive proxies: flat/cash default; XAUUSD or other crisis proxy only if Development/CEO accepts the substitution.

### Exit
- Hold selected asset until the next month-end.
- Exit and rotate when a different offensive/defensive winner is selected or risk regime changes.

### Stop Loss
- Source uses monthly regime rotation rather than intramonth stop.
- Framework risk stop only if required.

### Position Sizing
- 100% to one selected asset in the tested VAA version.
- Compatible with one-position-per-magic after proxy selection.

### Zusaetzliche Filter
- Month-end only.
- Framework spread/news filters.

## Concepts
- [[concepts/breadth-momentum]] - primary
- [[concepts/tactical-asset-allocation]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | Allocate Smartly catalogue and detailed Allocate Smartly VAA article provide named authors and URL. |
| R2 Mechanical | PASS | Weighted 1/3/6/12-month score and positive/negative breadth trigger are deterministic. |
| R3 Data Available | UNKNOWN | Core ETF universe requires DWX proxy mapping; US index components are testable, bond/EM legs are unresolved. |
| R4 ML Forbidden | PASS | Fixed monthly formula, no ML, no online adaptation, single selected holding. |

## R3
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-16, PENDING, drafted from Allocate Smartly catalogue batch.

## Verwandte Strategien
- [[strategies/QM5_1074_as-daa-canary]] - DAA separates crash canaries from offensive asset selection.

## Lessons Learned
- TBD
