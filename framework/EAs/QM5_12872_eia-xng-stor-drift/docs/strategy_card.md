---
ea_id: QM5_12872
slug: eia-xng-stor-drift
status: APPROVED
source_id: EIA-XNG-STOR-DRIFT-2026
period: D1
target_symbols: [XNGUSD.DWX]
pipeline_phase: Q02
---

# EIA XNG Storage Drift

Canonical approved card copy. Full source card lives at
`strategy-seeds/cards/approved/QM5_12872_eia-xng-stor-drift_card.md`.

The EA trades `XNGUSD.DWX` on D1 only. It uses EIA natural-gas storage report
cadence and EIA storage-season definitions as structural lineage, but it does
not read EIA values, analyst expectations, weather, futures curves, CSV files,
APIs, or news feeds at runtime. It follows confirmed report-window D1 drift in
the seasonal direction, consumes at most one signal per broker-calendar month,
and exits by ATR hard stop, SMA trend failure, time, standard news, and Friday
close.

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live/deploy manifest,
T_Live, portfolio gate, or AutoTrading setting is touched. This is not RSI,
not storage fade, not storage inside-bar breakout, not generic aftershock, not
XNG COT/production/rig-count/weather/LNG/month-ORB/carry logic, and not index
or metal exposure.
