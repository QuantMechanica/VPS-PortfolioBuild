---
ea_id: QM5_13076
slug: xti-nzdcad-rspr
strategy_id: EIA-BOC-RBNZ-XTI-NZDCAD-2026
source_id: EIA-BOC-RBNZ-XTI-NZDCAD-2026
status: APPROVED
pipeline_phase: Q02
last_updated: 2026-07-09
---

# XTI/NZDCAD Return-Spread Reversion

Approved card: `strategy-seeds/cards/xti-nzdcad-rspr_card.md`.

This EA implements a D1 two-leg `XTIUSD.DWX` / `NZDCAD.DWX` return-spread
z-score reversion basket. It uses only Darwinex MT5 OHLC at runtime. Backtests
use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the logical basket setfile
`QM5_13076_XTI_NZDCAD_RSPREAD_D1`.

No live manifest, `T_Live` file, AutoTrading setting, portfolio gate, or
portfolio admission code is touched by this build.
