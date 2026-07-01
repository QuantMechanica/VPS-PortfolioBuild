---
copy_of: strategy-seeds/cards/williams18-xti_card.md
ea_id: QM5_12851
slug: williams18-xti
type: strategy
strategy_id: SRC03_S12_XTI_20260701
source_id: SRC03
source_citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading. Local SRC03 source packet."
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
single_symbol_only: true
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 two-bar Williams 18-MA continuation stop entry; estimate 8-18 completed packages/year after inside-day, spread, pending-expiry, ATR-stop, and max-hold filters."
expected_trades_per_year_per_symbol: 12
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-01
expected_pf: 1.08
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
---

# Williams 18-Bar Two-Bar MA WTI

Canonical card: `strategy-seeds/cards/williams18-xti_card.md`.

Approved G0 summary: D1 `XTIUSD.DWX` commodity trend-continuation rule from
SRC03 Williams S12. It requires two completed non-inside daily bars on the same
side of the 18-day close SMA, then places a stop entry through the two-bar
extreme with ATR hard stop, pending expiry, optional fixed-R take-profit, and
max-hold exit.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `XTIUSD.DWX` D1. No live
manifest, AutoTrading, portfolio gate, external runtime data, grid, martingale,
RSI/cum-RSI, or ML is involved.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-01 | initial Williams 18-bar WTI sleeve build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | `strategy-seeds/cards/williams18-xti_card.md` |
| Q01 Build Validation | 2026-07-01 | PASS | `artifacts/qm5_12851_build_result.json` |
| Q02 Baseline Screening | 2026-07-01 | QUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` work item `89fff876-40de-4fb5-9c19-74179947a0d7` |
