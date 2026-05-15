---
date: 2026-05-15
heartbeat: QB Quality-Business (run 3)
comment_posted: QUA-1533 (Singh batch-2 diversity offset monitoring)
blocked_unchanged: QUA-1527 (OWNER confirmation pending)
---

# QB Heartbeat — 2026-05-15 (run 3)

## Queue state

| Category | Status |
|---|---|
| G0 cards awaiting QB verdict | 0 (queue clear) |
| Active QB assignments | QUA-1530 (Jul MBR, backlog), QUA-806 (Gmail feedback routing, backlog) |
| Singh batch-2 offset rule (QUA-1533) | CEO backlog, due 2026-05-22 |
| singh-swap-fly exception (QUA-1527) | blocked — OWNER confirmation pending |

## Pipeline critical path

| EA | Phase | Blocker |
|---|---|---|
| QM5_1014 lien-channels | P2 blocked | QUA-1184 (CTO, due 2026-05-17) → QUA-1156 |
| QM5_1004 davey-es-breakout | P2 blocked | QUA-770 (US500.DWX setfiles missing) |
| QM5_1017 chan-pairs-stat-arb | P2 pair-infra | QUA-1460 (in_progress, HoP) |
| QM5_1009 lien-fade-double-zeros | TBD | — |

No EA has reached P9 live-portfolio inclusion. Portfolio caps (30%/TF, 40%/market, 50%/style)
not yet binding on live positions; monitored for the build queue.

## QUA-1537 routing note

QUA-1537 "[CTO/DevOps] Live Darwinex API: Verify WTI.cash.DWX and USDX.f availability"
was created today (2026-05-15) — currently unassigned. This unblocks singh-cmd-corr
(SRC06_S13) pre-P0 action flag in the dual-gate registry. QB notes: if both instruments
are unavailable and no Darwinex-native alternative maps cleanly, singh-cmd-corr should
move to Deferred (same category as SRC05 futures-dependent cards).

QUA-1537 should be assigned to DevOps (86015301). Flagged in QUA-1533 comment below.

## Diversity-offset status (concentration caps)

Current dual-gate pool (32 P0-ready cards):
- Forex single-pair: ~69% (cap 40%, BREACH — improving if WTI/USDX cards confirmed or deferred)
- D1 timeframe: ~28% (cap 30%, tracking)
- Style: trend-following ~31%, mean-reversion ~31% (balanced, well within 50% cap)

If WTI.cash.DWX and USDX.f are NOT available → singh-cmd-corr deferred → forex concentration
rises marginally (1 non-forex card removed), but D1 count drops by 1 (from the 28% bucket).
Net portfolio-fit impact: immaterial for concentration; slightly worse on forex-diversification.

The diversity-offset rule (>=3 non-forex non-D1 SRC07+ cards before Singh batch fires) remains
the binding constraint. CEO QUA-1533 due 2026-05-22.

## Monitoring items for July MBR

1. QUA-1184 fix lands → QM5_1014 P2 unblocked → first P2 results for lien-channels
2. QUA-1533 resolved → Singh batch-2 G0 (up to 13 more forex cards) — triggers QB portfolio-fit review
3. QUA-1460 stat-arb infra → QM5_1017 pipeline resumes — pair EA in non-forex category (positive)
4. QUA-1527 OWNER ratification → singh-swap-fly P0 gate cleared (or deferred)
5. QUA-1537 DevOps result → singh-cmd-corr P0 gate cleared or deferred
