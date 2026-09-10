# WTI Refinery-Ramp Weekly Close-Location Reversion - Source Approval

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

- proposed slug: `wti-reframp-wclv-fade`
- proposed strategy ID: `EIA-YANG-WTI-REFRAMP-WCLV-FADE-20260910_S01`
- proposed source ID: `EIA-YANG-WTI-REFRAMP-WCLV-FADE-20260910`
- carrier: exact `XTIUSD.DWX`, D1, one slot
- clock: first tradable D1 bar of each normalized broker week
- calendar: Monday-anchor month April, May, June, or July
- state: negative parent-week-close to newest-week-close return, confirmed by
  the newest completed week closing strictly below one-third of its own range
- direction and lifecycle: long WTI reversion for one normalized broker week

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The following committed records were read completely before this approval:

1. `strategy-seeds/sources/EIA-WTI-REFINERY-MAINT-2026/source.md`, SHA-256
   `4E614C320C567F6BC2C18C4C5DFC272E228686203C9206E0F0EE761EE8491097`;
2. `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`, SHA-256
   `52DBFDAC58E6444D14AACFC97D26E4F8FA0010B6A10F0768DBE56067055ED7F7`.

The U.S. Energy Information Administration is the official U.S. government
energy publisher. Its governed packet records the transition from planned
refinery maintenance toward higher pre-summer utilization. Yang, Goncu, and
Pantelous provide academic commodity-futures reversal lineage. Neither source
tests April-July, two completed broker weeks, a parent-close return, a lower-
tercile close, a one-week long-only horizon, or a Darwinex continuous WTI CFD.
No efficacy, density, CFD-equivalence, or decorrelation result transfers.

Direct generic URL retrieval was attempted through the governed source router
on 2026-09-10 and classified `DEFERRED:SOURCE_POLICY` for both the EIA and SSRN
pages. No blocked page text was used; the committed complete-read parent
records and their hashes are the bounded evidence basis.

## Locked Mechanic

1. At the first tradable D1 bar of each Monday-anchored broker week, persist
   the attempt before every fallible entry gate.
2. Continue only when the anchor month is April, May, June, or July.
3. Reconstruct exactly the two immediately completed adjacent normalized
   broker weeks, each with three through five valid, unique D1 sessions.
4. Compute `r = ln(newest_final_close / parent_final_close)` and
   `clv = (newest_final_close-newest_low)/(newest_high-newest_low)`.
5. Buy only when `r < 0` and `clv < 1/3`. Equality, a nonnegative return, a
   higher close location, malformed history, or nonfinite arithmetic consumes
   the week flat. There is no short branch.
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

`framework/scripts/research_dedup_check.py` scanned 4,908 registry rows and
1,518 repository cards. The configured Strategy Wiki root was unavailable;
that limitation remains explicit in
`artifacts/qm5_candidate_wti_reframp_wclv_fade_dedup_preallocation_20260910.json`.
No exact identity was found. One fuzzy match requires manual resolution:

- `QM5_41426` uses the same calendar and parent-close/range construction but
  buys only a strictly positive, upper-tercile state as continuation. This
  candidate buys only a strictly negative, lower-tercile state as reversion;
  the admitted states are mutually exclusive.

`QM5_41425` uses April-May and one completed week's open-to-close sign without
a range-location gate. An opening gap can make its return sign disagree with
this two-package parent-close endpoint, and this candidate also includes June
and July. The verdict is
`DISTINCT_WTI_APRIL_JULY_REFINERY_RAMP_PARENT_CLOSE_NEGATIVE_LOWER_TERCILE_WEEKLY_REVERSION`.

## Kill And Safety Boundary

Q02 must retire below five completed positions in any full post-warm-up year,
at zero trades or nonpositive governed economics, or on any calendar, package,
endpoint, close-location, direction, attempt, risk, lifecycle, or determinism
defect. This approval excludes manual backtests; live, demo, shadow, stress,
and optimization presets; terminal control; AutoTrading; `T_Live`; deploy or
live manifests; portfolio-gate changes; portfolio admission; decorrelation
claims; and correlation waivers.
