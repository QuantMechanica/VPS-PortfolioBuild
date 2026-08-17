# QM5_41051 - WTI Exact-Week Pullback / Friday Bounce

Status: `G0 APPROVED; MAGIC ALLOCATED; BUILD PASS; Q01 PASS; Q02 NOT ENQUEUED — CPU CEILING`

## Identity

- EA ID: `QM5_41051`
- slug: `wti-fri-weekfade`
- strategy ID: `GORSKA-YANG-WTI-FRIWEEKFADE-2026_S01`
- source ID: `GORSKA-YANG-WTI-FRIWEEKFADE-2026`
- source packet:
  `strategy-seeds/sources/GORSKA-YANG-WTI-FRIWEEKFADE-2026/source.md`
- source approval:
  `decisions/2026-08-17_wti_friday_week_pullback_source_approval.md`
- host: exact `XTIUSD.DWX`, D1
- slot: `0`
- registered magic: `410510000`
- approved card:
  `strategy-seeds/cards/approved/QM5_41051_wti-fri-weekfade_card.md`
- G0 decision:
  `decisions/2026-08-17_wti_friday_week_pullback_g0.md`

## Locked Candidate Boundary

At the first executable tick of a genuine broker Friday, within 180 minutes
of the D1 session open, require exact completed Thursday, Wednesday, Tuesday,
and Monday sessions under one uniform energy-label convention. Consume the
Friday attempt before every fallible gate. Compute only
`ln(ThursdayClose / MondayOpen)`. Buy WTI when it is strictly negative and
consume all other states flat.

The planned non-live build uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, one
frozen `3.0 * ATR(20,D1)` hard stop, no target, a 1,500-point spread ceiling,
framework Friday close at broker hour 21, and first-later-D1/three-day stale
repair. It has no external runtime source, retry, scale-in, grid, martingale,
hedge, or pyramid.

## Duplicate Boundary

The canonical checker scanned 4,538 EA rows and 625 root cards and returned
`CLEAN`. Manual review separates the exact Monday-open through Thursday-close
formation from the thresholded Thursday-only bounce (`QM5_12753`), the
Thursday-surge short (`QM5_20117`), unconditional Friday premium
(`QM5_12597`), 252-D1 Friday regimes (`QM5_20145`, `QM5_20172`), first-Friday
prior-month reversal (`QM5_41026`), and earlier/prior-week momentum families.

## Build State

The branch-only V5 implementation is complete with one compiled `.ex5`, an
exact approved-card copy, 13 independent reference fixtures, and one
`RISK_FIXED` D1 backtest preset. Strict MetaEditor compilation completed with
zero errors and zero warnings; the targeted V5 build gate and P1 artifact
validator both returned `PASS` on 2026-08-17. The setfile carries the generated
source build hash.

The target-only Q02 dry run selected exactly one new row, but the five-sample
pre-apply host reading reached 100% and exceeded the 97% hard CPU ceiling.
No queue row was created. A later paced operator may enqueue only after a fresh
tester-slot and CPU check passes. Development must not change the calendar,
endpoints, sign, direction, risk, or lifecycle.

No live artifact, manual test, terminal control, portfolio mutation, or
performance claim is authorized.
