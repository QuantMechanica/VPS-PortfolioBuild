---
copy_of: strategy-seeds/cards/xcu-4w-reversal_card.md
ea_id: QM5_13081
slug: xcu-4w-reversal
type: strategy
strategy_id: YANG-CME-USGS-XCU-REVERSAL-2026
source_id: YANG-CME-USGS-XCU-REVERSAL-2026
target_symbols: [XCUUSD.DWX]
logical_symbol: QM5_13081_XCU_4W_REVERSAL_D1
period: D1
expected_trade_frequency: "Weekly D1 XCUUSD.DWX 20-bar overreaction reversal gate; estimate 8-18 trades/year."
expected_trades_per_year_per_symbol: 12
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
---

# QM5_13081 XCU Four-Week Reversal

Canonical card: `strategy-seeds/cards/xcu-4w-reversal_card.md`.

Approved G0 summary: D1 `XCUUSD.DWX` weekly 20-bar overreaction reversal based
on commodity futures reversal lineage. It fades large four-week copper moves
with ATR hard-stop control and a 21-day max-hold exit.

This is explicitly non-duplicate: it is not the existing `QM5_13080`
XCU Donchian trend card, not XAU/XAG, XTI, XNG, Brent, index, commodity-RSI, or
any market-neutral spread package.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the single symbol
`XCUUSD.DWX`. No live manifest, AutoTrading, portfolio gate, external runtime
data, grid, martingale, or ML is involved.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-09 | initial XCU 4-week reversal build | Q01 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-09 | APPROVED | `strategy-seeds/cards/xcu-4w-reversal_card.md` |
| Q01 Build Validation | TBD | TBD | TBD |
| Q02 Baseline Screening | TBD | TBD | enqueue after compile |

