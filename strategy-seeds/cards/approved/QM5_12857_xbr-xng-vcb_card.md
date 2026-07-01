---
copy_of: strategy-seeds/cards/xbr-xng-vcb_card.md
ea_id: QM5_12857
slug: xbr-xng-vcb
type: strategy
strategy_id: BOLLINGER-BB-SQUEEZE-2001_XBR_XNG_VCB
source_id: BOLLINGER-BB-SQUEEZE-2001
target_symbols: [XBRUSD.DWX, XNGUSD.DWX]
logical_symbol: QM5_12857_XBR_XNG_VCB_D1
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

# XBR/XNG Ratio Volatility-Contraction Breakout

Canonical card: `strategy-seeds/cards/xbr-xng-vcb_card.md`.

Approved G0 summary: D1 market-neutral XBR/XNG log-ratio Bollinger BandWidth
compression breakout. The EA trades only after the ratio has reached a low
BandWidth rank and then closes outside its Bollinger envelope. It is explicitly
non-duplicate versus existing XTI/XNG z-score reversion, raw ratio-channel
breakout, return-spread reversion, relative momentum, fixed seasonal switching,
single-symbol Brent/WTI sleeves, WTI/Brent spreads, XNG RSI, and metal/index
exposure.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the logical basket
symbol `QM5_12857_XBR_XNG_VCB_D1`. No live manifest, AutoTrading, portfolio
gate, external runtime data, grid, martingale, or ML is involved.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-01 | initial XBR/XNG ratio volatility-contraction breakout build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | `strategy-seeds/cards/xbr-xng-vcb_card.md` |
| Q01 Build Validation | 2026-07-01 | PASS | `artifacts/qm5_12857_build_result.json` |
| Q02 Baseline Screening | 2026-07-01 | QUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` work item `189ba50a-caf0-4402-acde-623a4d2d7ff3` |
