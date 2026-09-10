# WTI Refinery-Maintenance Weekly Close-Location Reversion - Source Approval

Date: 2026-09-11

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced Q02 enqueue if the whole-host CPU ceiling permits.

Authority: the current explicit OWNER commodity/energy sleeve mission on
branch `agents/board-advisor`. The mission requests one new, non-duplicate,
structural low-frequency commodity/energy edge outside the certified
XAU/SP500/NDX/XNG carrier set, requires fixed-risk backtests and reputable
source criteria, and forbids live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `wti-refmaint-wclv-fade`
- proposed strategy ID: `EIA-YANG-WTI-REFMAINT-WCLV-FADE-20260911_S01`
- proposed source ID: `EIA-YANG-WTI-REFMAINT-WCLV-FADE-20260911`
- carrier: exact `XTIUSD.DWX`, D1, one slot
- clock: first tradable D1 bar of each normalized broker week
- calendar: Monday-anchor month February, March, September, or October
- state: positive parent-week-close to newest-week-close return, confirmed by
  the newest completed week closing strictly above two-thirds of its range
- direction and lifecycle: short WTI reversion for one normalized broker week

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The following committed records were read completely before this approval:

1. `strategy-seeds/sources/EIA-WTI-REFINERY-MAINT-2026/source.md`, SHA-256
   `4E614C320C567F6BC2C18C4C5DFC272E228686203C9206E0F0EE761EE8491097`;
2. `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`, SHA-256
   `52DBFDAC58E6444D14AACFC97D26E4F8FA0010B6A10F0768DBE56067055ED7F7`.

The U.S. Energy Information Administration is the official U.S. government
energy publisher. Its governed packet records recurring refinery-maintenance
and turnaround structure. Yang, Goncu, and Pantelous provide academic
commodity-futures reversal lineage. Neither source tests these four broker
calendar months, two completed weeks, the parent-close endpoint, an upper-
tercile confirmation, a one-week short, or a Darwinex continuous WTI CFD. No
efficacy, density, CFD-equivalence, or decorrelation result transfers.

## Locked Mechanic

1. At the first tradable D1 bar of each Monday-anchored broker week, persist
   the attempt before every fallible entry gate.
2. Continue only when the anchor month is February, March, September, or
   October.
3. Reconstruct exactly the two immediately completed adjacent normalized
   broker weeks, each with three through five valid, unique D1 sessions.
4. Compute `r = ln(newest_final_close / parent_final_close)` and
   `clv = (newest_final_close-newest_low)/(newest_high-newest_low)`.
5. Sell only when `r > 0` and `clv > 2/3`. Equality, a nonpositive return, a
   lower close location, malformed history, or nonfinite arithmetic consumes
   the week flat. There is no long branch.
6. Use `RISK_FIXED>0`, `RISK_PERCENT=0`, a frozen `3.5*ATR(20,D1)` hard stop,
   no target, and a 1,500-point spread ceiling.
7. Close at the next normalized broker week or after ten elapsed days as stale
   repair. Never retry, trail, partially close, scale in, grid, martingale, or
   pyramid.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_CALENDAR_TRANSLATION_RISK`: one canonical
  governed child source combines complete official and academic parent
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

`framework/scripts/research_dedup_check.py` scanned 4,909 registry rows and
1,519 repository cards. The configured Strategy Wiki root was unavailable;
that limitation remains explicit in
`artifacts/qm5_candidate_wti_refmaint_wclv_fade_dedup_preallocation_20260911.json`.
No exact identity was found. Three fuzzy neighbors were manually resolved:

- `QM5_41427` sells only a negative/lower-tercile state as continuation; this
  candidate sells only a positive/upper-tercile state as reversion. The
  admitted states are mutually exclusive.
- `QM5_41424` uses one completed week's open-to-close sign with no range-
  location gate. This candidate uses two adjacent completed packages and a
  parent-close endpoint; an opening gap can make the return signs disagree.
- `QM5_41428` trades April-July, buys a negative/lower-tercile state, and is
  therefore disjoint in calendar, sign, close location, and direction.

The verdict is
`DISTINCT_WTI_REFMAINT_PARENT_CLOSE_POSITIVE_UPPER_TERCILE_WEEKLY_REVERSION`.

## Kill And Safety Boundary

Q02 must retire below five completed positions in any full post-warm-up year,
at zero trades or nonpositive governed economics, or on any contract defect.
This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal control; AutoTrading; `T_Live`; deploy or live
manifests; portfolio-gate changes; portfolio admission; decorrelation claims;
and correlation waivers.
