---
ea_id: QM5_13090
slug: xti-xcu-rspread
type: strategy
strategy_id: EIA-CME-USGS-XTI-XCU-RSPREAD-2026
source_id: EIA-CME-USGS-XTI-XCU-RSPREAD-2026
g0_status: APPROVED
status: APPROVED
target_symbols: [XTIUSD.DWX, XCUUSD.DWX]
basket_symbols: [XTIUSD.DWX, XCUUSD.DWX]
logical_symbol: QM5_13090_XTI_XCU_RSPREAD_D1
period: D1
pipeline_phase: Q02
last_updated: 2026-07-09
---

# QM5_13090 XTI/XCU Return-Spread Reversion

Approved card mirror for `strategy-seeds/cards/xti-xcu-rspread_card.md`.

Summary: low-frequency market-neutral `XTIUSD.DWX` / `XCUUSD.DWX` D1
return-spread reversion basket sourced from EIA crude-oil price structure,
official CME/USGS copper references, and Chan pair-spread implementation
lineage. Runtime uses MT5 OHLC, spread, ATR, broker calendar, and V5 framework
guards only.

Non-duplicate notes: this is WTI versus copper relative-return reversion, not
XTI/AUD, XTI/CAD, XTI/XNG, oil/gold, oil/silver, Brent/silver, solo copper,
WTI event/seasonal/inventory/roll/COT/OPEC/IEA/JODI, XAU/XAG, XNG, index, or
commodity-RSI logic.

Build: `artifacts/qm5_13090_build_result.json`
Q02 enqueue: `artifacts/qm5_13090_q02_enqueue_20260709.json`

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-09 | APPROVED | this card |
| Q01 Build Validation | 2026-07-09 | PASS | `artifacts/qm5_13090_build_result.json` |
| Q02 Baseline Screening | 2026-07-09 | QUEUED | `artifacts/qm5_13090_q02_enqueue_20260709.json`; work item `c135bd93-a7f2-4cd8-b5ca-9ec4d5a11f2b` |
