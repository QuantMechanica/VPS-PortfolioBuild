---
copy_of: strategy-seeds/cards/rigcount-fri-mom_card.md
ea_id: QM5_12858
slug: rigcount-fri-mom
type: strategy
strategy_id: BAKERHUGHES-RIGCOUNT-FRI-MOM-2026
source_id: BAKERHUGHES-RIGCOUNT-2026
target_symbols: [XTIUSD.DWX]
logical_symbol: QM5_12858_XTI_RIGCOUNT_FRI_MOM_D1
period: D1
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-01
---

# Baker Hughes Rig-Count Friday Momentum

Canonical card: `strategy-seeds/cards/rigcount-fri-mom_card.md`.

Approved G0 summary: D1 `XTIUSD.DWX` continuation after a large final
broker-week displacement around the weekly Baker Hughes North America Rig Count
release. The EA uses the last completed workday D1 bar as the market reaction
proxy, then enters in the same direction on the first new-week D1 bar.

This is explicitly non-duplicate versus WTI static weekday/month calendar
anomalies, weekend-gap rules, WPSR/Cushing/refinery/hurricane/OPEC/SPR/expiry/
ETF-roll/seasonality rules, XTI/XNG baskets, XAU/XAG or metal-ratio sleeves,
and `QM5_12567` RSI commodity logic.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the single symbol
`XTIUSD.DWX`. No live manifest, AutoTrading, portfolio gate, external runtime
data, grid, martingale, or ML is involved.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-01 | initial Baker Hughes rig-count Friday momentum build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | `strategy-seeds/cards/rigcount-fri-mom_card.md` |
| Q01 Build Validation | 2026-07-01 | TBD | `artifacts/qm5_12858_build_result.json` |
| Q02 Baseline Screening | 2026-07-01 | QUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` |
