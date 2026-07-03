---
copy_of: strategy-seeds/cards/xng-rig-fri-mom_card.md
ea_id: QM5_12997
slug: xng-rig-fri-mom
type: strategy
strategy_id: BAKERHUGHES-XNG-RIGCOUNT-FRI-MOM-2026
source_id: BAKERHUGHES-RIGCOUNT-2026
target_symbols: [XNGUSD.DWX]
logical_symbol: QM5_12997_XNG_RIGCOUNT_FRI_MOM_D1
period: D1
expected_trade_frequency: "D1 natural-gas last-workday rig-count displacement continuation; estimate 6-16 trades/year."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-03
---

# Baker Hughes XNG Rig-Count Friday Momentum

Canonical card: `strategy-seeds/cards/xng-rig-fri-mom_card.md`.

Approved G0 summary: D1 `XNGUSD.DWX` continuation after a large final
broker-week displacement around the weekly Baker Hughes North America Rig Count
release cadence. The EA uses the last completed workday D1 bar as the natural
gas market reaction proxy, then enters in the same direction on the first
new-week D1 bar.

This is explicitly non-duplicate versus WTI rig-count cards, XNG storage,
freeze, hurricane, LNG, month, weekday, weekend, basket, metal-ratio, and
`QM5_12567` RSI commodity logic.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the single symbol
`XNGUSD.DWX`. No live manifest, AutoTrading, portfolio gate, external runtime
data, grid, martingale, or ML is involved.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-03 | initial Baker Hughes XNG rig-count Friday momentum build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-03 | APPROVED | `strategy-seeds/cards/xng-rig-fri-mom_card.md` |
| Q01 Build Validation | 2026-07-03 | PASS | `artifacts/qm5_12997_build_result.json` |
| Q02 Baseline Screening | 2026-07-03 | QUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` work item `26ed76db-8424-4424-acf3-0a156e460658` |
