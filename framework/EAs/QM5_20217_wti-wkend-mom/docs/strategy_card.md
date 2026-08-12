---
copy_of: strategy-seeds/cards/approved/QM5_20217_wti-wkend-mom_card.md
strategy_id: CHAN-TGIF-WTI-WKENDMOM-2026_S01
source_id: CHAN-TGIF-WTI-WKENDMOM-2026
ea_id: QM5_20217
slug: wti-wkend-mom
status: APPROVED
g0_status: APPROVED
target_symbols: [XTIUSD.DWX]
logical_symbol: XTIUSD.DWX
period: D1
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED
q02_work_item_id: 4eaf26f4-d7e7-4915-9e3f-9f0c4213d157
---

# Build-Time Card Reference

Canonical rules:
`strategy-seeds/cards/approved/QM5_20217_wti-wkend-mom_card.md`.

The build must retain the genuine Friday-to-Monday sequence, completed
90-return sample volatility, prior-Friday high/low thresholds, `0.10` buffer,
symmetric gap-direction continuation, consumed one-attempt state, first-
following-D1 exit, two-day stale repair, fixed-risk ATR hard stop, and no take
profit. No live or portfolio artifact is authorized.
