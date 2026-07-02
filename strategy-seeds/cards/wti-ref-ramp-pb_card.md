---
ea_id: QM5_12869
slug: wti-ref-ramp-pb
type: strategy
strategy_id: EIA-WTI-REFINERY-MAINT-2026_S03
source_id: EIA-WTI-REFINERY-MAINT-2026
sources:
  - "[[sources/EIA-WTI-REFINERY-MAINT-2026]]"
strategy_type_flags: [calendar-seasonality, structural-demand, pullback-continuation, trend-filter-ma, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12869_XTI_REF_RAMP_PB_D1
period: D1
g0_status: APPROVED
status: APPROVED
pipeline_phase: Q02
last_updated: 2026-07-02
ml_required: false
---

# WTI Refinery Ramp Pullback Continuation

Canonical approved card:

`strategy-seeds/cards/approved/QM5_12869_wti-ref-ramp-pb_card.md`

This card mechanizes a low-frequency May-July WTI pullback-continuation sleeve
from the existing EIA refinery-maintenance source packet. Runtime uses Darwinex
MT5 OHLC and broker calendar only. No external feed, ML, grid, martingale, live
manifest, `T_Live`, portfolio gate, or AutoTrading change is part of this card.
