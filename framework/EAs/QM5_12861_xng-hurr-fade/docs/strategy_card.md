---
copy_of: strategy-seeds/cards/xng-hurr-fade_card.md
ea_id: QM5_12861
slug: xng-hurr-fade
type: strategy
strategy_id: EIA-NOAA-XNG-HURR-2026_S02
source_id: EIA-NOAA-XNG-HURR-2026
target_symbols: [XNGUSD.DWX]
logical_symbol: QM5_12861_XNG_HURR_FADE_D1
period: D1
g0_status: APPROVED
status: APPROVED
pipeline_phase: Q02
last_updated: 2026-07-01
---

# XNG Hurricane Failed-Spike Fade

Build reference copy for `QM5_12861_xng-hurr-fade`.

Canonical card: `strategy-seeds/cards/xng-hurr-fade_card.md`.
Approved card: `artifacts/cards_approved/QM5_12861_xng-hurr-fade.md`.

Implementation summary: single-symbol `XNGUSD.DWX` D1 short-only fade inside
the August 15 through October 31 hurricane risk window. Entry requires a
completed D1 upside new high, ATR/SMA stretch, bearish body, and close near the
bar low. Exit uses SMA normalization, upside channel invalidation, season end,
max hold, ATR stop, and V5 Friday close.

Backtest risk is `RISK_FIXED=1000`, `RISK_PERCENT=0`. No live deploy artifact,
AutoTrading action, portfolio gate edit, external runtime feed, grid,
martingale, or ML is authorized.
