---
copy_of: strategy-seeds/cards/xti-xcu-rspread_card.md
ea_id: QM5_13090
slug: xti-xcu-rspread
type: strategy
strategy_id: EIA-CME-USGS-XTI-XCU-RSPREAD-2026
source_id: EIA-CME-USGS-XTI-XCU-RSPREAD-2026
target_symbols: [XTIUSD.DWX, XCUUSD.DWX]
basket_symbols: [XTIUSD.DWX, XCUUSD.DWX]
logical_symbol: QM5_13090_XTI_XCU_RSPREAD_D1
period: D1
expected_trade_frequency: "D1 XTI/XCU commodity return-spread z-score reversion; estimate 6-14 paired packages/year."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
---

# QM5_13090 XTI/XCU Return-Spread Reversion

Canonical card: `strategy-seeds/cards/xti-xcu-rspread_card.md`.

Approved G0 summary: D1 `XTIUSD.DWX` / `XCUUSD.DWX` commodity return-spread
basket using fixed lookback returns, rolling z-score entry/exit, ATR hard
stops, max-hold exit, and broken-package repair. Source lineage is the EIA
crude-oil price driver explainer, official CME/USGS copper references, and Chan
pair-spread implementation lineage.

This is explicitly non-duplicate: it is not XTI/AUDUSD, XTI/AUDCAD, XTI/XNG,
oil/gold, oil/silver, solo copper trend/reversal, WTI event/calendar/inventory,
or commodity-RSI logic.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the logical basket
setfile `QM5_13090_XTI_XCU_RSPREAD_D1`. No live manifest, AutoTrading,
portfolio gate, external runtime data, grid, martingale, or ML is involved.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-09 | initial XTI/XCU basket build | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-09 | APPROVED | `strategy-seeds/cards/xti-xcu-rspread_card.md` |
| Q01 Build Validation | 2026-07-09 | PENDING | `artifacts/qm5_13090_build_result.json` |
| Q02 Baseline Screening | 2026-07-09 | PENDING | `artifacts/qm5_13090_q02_enqueue_20260709.json` |
