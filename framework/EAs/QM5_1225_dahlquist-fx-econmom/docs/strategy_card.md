---
ea_id: QM5_1225
slug: dahlquist-fx-econmom
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
sources:
  - "[[sources/ssrn-financial-economics-network]]"
concepts:
  - "[[concepts/fundamental-momentum]]"
  - "[[concepts/fx-risk-premia]]"
indicators:
  - "[[indicators/macro-data-table]]"
  - "[[indicators/cross-sectional-rank]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "R1 SSRN URL and named paper; R2 deterministic macro z-score ranks/rebalance/exits/stops; R3 trades DWX FX pairs with static macro CSV; R4 fixed rules, no ML/grid/martingale."
---

# Dahlquist-Hasseltoft Economic Momentum Currency Basket

## Quelle
- Source: [[sources/ssrn-financial-economics-network]]
- URL: https://ssrn.com/abstract=2579666
- Named source authors: Magnus Dahlquist, Stockholm School of Economics / Swedish House of Finance, and Henrik Hasseltoft, "Economic Momentum and Currency Returns" (Swedish House of Finance Research Paper No. 16-14, 2019 revision).
- Location: SSRN abstract states that past trends in economic activity and inflation predict currency returns, with a long-strong / short-weak economic-momentum currency strategy.

## Mechanik

### Entry
1. Trade a monthly DWX FX basket: `EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX`, `NZDUSD.DWX`, `USDCAD.DWX`, `USDCHF.DWX`, `USDJPY.DWX`.
2. Load a deterministic monthly macro CSV for the corresponding economies with columns `country, date, industrial_production_yoy, cpi_yoy`.
3. For each currency, compute `economic_momentum = zscore(change_6m(industrial_production_yoy)) + zscore(change_6m(cpi_yoy))`.
4. Rank currencies by economic momentum at month-end.
5. Go LONG the top-ranked currency versus USD and SHORT the bottom-ranked currency versus USD at the next month open.

### Exit
- Rebalance monthly when the macro table advances.
- Exit a leg if it leaves the top/bottom two ranks.
- Stay flat if the macro CSV is stale by more than 45 calendar days.

### Stop Loss
- Per leg hard stop at `3.0 * ATR(D1, 20)`.
- Monthly basket stop at `2R`.

### Position Sizing
- P2 baseline: `RISK_FIXED = 500` USD per leg, `1000` USD total basket risk.
- Live: `RISK_PERCENT = 0.125` per leg, max `0.25` total.

### Zusätzliche Filter
- Requires OWNER-provided monthly macro table before P1 build; no live web calls from EA.
- P3 sweep: macro lookback `{3, 6, 12}` months and top/bottom rank count `{1, 2}`.

## Concepts (was ist das für eine Strategie)
- [[concepts/fundamental-momentum]] - primary
- [[concepts/fx-risk-premia]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Verifiable SSRN URL with named authors and Swedish House of Finance working-paper attribution. |
| R2 Mechanical | UNKNOWN | Monthly macro table, z-scored 6-month changes, ranks, rebalance, and exits are deterministic. |
| R3 Data Available | UNKNOWN | Price execution uses DWX FX pairs; macro CSV is an external deterministic input requirement. |
| R4 ML Forbidden | UNKNOWN | Fixed formula on static macro data; no learning, adaptive PnL parameters, grid, or martingale. |

## Pipeline-Verlauf
- G0: 2026-05-18, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1224_white-okunev-fx-xmom]] - price-based FX cross-sectional momentum.
- [[strategies/QM5_1127_menkhoff-fx-carry-vol]] - carry risk premium with volatility filter.

## Lessons Learned (während Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`.*
