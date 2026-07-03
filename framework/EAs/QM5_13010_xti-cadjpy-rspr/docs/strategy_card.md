---
ea_id: QM5_13010
slug: xti-cadjpy-rspr
strategy_id: EIA-BOC-BOJ-XTI-CADJPY-2026_S01
source_id: EIA-BOC-BOJ-XTI-CADJPY-2026
status: APPROVED
pipeline_phase: Q02
last_updated: 2026-07-04
---

# XTI/CADJPY Return-Spread Reversion

Approved card: `strategy-seeds/cards/xti-cadjpy-rspr_card.md`.

This EA implements a D1 two-leg `XTIUSD.DWX` / `CADJPY.DWX` return-spread
z-score reversion basket. It uses only Darwinex MT5 OHLC at runtime. Backtests
use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the logical basket setfile
`QM5_13010_XTI_CADJPY_RSPREAD_D1`.

No live manifest, `T_Live` file, AutoTrading setting, portfolio gate, or
portfolio admission code is touched by this build.
