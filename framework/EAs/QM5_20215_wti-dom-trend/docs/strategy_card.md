---
copy_of: strategy-seeds/cards/approved/QM5_20215_wti-dom-trend_card.md
strategy_id: BOROWSKI-MOP-WTI-DOMTREND-2026_S01
source_id: BOROWSKI-MOP-WTI-DOMTREND-2026
ea_id: QM5_20215
slug: wti-dom-trend
status: APPROVED
g0_status: APPROVED
target_symbols: [XTIUSD.DWX]
logical_symbol: XTIUSD.DWX
period: D1
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_STARTED
---

# Build-Time Card Reference

Canonical rules:
strategy-seeds/cards/approved/QM5_20215_wti-dom-trend_card.md.

The build must retain exact day 1 positive-trend longs, exact day 26
negative-trend shorts, completed Close[1]/Close[253] state, no date shifting,
one consumed attempt per exact date, next-D1 exit, fixed-risk ATR hard stop,
and one-day stale guard. No live or portfolio artifact is authorized.
