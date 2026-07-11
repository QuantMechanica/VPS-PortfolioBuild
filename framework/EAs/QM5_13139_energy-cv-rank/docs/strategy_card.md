---
copy_of: strategy-seeds/cards/energy-cv-rank_card.md
strategy_id: SZYMANOWSKA-CV-2014_XTI_XNG_S01
source_id: SZYMANOWSKA-CV-2014
ea_id: QM5_13139
slug: energy-cv-rank
status: APPROVED
g0_status: APPROVED
logical_symbol: QM5_13139_XTI_XNG_CV_D1
period: D1
pipeline_phase: Q02
---

# QM5_13139 Strategy Card Pointer

Canonical card: `strategy-seeds/cards/energy-cv-rank_card.md`.

This build implements the locked bimonthly XTI/XNG coefficient-of-variation
rank: 36 completed monthly log returns, sample variance divided by absolute
mean, long higher CV and short lower CV, equal fixed-risk legs, ATR hard stops,
next-period/stale exits, restart-safe same-period suppression, and orphan
cleanup. Q02 is a falsification of the two-CFD carrier; no source performance
or portfolio correlation is inherited.
