---
ea_id: QM5_1113
slug: qp-country-cape-value
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
sources:
  - "[[sources/quantpedia-encyclopedia]]"
concepts:
  - "[[concepts/value-factor]]"
  - "[[concepts/country-selection]]"
indicators:
  - "[[indicators/cape-ratio-rank]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "Quantpedia country-CAPE value (Faber 2012 SSRN + Klement 2012 SSRN + Zaremba 2015 IAJ): R1 verifiable Quantpedia URL + multiple SSRN/DOI citations; R2 yearly CAPE rank + threshold (<15) + equal-weight cheapest-tertile deterministic IF CAPE CSV provided — flag for Codex to stub deterministic country-"
---

# Quantpedia Country CAPE Value

## Quelle
- Source: [[sources/quantpedia-encyclopedia]] - Quantpedia "Value Factor - CAPE Effect within Countries"
- URL: https://quantpedia.com/strategies/value-factor-effect-within-countries
- Named source authors: Mebane Faber 2012, "Global Value: Building Trading Models with the 10 Year CAPE", SSRN, https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2129474; Klement 2012, "Does the Shiller-PE Work in Emerging Markets?", SSRN, https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2088140; Zaremba 2015, "Country selection strategies based on value, size and momentum", Investment Analysts Journal, https://doi.org/10.1080/10293523.2015.1086702.

## Mechanik

### Entry
At the final trading day of each calendar year:
1. Universe: DWX broad equity-index CFDs mapped to countries with a deterministic external CAPE input table, candidate set `NDX.DWX`, `WS30.DWX`, `GER40.DWX`, `UK100.DWX`, `JPN225.DWX`, `AUS200.DWX`, plus `SP500.DWX` for backtest-only research if needed.
2. For each country/index, read the latest available country CAPE ratio from a versioned CSV input generated before the backtest starts.
3. Rank countries ascending by CAPE ratio.
4. Open LONG positions in the cheapest 33% of rank-eligible countries only if CAPE < 15.
5. Hold cash/no position for countries with CAPE >= 15.

### Exit
- Close and rebalance at the next yearly rebalance.
- Close a leg if its mapped country is removed from the deterministic CAPE input table.

### Stop Loss
- ATR(20) hard stop at 5.0x D1 ATR from entry.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per active slot.
- Live: `RISK_PERCENT = 0.25` per active slot.

### Zusaetzliche Filter
- Yearly rebalance only.
- Require the CAPE CSV to be versioned and timestamped before a run; no live web calls from the EA.
- Optional P3 sweep: CAPE threshold 12/15/18 and bucket size 25%/33%/50%.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/value-factor]] - primary
- [[concepts/country-selection]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Quantpedia URL is verifiable and names Mebane Faber plus supporting CAPE-country valuation papers. |
| R2 Mechanical | UNKNOWN | Yearly CAPE rank, CAPE threshold, and equal-weight selection are deterministic once the CAPE CSV exists. |
| R3 Data Available | UNKNOWN | Original ETF/country-index universe ports to DWX broad index CFDs, but requires deterministic external CAPE history. |
| R4 ML Forbidden | UNKNOWN | Fixed valuation rank/threshold rule; no ML, online learning, grid, or martingale. |

## R3 - T6 Live-Promotion-Caveat
If SP500.DWX is an active traded leg and the EA passes P0-P9 on SP500.DWX only, T6 deploy requires parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. If SP500.DWX is omitted and only live-routable index CFDs are traded, this caveat is N/A.

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1105_qp-country-reversal]] - related country-index contrarian family, but this card uses valuation rather than trailing return.
- [[strategies/QM5_1112_qp-country-momentum]] - same country-index universe, opposite factor family.

## Lessons Learned (waehrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
