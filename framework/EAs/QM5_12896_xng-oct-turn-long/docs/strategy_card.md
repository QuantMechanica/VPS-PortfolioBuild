---
copy_of: strategy-seeds/cards/xng-oct-turn-long_card.md
ea_id: QM5_12896
slug: xng-oct-turn-long
status: APPROVED
pipeline_phase: Q02
---

# XNG October Winter-Turn Long

Build copy for `QM5_12896_xng-oct-turn-long`.

The EA trades `XNGUSD.DWX` on D1. It checks the first D1 bar of each
broker-calendar week in October and November, buys only after a positive
10-D1 turn and fast/slow SMA confirmation, and exits on ATR stop, fast-SMA
failure, season end, or max hold.

The edge is source-backed by the EIA natural-gas seasonality note and is
distinct from `QM5_12567` because it is a seasonal transition/trend rule, not
an RSI pullback. Backtests use `RISK_FIXED=1000`. No live deployment files are
touched.
