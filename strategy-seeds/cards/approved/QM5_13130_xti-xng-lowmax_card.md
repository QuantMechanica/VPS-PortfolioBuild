---
copy_of: strategy-seeds/cards/xti-xng-lowmax_card.md
strategy_id: HOLLSTEIN-MAX-2021_XTI_XNG_S01
source_id: HOLLSTEIN-MAX-2021
ea_id: QM5_13130
slug: xti-xng-lowmax
status: APPROVED
g0_status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
logical_symbol: QM5_13130_XTI_XNG_LOWMAX_D1
period: D1
expected_trades_per_year_per_symbol: 12
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
---

# Approved Card Copy - QM5_13130_xti-xng-lowmax

The canonical approved card is
`strategy-seeds/cards/xti-xng-lowmax_card.md`. Approval covers exactly the
prior-252-return top-five MAX formula, low-MAX-versus-high-MAX XTI/XNG rank,
equal half-risk paired monthly package, ATR hard stops, monthly/stale exits,
same-month deal-history guard, and orphan cleanup.

Approval preserves the source's full-sample null, post-financialization-only
direction, and broad-futures-to-two-CFD narrowing as binding Q02 kill risks.
No live artifact or portfolio admission is approved.
