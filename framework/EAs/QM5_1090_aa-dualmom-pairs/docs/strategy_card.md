---
ea_id: QM5_1090
slug: aa-dualmom-pairs
type: strategy
source_id: ede348b4-0fa7-5be1-baa8-09e9089b67b7
sources:
  - "[[sources/alpha-architect-blog]]"
concepts:
  - "[[concepts/dual-momentum]]"
  - "[[concepts/relative-momentum]]"
  - "[[concepts/time-series-momentum]]"
indicators:
  - "[[indicators/twelve-month-relative-momentum]]"
  - "[[indicators/twelve-month-time-series-momentum]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-17
g0_approval_reasoning: "R1 URL to Alpha Architect source; R2 deterministic monthly relative plus absolute momentum entry-exit; R3 portable to DWX CFD pairs incl SP500.DWX with T6 caveat; R4 fixed rules, no ML/martingale/adaptive parameters."
expected_trades_per_year_per_symbol: 12
---

# Alpha Architect Pairwise Dual Momentum

## Quelle
- Source: [[sources/alpha-architect-blog]]
- Page / Timestamp: Wesley Gray, PhD, "A Tactical Asset Allocation Horserace Between Two Thoroughbreds", 2015-02-13, https://alphaarchitect.com/asset-allocation-horserace-robust-asset-allocation-raa-vs-dual-momentum/

## Mechanik

### Entry
Monthly at the close for each configured asset pair:
- Compute each asset's 12-month total return.
- Select the asset in the pair with the higher 12-month relative performance.
- For the selected asset, compute 12-month excess return versus T-bill/cash.
- If the selected asset's excess return is positive, go long that selected asset.
- If the selected asset's excess return is not positive, hold cash instead of either risky asset.

### Exit
- Rebalance monthly.
- Exit the current asset if it is no longer the pair's relative winner.
- Exit to cash if the selected winner fails the 12-month excess-return gate.

### Stop Loss
- Source relies on monthly dual-momentum exits, not explicit stops.
- Build default: ATR stop and V5 portfolio risk guard.

### Position Sizing
- Equal allocation per active pair sleeve.
- P2 baseline uses Fixed Risk $1,000 per V5 convention.

### Zusätzliche Filter
- Monthly rebalance only.
- Require 12 monthly bars for both pair assets before first signal.
- Use cash/zero proxy while out of risk assets.

## Concepts (was ist das für eine Strategie)
- [[concepts/dual-momentum]] — primary
- [[concepts/relative-momentum]] — secondary
- [[concepts/time-series-momentum]] — secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full URL, named author Wesley Gray, PhD, dated Alpha Architect post, with Gary Antonacci dual momentum citation. |
| R2 Mechanical | PASS | Explicit relative momentum selection plus 12-month absolute momentum cash gate. |
| R3 Data Available | PASS | Pair logic is directly portable to DWX index, commodity, metal, and FX CFD pairs. |
| R4 ML Forbidden | PASS | Fixed ranking and monthly rebalance; no ML, online learning, martingale, or adaptive parameters. |

## R3
Suggested DWX pairs: `SP500.DWX`/`GDAXI.DWX`, `NDX.DWX`/`WS30.DWX`, `XAUUSD.DWX`/`XTIUSD.DWX`, `EURUSD.DWX`/`USDJPY.DWX`.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, extracted by Research from Alpha Architect blog.

## Verwandte Strategien
- [[strategies/QM5_1089_aa-raa-robust-pairs]] — same Alpha Architect comparison article, but robust TMOM/MA timing instead of dual momentum.

## Lessons Learned (während Pipeline-Lauf)
- TBD

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
