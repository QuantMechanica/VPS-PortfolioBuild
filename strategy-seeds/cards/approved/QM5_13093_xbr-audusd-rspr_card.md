---
copy_of: strategy-seeds/cards/xbr-audusd-rspr_card.md
ea_id: QM5_13093
slug: xbr-audusd-rspr
type: strategy
strategy_id: EIA-RBA-XBR-AUDUSD-2026
source_id: EIA-RBA-XBR-AUDUSD-2026
target_symbols: [XBRUSD.DWX, AUDUSD.DWX]
basket_symbols: [XBRUSD.DWX, AUDUSD.DWX]
logical_symbol: QM5_13093_XBR_AUDUSD_RSPREAD_D1
period: D1
expected_trade_frequency: "D1 XBR/AUDUSD commodity-FX return-spread z-score reversion; estimate 6-12 paired packages/year."
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

# QM5_13093 XBR/AUDUSD Return-Spread Reversion

Canonical card: `strategy-seeds/cards/xbr-audusd-rspr_card.md`.

Approved G0 summary: D1 `XBRUSD.DWX` / `AUDUSD.DWX` commodity-FX
return-spread basket using fixed lookback returns, rolling z-score entry/exit,
ATR hard stops, max-hold exit, and broken-package repair. Source lineage is the
EIA oil/exchange-rate working paper, RBA AUD exchange-rate driver explainer,
and EIA Brent spot-price context.

This is explicitly non-duplicate: it is not `QM5_13073` WTI/AUDUSD, not any
Brent/CAD-cross basket, not XBR/XNG, not XTI/XNG, not XAU/XAG, not XNG-only,
not an index sleeve, and not commodity-RSI logic.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the logical basket
setfile `QM5_13093_XBR_AUDUSD_RSPREAD_D1`. No live manifest, AutoTrading,
portfolio gate, external runtime data, grid, martingale, or ML is involved.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-09 | initial XBR/AUDUSD basket build | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-09 | APPROVED | `strategy-seeds/cards/xbr-audusd-rspr_card.md` |
