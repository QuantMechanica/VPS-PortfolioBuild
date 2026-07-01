---
copy_of: strategy-seeds/cards/williams18-xti_card.md
ea_id: QM5_12851
slug: williams18-xti
type: strategy
strategy_id: SRC03_S12_XTI_20260701
source_id: SRC03
target_symbols: [XTIUSD.DWX]
period: D1
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-01
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
| Q01 Build Validation | 2026-07-01 | PENDING | `artifacts/qm5_12851_build_result.json` |
| Q02 Baseline Screening | 2026-07-01 | PENDING | queued after Q01 record-build |
