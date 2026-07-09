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
status: APPROVED
pipeline_phase: Q02
last_updated: 2026-07-09
---

# QM5_13098 XCU/XAU Return-Spread Reversion

Canonical card: `strategy-seeds/cards/xcu-xau-rspread_card.md`.

This EA implements a D1 `XCUUSD.DWX` / `XAUUSD.DWX` copper-gold return-spread
reversion basket. It uses fixed lookback returns, rolling z-score entry/exit,
ATR hard stops, max-hold exit, spread caps, and deterministic broken-package
repair. Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`.

