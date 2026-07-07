---
ea_id: QM5_13045
slug: xti-netimp-fade
strategy_id: EIA-XTI-NETIMP-FADE-2026
source_id: EIA-XTI-NETIMP-FADE-2026
status: APPROVED
pipeline_phase: Q02
---

# XTI Net-Import Shock Fade

Build-time copy of the approved card:
`strategy-seeds/cards/approved/QM5_13045_xti-netimp-fade_card.md`.

This EA implements a deterministic `XTIUSD.DWX` D1 WPSR net-import shock fade.
It trades no external EIA feed at runtime. It checks the completed
Wednesday/Thursday D1 signal bar, requires an ATR-sized shock plus a multi-day
same-direction extension away from SMA, then enters contrarian toward mean
reversion. It is capped to one signal per broker-calendar month.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX` D1
setfile. No T_Live, AutoTrading, deploy manifest, live setfile, or portfolio
gate is touched by this build.
