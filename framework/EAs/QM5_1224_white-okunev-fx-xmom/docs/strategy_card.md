---
ea_id: QM5_1224
slug: white-okunev-fx-xmom
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
sources:
  - "[[sources/ssrn-financial-economics-network]]"
concepts:
  - "[[concepts/cross-sectional-momentum]]"
  - "[[concepts/fx-risk-premia]]"
indicators:
  - "[[indicators/moving-average]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "R1 SSRN URL and named paper; R2 deterministic MA rank/rebalance/exits/stops; R3 DWX major FX basket; R4 fixed rules, no ML/grid/martingale."
---

# White-Okunev FX Cross-Sectional Moving-Average Momentum

## Quelle
- Source: [[sources/ssrn-financial-economics-network]]
- URL: https://ssrn.com/abstract=264574
- Named source authors: Derek R. White, UNSW Australia Business School, and John Okunev, Bond University Business School, "Do Momentum Based Strategies Still Work in Foreign Currency Markets?" (2001).
- Location: SSRN abstract describes a long/short strategy that buys the most attractive currency and shorts the least attractive currency, tested across 354 long/short moving-average rules over eight currencies.

## Mechanik

### Entry
1. Use a DWX USD-cross basket: `EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX`, `NZDUSD.DWX`, `USDCAD.DWX`, `USDCHF.DWX`, `USDJPY.DWX`.
2. On each D1 close, convert each pair into a USD-normalized currency score where positive means the non-USD currency is strong versus USD.
3. For each currency, compute `score = Close / SMA(Close, 120) - 1` after sign-adjusting inverse USD quote pairs.
4. Rank currencies by `score`.
5. Go LONG the strongest currency versus USD and SHORT the weakest currency versus USD at next D1 open, using the corresponding tradable DWX pair direction.

### Exit
- Rebalance monthly on the first trading day.
- Exit a leg if its currency leaves the top/bottom two ranks.
- Close both legs if fewer than five basket symbols have valid 160-bar history.

### Stop Loss
- Per leg hard stop at `3.0 * ATR(D1, 20)`.
- Basket kill for the month if combined open loss reaches `2R`.

### Position Sizing
- P2 baseline: `RISK_FIXED = 500` USD per leg, `1000` USD total basket risk.
- Live: `RISK_PERCENT = 0.125` per leg, max `0.25` total.

### Zusätzliche Filter
- Monthly rebalance only; no intramonth re-optimization.
- P3 sweep: SMA lookbacks `{60, 120, 180, 240}` and rebalance cadence `{weekly, monthly}`.

## Concepts (was ist das für eine Strategie)
- [[concepts/cross-sectional-momentum]] - primary
- [[concepts/fx-risk-premia]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Verifiable SSRN URL with named academic authors and institutional affiliations. |
| R2 Mechanical | UNKNOWN | Currency ranking, moving-average score, monthly rebalance, exits, and stops are deterministic. |
| R3 Data Available | UNKNOWN | Uses major DWX FX pairs only; source eight-currency universe ports directly to available USD crosses. |
| R4 ML Forbidden | UNKNOWN | Fixed moving-average ranking; no ML, adaptive parameters, grid, or martingale. |

## Pipeline-Verlauf
- G0: 2026-05-18, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1126_mop-tsmom]] - time-series momentum per instrument rather than cross-sectional rank.
- [[strategies/QM5_1127_menkhoff-fx-carry-vol]] - FX carry with volatility filter, not price momentum.

## Lessons Learned (während Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`.*
