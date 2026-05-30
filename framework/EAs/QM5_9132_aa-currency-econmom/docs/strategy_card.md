---
ea_id: QM5_9132
slug: aa-currency-econmom
type: strategy
source_id: ede348b4-0fa7-5be1-baa8-09e9089b67b7
sources:
  - "[[sources/alpha-architect-blog]]"
concepts:
  - "[[concepts/fundamental-momentum]]"
  - "[[concepts/currency-momentum]]"
indicators:
  - "[[indicators/economic-momentum]]"
  - "[[indicators/macro-trend]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 Alpha Architect URL cited; R2 fixed monthly macro ranking entry/exit; R3 portable to DWX FX pairs after macro data/lag handling; R4 fixed non-ML one-position-per-slot rules."
---

# Alpha Architect Currency Economic Momentum

## Quelle
- Source: [[sources/alpha-architect-blog]]
- Page / Timestamp: Larry Swedroe, "Fundamental Momentum, the Carry Trade, and Currency Returns", 2020-07-23, https://alphaarchitect.com/fundamental-momentum-the-carry-trade-and-currency-returns/

## Mechanik

The source summarizes Dahlquist and Hasseltoft's economic-momentum currency rule: currencies with stronger past macroeconomic trends outperform currencies with weaker macro trends. This card drafts a deterministic monthly long/short currency basket.

### Target Symbols / Period
- Target symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, USDCHF.DWX, NZDUSD.DWX.
- Period: MN1 signal refresh with D1 execution/ATR risk controls.

### Entry
- Monthly rebalance after country macro releases are finalized for the signal month.
- Universe: developed-market currencies that can be mapped to DWX FX pairs.
- For each country, compute trailing 36-month to 60-month standardized trends in the source's five macro variables: industrial production, retail sales, unemployment, consumer prices, and producer prices.
- Invert unemployment so a stronger labor trend receives a higher score.
- Average z-scored macro trends into `ECON_MOM`.
- Rank currencies by `ECON_MOM`.
- Open long basket in the strongest tercile.
- Open short basket in the weakest tercile.

### Exit
- Close names that leave their active tercile at the next monthly rebalance.
- Re-form long and short baskets monthly after signal refresh.

### Stop Loss
- Source has no stop.
- Build default: 2.5 x ATR(20,D1) per FX leg, plus V5 portfolio kill rules.

### Position Sizing
- Equal notional per active currency leg.
- P2-baseline: `RISK_FIXED = 1000` distributed across active slots.
- T6-live: `RISK_PERCENT = 0.5` distributed across active slots.

### Zusätzliche Filter
- One position per symbol/magic slot.
- Require approved macro data with release-lag handling; do not use revised values unavailable at the trade date.
- Skip currencies whose macro panel has missing values after lag alignment.

## Concepts (was ist das für eine Strategie)
- [[concepts/fundamental-momentum]] - primary
- [[concepts/currency-momentum]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full Alpha Architect URL with named author Larry Swedroe and named JFE paper. |
| R2 Mechanical | PASS | Fixed macro variables, fixed trend windows, monthly ranking, and deterministic long/short baskets. |
| R3 Data Available | UNKNOWN | DWX FX pairs are available, but the rule requires point-in-time macro data and currency-basket mapping. |
| R4 ML Forbidden | PASS | Fixed scoring formula; no ML, online learning, adaptive parameters, grid, or martingale. |

## Pipeline-Verlauf
- G0: PENDING (Batch 19 draft 2026-05-19)
- P1: -
- P2: -

## Verwandte Strategien
- [[strategies/QM5_1538_aa-tsmom-1-3-12]] - related currency time-series momentum.
- [[strategies/QM5_9131_aa-good-carry]] - related currency carry/fundamental signal.

## Lessons Learned (während Pipeline-Lauf)
- TBD

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
