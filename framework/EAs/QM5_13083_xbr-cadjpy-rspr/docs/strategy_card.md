---
ea_id: QM5_13083
slug: xbr-cadjpy-rspr
strategy_id: EIA-BOC-BOJ-XBR-CADJPY-2026_S01
source_id: EIA-BOC-BOJ-XBR-CADJPY-2026
status: APPROVED
pipeline_phase: Q02
last_updated: 2026-07-09
---

# XBR/CADJPY Return-Spread Reversion

Approved card: `strategy-seeds/cards/xbr-cadjpy-rspr_card.md`.

This EA implements a D1 two-leg `XBRUSD.DWX` / `CADJPY.DWX` return-spread
z-score reversion basket. It uses only Darwinex MT5 OHLC at runtime. Backtests
use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the logical basket setfile
`QM5_13083_XBR_CADJPY_RSPREAD_D1`.

No live manifest, `T_Live` file, AutoTrading setting, portfolio gate, or
portfolio admission code is touched by this build.
