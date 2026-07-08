---
ea_id: QM5_13052
slug: brent-jul-prem
type: strategy
strategy_id: ARENDAS-OIL-SEASON-2018_BRENT_JUL_S05
source_id: ARENDAS-OIL-SEASON-2018
g0_status: APPROVED
status: APPROVED
target_symbols: [XBRUSD.DWX]
period: D1
pipeline_phase: Q02
last_updated: 2026-07-08
---

# QM5_13052 Brent July Calendar Premium

Approved card mirror for `strategy-seeds/cards/brent-jul-prem_card.md`.

Summary: low-frequency `XBRUSD.DWX` D1 July-only long calendar sleeve sourced
from Arendas, Tkacova, and Bukoven (2018), "Seasonal patterns in oil prices and
their implications for investors", Journal of International Studies. Runtime
uses MT5 OHLC, broker calendar, ATR, spread, and V5 framework guards only.

Non-duplicate notes: this is not the existing broad Brent February-September
first-month-bar card, not Brent September terminal-month exposure, not WTI July,
not WTI event/calendar, not XTI/XNG, not XNG, not XAU/XAG, and not RSI
commodity pullback logic.

Build: `artifacts/qm5_13052_build_result.json`
Q02 enqueue: `artifacts/qm5_13052_q02_enqueue_20260708.json`
