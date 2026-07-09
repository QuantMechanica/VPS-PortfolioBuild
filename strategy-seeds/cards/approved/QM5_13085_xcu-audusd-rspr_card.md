---
copy_of: strategy-seeds/cards/xcu-audusd-rspr_card.md
ea_id: QM5_13085
slug: xcu-audusd-rspr
type: strategy
strategy_id: RBA-CME-XCU-AUDUSD-RSPREAD-2026
source_id: RBA-CME-XCU-AUDUSD-RSPREAD-2026
target_symbols: [XCUUSD.DWX, AUDUSD.DWX]
basket_symbols: [XCUUSD.DWX, AUDUSD.DWX]
logical_symbol: QM5_13085_XCU_AUDUSD_RSPREAD_D1
period: D1
expected_trade_frequency: "D1 XCU/AUDUSD commodity-FX return-spread z-score reversion; estimate 6-12 paired packages/year."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
---

# QM5_13085 XCU/AUDUSD Return-Spread Reversion

Canonical card: `strategy-seeds/cards/xcu-audusd-rspr_card.md`.

Approved G0 summary: D1 `XCUUSD.DWX` / `AUDUSD.DWX` commodity-FX
return-spread basket using fixed lookback returns, rolling z-score entry/exit,
ATR hard stops, max-hold exit, and broken-package repair. Source lineage is the
RBA AUD exchange-rate driver explainer plus official CME/USGS copper references.

This is explicitly non-duplicate: it is not solo copper trend or reversal, not
WTI/AUDUSD or any other WTI/AUD/CAD basket, not XNG/AUD, not XAU/XAG, not
oil/metals, and not commodity-RSI logic.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the logical basket
setfile `QM5_13085_XCU_AUDUSD_RSPREAD_D1`. No live manifest, AutoTrading,
portfolio gate, external runtime data, grid, martingale, or ML is involved.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-09 | initial XCU/AUDUSD basket build | Q01 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-09 | APPROVED | `strategy-seeds/cards/xcu-audusd-rspr_card.md` |
| Q01 Build Validation | TBD | TBD | TBD |
| Q02 Baseline Screening | TBD | TBD | enqueue after compile |
