---
copy_of: strategy-seeds/cards/energy-vov_card.md
strategy_id: HOLLSTEIN-VOV-2021_XTI_XNG_S01
source_id: HOLLSTEIN-VOV-2021
ea_id: QM5_13146
slug: energy-vov
status: APPROVED
g0_status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
logical_symbol: QM5_13146_XTI_XNG_VOV_D1
period: D1
expected_trades_per_year_per_symbol: 12
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
---

# Approved Card Copy - QM5_13146_energy-vov

The canonical approved card is `strategy-seeds/cards/energy-vov_card.md`.
Approval covers exactly 252 overlapping realized-volatility estimates built
from 20 completed D1 log returns each; population dispersion divided by mean
RV; low-realized-VoV versus high-realized-VoV XTI/XNG direction; monthly
cadence; equal fixed-risk paired package; frozen ATR hard stops; next-month and
stale exits; same-month deal-history guard; and orphan cleanup.

Approval preserves the implied-to-realized substitution, broad-futures-to-two-
CFD narrowing, continuous-CFD basis, weaker modern source evidence, overlapping
windows, gaps, legging, and costs as binding Q02 kill risks. Live artifacts,
portfolio admission, and portfolio-gate changes are not approved.
