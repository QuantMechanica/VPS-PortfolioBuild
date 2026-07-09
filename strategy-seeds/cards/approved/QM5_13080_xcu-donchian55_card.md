---
copy_of: strategy-seeds/cards/xcu-donchian55_card.md
ea_id: QM5_13080
slug: xcu-donchian55
type: strategy
strategy_id: SZAKMARY-CME-USGS-XCU-TREND-2026
source_id: SZAKMARY-CME-USGS-XCU-TREND-2026
target_symbols: [XCUUSD.DWX]
logical_symbol: QM5_13080_XCU_DONCHIAN55_D1
period: D1
expected_trade_frequency: "D1 XCUUSD 55-period Donchian close-channel breakout with ADX regime filter; estimate 10-20 trades/year."
expected_trades_per_year_per_symbol: 14
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
---

# QM5_13080 XCU Donchian-55 Trend

Canonical card: `strategy-seeds/cards/xcu-donchian55_card.md`.

Approved G0 summary: D1 `XCUUSD.DWX` Donchian-55 close-channel breakout with
ADX trend-regime confirmation, ATR hard stop, contra-channel exit, and
max-hold exit. Source lineage is peer-reviewed commodity trend-following
research plus official CME/USGS copper references.

This is explicitly non-duplicate: the repo has no existing XCU card or EA, and
the logic is not XAU/XAG ratio, XTI, XNG, Brent, index, commodity-RSI, or any
market-neutral spread package.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the single symbol
`XCUUSD.DWX`. No live manifest, AutoTrading, portfolio gate, external runtime
data, grid, martingale, or ML is involved.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-09 | initial XCU Donchian-55 build | Q01 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-09 | APPROVED | `strategy-seeds/cards/xcu-donchian55_card.md` |
| Q01 Build Validation | TBD | TBD | TBD |
| Q02 Baseline Screening | TBD | TBD | enqueue after compile |

