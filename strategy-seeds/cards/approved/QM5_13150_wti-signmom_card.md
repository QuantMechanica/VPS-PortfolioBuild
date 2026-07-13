---
copy_of: strategy-seeds/cards/wti-signmom_card.md
strategy_id: PAPAILIAS-RSM-2021_XTI_S02
source_id: PAPAILIAS-RSM-2021
ea_id: QM5_13150
slug: wti-signmom
status: APPROVED
g0_status: APPROVED
created: 2026-07-12
created_by: Research
last_updated: 2026-07-12
target_symbols: [XTIUSD.DWX]
period: D1
expected_trades_per_year_per_symbol: 12
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
---

# Approved Card Copy - QM5_13150_wti-signmom

The canonical approved card is
`strategy-seeds/cards/wti-signmom_card.md`. Approval covers exactly twelve
completed monthly WTI return signs, their equal-weight non-negative fraction,
the fixed source threshold 0.40, monthly renewal, one current-month attempt,
RISK_FIXED sizing, a frozen ATR hard stop, and the next-month/35-day exits.

The WTI carrier is explicitly linked to the existing XNG source sibling. Its
signal statistic remains distinct from cumulative-return WTI TSMOM. Approval
preserves the paper's adverse individual WTI drawdown, futures-to-CFD basis,
cost, and unproven book correlation as binding pipeline risks. No live artifact
or portfolio admission is approved. Q01 passed and Q02 work item
`a88b8890-3cb2-4ec7-bff0-bc72325057dd` is pending.
