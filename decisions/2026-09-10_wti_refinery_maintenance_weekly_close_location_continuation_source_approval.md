# WTI Refinery-Maintenance Weekly Close-Location Continuation - Source Approval

Date: 2026-09-10

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced Q02 enqueue if the whole-host CPU ceiling permits.

Authority: the current explicit OWNER commodity/energy sleeve mission on
branch `agents/board-advisor`. The mission requests one new, non-duplicate,
structural low-frequency commodity/energy edge outside the certified
XAU/SP500/NDX/XNG carrier set, requires fixed-risk backtests and reputable
source criteria, and forbids live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `wti-refmaint-wclv-cont`
- proposed strategy ID: `EIA-MOP-WTI-REFMAINT-WCLV-CONT-20260910_S01`
- proposed source ID: `EIA-MOP-WTI-REFMAINT-WCLV-CONT-20260910`
- carrier: exact `XTIUSD.DWX`, D1, one slot
- clock: first tradable D1 bar of each normalized broker week
- calendar: Monday-anchor month February, March, September, or October
- state: negative parent-week-close to newest-week-close return, confirmed by
  the newest completed week closing strictly below one-third of its own range
- direction and lifecycle: short WTI for one normalized broker week

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The following committed records were read completely before this approval:

1. `strategy-seeds/sources/EIA-WTI-REFINERY-MAINT-2026/source.md`, SHA-256
   `4E614C320C567F6BC2C18C4C5DFC272E228686203C9206E0F0EE761EE8491097`;
2. `strategy-seeds/sources/MOP-WTI-WCLOSE-LOCATION-MOM-2026/source.md`, SHA-256
   `60292F608787EEC685AAF7B375D66B5A819E21EF2711FA2970AE73945B70F25D`.

The U.S. Energy Information Administration is the official U.S. government
energy publisher. Its governed packet records planned refinery-maintenance
structure in late winter and fall. The second packet preserves a complete-read,
peer-reviewed own-return momentum lineage that explicitly includes WTI and
discloses the weekly close-location translation. Neither source tests this
four-month, lower-tercile, short-only continuous-CFD conjunction. No efficacy,
density, CFD-equivalence, or decorrelation result transfers.

## Locked Mechanic

1. At the first tradable D1 bar of each Monday-anchored broker week, persist
   the attempt before every fallible entry gate.
2. Continue only when the anchor month is February, March, September, or
   October.
3. Reconstruct exactly the two immediately completed adjacent normalized
   broker weeks, each with three through five valid, unique D1 sessions.
4. Compute `r = ln(newest_final_close / parent_final_close)` and
   `clv = (newest_final_close-newest_low)/(newest_high-newest_low)`.
5. Sell only when `r < 0` and `clv < 1/3`. Equality, a nonnegative return, a
   higher close location, malformed history, or nonfinite arithmetic consumes
   the week flat. There is no long branch.
6. Use `RISK_FIXED>0`, `RISK_PERCENT=0`, a frozen `3.5*ATR(20,D1)` hard stop,
   no target, and a 1,500-point spread ceiling.
7. Close at the next normalized broker week or after ten elapsed days as stale
   repair. Never retry, trail, partially close, scale in, grid, martingale, or
   pyramid.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_CALENDAR_TRANSLATION_RISK`: one canonical
  governed child source combines complete official and peer-reviewed parent
  records; the exact conjunction remains untested.
- R2 `PASS`: calendar, completed-week packages, endpoints, strict sign,
  close-location boundary, direction, attempt, risk, stop, spread, and
  lifecycle are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history supplies every runtime market input.
- R4 `PASS`: deterministic native arithmetic and V5 state only; no ML,
  trained output, banned signal indicator, external runtime feed, grid, or
  martingale.

## Non-Duplicate Decision

`framework/scripts/research_dedup_check.py` scanned 4,907 registry rows and
1,517 repository cards. The configured Strategy Wiki root was unavailable;
that limitation remains explicit in
`artifacts/qm5_candidate_wti_refmaint_wclv_cont_dedup_preallocation_20260910.json`.
No exact identity was found. Four fuzzy family neighbors require manual
resolution:

- `QM5_41421` uses the same calendar and short side but reads exactly one
  completed week's open-to-close sign and has no range-location gate. This
  candidate reads two adjacent packages and excludes the newest opening gap.
- `QM5_41426` uses the same endpoint/range construction but trades only the
  April-July refinery ramp, requires a positive return and upper-tercile close,
  and buys rather than sells. The seasonal regimes and qualifying states are
  disjoint.
- `QM5_41080` is year-round and symmetric, uses strict outer-fifth thresholds,
  and includes an upper long branch. This candidate is maintenance-only,
  lower-tercile, and short-only.
- `QM5_41081` uses XNG, not WTI.

An opening gap can make the one-week open-to-close sign disagree with the
parent-close endpoint, so `QM5_41421` does not contain this signal. Verdict:
`DISTINCT_WTI_REFINERY_MAINTENANCE_PARENT_CLOSE_RETURN_LOWER_TERCILE_WEEKLY_CONTINUATION`.

## Kill And Safety Boundary

Q02 must retire below five completed positions in any full post-warm-up year,
at zero trades or nonpositive governed economics, or on any calendar, package,
endpoint, close-location, direction, attempt, risk, lifecycle, or determinism
defect. This approval excludes manual backtests; live, demo, shadow, stress,
and optimization presets; terminal control; AutoTrading; `T_Live`; deploy or
live manifests; portfolio-gate changes; portfolio admission; decorrelation
claims; and correlation waivers.
