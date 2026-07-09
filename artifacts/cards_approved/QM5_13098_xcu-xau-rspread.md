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

Approved G0 summary: D1 `XCUUSD.DWX` / `XAUUSD.DWX` copper-gold
return-spread basket using fixed lookback returns, rolling z-score entry/exit,
ATR hard stops, max-hold exit, and broken-package repair. Source lineage is a
peer-reviewed 2024 copper-to-gold ratio paper plus State Street and CME market
references. Canonical card: `strategy-seeds/cards/xcu-xau-rspread_card.md`.

## Hypothesis

Extreme completed-D1 copper-minus-gold return spreads should partially
normalize because copper and gold are both metals while carrying different
cyclical versus defensive exposures.

## Rules

Run only on `XCUUSD.DWX` D1. Compute
`ln(XCU[t] / XCU[t-L]) - beta_xau * ln(XAU[t] / XAU[t-L])`, standardize over a
rolling window, short the spread above `strategy_entry_z`, long the spread
below `-strategy_entry_z`, close on `strategy_exit_z`, max hold, Friday close,
or broken-package detection, and apply ATR hard stops to both legs.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the logical basket
setfile `QM5_13098_XCU_XAU_RSPREAD_D1`. No live manifest, AutoTrading,
portfolio gate, external runtime data, grid, martingale, or ML is involved.
