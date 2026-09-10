# WTI Refinery-Maintenance Negative-Week Continuation - Source Approval

Date: 2026-09-10

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced Q02 enqueue if tester and host-CPU ceilings permit.

Authority: the current explicit OWNER commodity/energy sleeve mission on the
dedicated agent branch. The mission requests one new, non-duplicate,
structural low-frequency commodity or energy edge, requires fixed-risk
backtests and reputable sources, and forbids live and portfolio-gate mutation.

## Candidate Identity

- allocated identity: `QM5_41421`
- slug: `wti-refmaint-negweek-cont`
- strategy ID: `EIA-MOP-WTI-REFMAINT-NEGWEEK-CONT-20260910_S01`
- source ID: `EIA-MOP-WTI-REFMAINT-NEGWEEK-CONT-20260910`
- carrier: exact `XTIUSD.DWX` D1
- calendar: Monday anchor in February, March, September, or October
- state: the immediately completed normalized broker week has a strictly
  negative open-to-close log return
- direction: short WTI for one normalized broker week

## Approved Source Basis

The governed packets
`strategy-seeds/sources/EIA-WTI-REFINERY-MAINT-2026/source.md` and
`strategy-seeds/sources/MOP-TSMOM-2012/source.md` were read completely before
this approval. Their SHA-256 values are respectively
`4E614C320C567F6BC2C18C4C5DFC272E228686203C9206E0F0EE761EE8491097` and
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

The linked official EIA pages were also read on 2026-09-10. EIA reports that
refinery outages occur most frequently in the first quarter and fall, when
petroleum-product and crude-oil demand are seasonally lowest, and separately
reports that planned maintenance generally peaks in late February and March.
Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`, document own-return persistence
across liquid futures and include WTI. Neither source tests this four-month,
short-only weekly WTI CFD conjunction. No source efficacy, density,
CFD-equivalence, or decorrelation result transfers.

## Locked Mechanic

1. At the first tradable D1 bar of each Monday-anchored broker week, persist
   the attempt before every fallible entry gate.
2. Continue only for February, March, September, and October anchor months.
3. Reconstruct exactly the immediately completed normalized broker week with
   three through five unique ordered D1 sessions and compute
   `ln(final_close / first_open)`.
4. A strictly negative return opens one short WTI position. Positive, exact
   zero, malformed, stale, or nonfinite history stays flat and consumes the
   week. There is no long branch.
5. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.
6. Close at the next normalized broker week or after ten elapsed days as stale
   repair. Never retry, trail, partially close, scale in, grid, martingale, or
   pyramid.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: official EIA
  seasonal-maintenance context plus named peer-reviewed commodity momentum,
  DOI, and complete-read evidence.
- R2 `PASS`: calendar, completed-week package, negative sign, short side,
  attempt, risk, stop, spread, and lifecycle are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history supplies every runtime market input.
- R4 `PASS`: deterministic native arithmetic and V5 state only; no banned
  indicator, ML, external runtime feed, grid, or martingale.

## Non-Duplicate Decision

`framework/scripts/research_dedup_check.py` scanned 4,901 registry rows, 1,511
repository cards, and 45 Strategy Wiki nodes using the relocated canonical
Wiki path. It returned `CLEAN` in
`artifacts/qm5_candidate_wti_refmaint_negweek_cont_dedup_preallocation_20260910.json`.

Manual review separates the two-sided shoulder stretch-rejection fade
`QM5_12593`, the May-July refinery squeeze/pullback rules `QM5_12763` and
`QM5_12869`, the year-round single-week WTI momentum `QM5_41375`, the
year-round two-week streak `QM5_41419`, and the winter/summer two-week
agreement variants `QM5_41404` and `QM5_41406`. The new identity is jointly
defined by the refinery-maintenance months, one completed negative week,
short-only continuation, and one-week lifecycle. Verdict:
`DISTINCT_WTI_REFINERY_MAINTENANCE_NEGATIVE_WEEK_CONTINUATION`.

## Kill And Safety Boundary

Q02 must retire below five completed positions in any full post-warm-up year,
at zero trades or nonpositive governed economics, or on any calendar, package,
direction, attempt, risk, lifecycle, or determinism defect. This approval
excludes manual backtests; live, demo, shadow, stress, and optimization
presets; terminal control; AutoTrading; `T_Live`; deploy/live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; and
decorrelation claims.
