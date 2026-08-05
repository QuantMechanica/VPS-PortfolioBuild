---
copy_of: strategy-seeds/cards/approved/QM5_20221_wti-win-signmom_card.md
strategy_id: BURAKOV-PAPAILIAS-WTI-WINSIGN-2026_S01
source_id: BURAKOV-PAPAILIAS-WTI-WINSIGN-2026
ea_id: QM5_20221
slug: wti-win-signmom
status: APPROVED
g0_status: APPROVED
target_symbols: [XTIUSD.DWX]
logical_symbol: XTIUSD.DWX
period: D1
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED
---

# Build-Time Card Reference

Canonical rules:
`strategy-seeds/cards/approved/QM5_20221_wti-win-signmom_card.md`.

The build must retain the fixed November-May regime, June-October flat state,
thirteen consecutive completed month endpoints, twelve non-negative return
signs, fixed 0.40 threshold, monthly consumed-attempt state,
close-before-renew lifecycle, fixed-risk ATR hard stop, and no target. No live
or portfolio artifact is authorized.

Q01 evidence: `D:/QM/reports/framework/21/build_check_20260805_074444.json`
(PASS; zero failures and zero warnings).
