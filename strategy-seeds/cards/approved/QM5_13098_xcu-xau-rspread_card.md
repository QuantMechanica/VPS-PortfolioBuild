---
copy_of: strategy-seeds/cards/xcu-xau-rspread_card.md
ea_id: QM5_13098
slug: xcu-xau-rspread
type: strategy
strategy_id: PARNES-SSGA-COPPERGOLD-2026
source_id: PARNES-SSGA-COPPERGOLD-2026
target_symbols: [XCUUSD.DWX, XAUUSD.DWX]
basket_symbols: [XCUUSD.DWX, XAUUSD.DWX]
logical_symbol: QM5_13098_XCU_XAU_RSPREAD_D1
period: D1
expected_trade_frequency: "D1 XCU/XAU copper-gold return-spread z-score reversion; estimate 5-10 paired packages/year."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
---

# QM5_13098 XCU/XAU Return-Spread Reversion

Canonical card: `strategy-seeds/cards/xcu-xau-rspread_card.md`.

Approved G0 summary: D1 `XCUUSD.DWX` / `XAUUSD.DWX` copper-gold
return-spread basket using fixed lookback returns, rolling z-score entry/exit,
ATR hard stops, max-hold exit, and broken-package repair. Source lineage is a
peer-reviewed 2024 copper-to-gold ratio paper plus State Street and CME market
references.

This is explicitly non-duplicate: it is not solo copper trend or reversal, not
XCU/AUDUSD, not XTI/XCU, not XTI/XAU oil/gold, not XNG/XAU gas/gold, not
XAU/XAG gold/silver, and not commodity-RSI logic.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the logical basket
setfile `QM5_13098_XCU_XAU_RSPREAD_D1`. No live manifest, AutoTrading,
portfolio gate, external runtime data, grid, martingale, or ML is involved.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-09 | initial XCU/XAU basket build | Q02 | QUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-09 | APPROVED | `strategy-seeds/cards/xcu-xau-rspread_card.md` |
| Q01 Build Validation | 2026-07-09 | PENDING | `artifacts/qm5_13098_build_result.json` |
| Q02 Baseline Screening | 2026-07-09 | PENDING | `artifacts/qm5_13098_q02_enqueue_20260709.json` |

