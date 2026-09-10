# WTI Refinery-Ramp Weekly Close-Location Continuation - Source Approval

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

- proposed slug: `wti-reframp-wclv-cont`
- proposed strategy ID: `EIA-MOP-WTI-REFRAMP-WCLV-CONT-20260910_S01`
- proposed source ID: `EIA-MOP-WTI-REFRAMP-WCLV-CONT-20260910`
- carrier: exact `XTIUSD.DWX`, D1, one slot
- clock: first tradable D1 bar of each normalized broker week
- calendar: Monday-anchor month April, May, June, or July
- state: positive parent-week-close to newest-week-close return, confirmed by
  the newest completed week closing strictly above two-thirds of its own range
- direction and lifecycle: long WTI for one normalized broker week

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The following committed records were read completely before this approval:

1. `strategy-seeds/sources/EIA-WTI-REFINERY-MAINT-2026/source.md`, SHA-256
   `4E614C320C567F6BC2C18C4C5DFC272E228686203C9206E0F0EE761EE8491097`;
2. `strategy-seeds/sources/MOP-WTI-WCLOSE-LOCATION-MOM-2026/source.md`, SHA-256
   `60292F608787EEC685AAF7B375D66B5A819E21EF2711FA2970AE73945B70F25D`.

The U.S. Energy Information Administration is the official U.S. government
energy publisher. Its governed packet records the pre-summer transition from
planned refinery maintenance toward higher utilization. The second packet
preserves a complete-read, peer-reviewed own-return momentum lineage that
explicitly includes WTI and discloses the weekly close-location translation.
Neither source tests this April-July, upper-tercile, long-only continuous-CFD
conjunction. No efficacy, density, CFD-equivalence, or decorrelation result
transfers.

## Locked Mechanic

1. At the first tradable D1 bar of each Monday-anchored broker week, persist
   the attempt before every fallible entry gate.
2. Continue only when the anchor month is April, May, June, or July.
3. Reconstruct exactly the two immediately completed adjacent normalized
   broker weeks, each with three through five valid, unique D1 sessions.
4. Compute `r = ln(newest_final_close / parent_final_close)` and
   `clv = (newest_final_close-newest_low)/(newest_high-newest_low)`.
5. Buy only when `r > 0` and `clv > 2/3`. Equality, a nonpositive return, a
   lower close location, malformed history, or nonfinite arithmetic consumes
   the week flat. There is no short branch.
6. Use `RISK_FIXED>0`, `RISK_PERCENT=0`, a frozen `3.5*ATR(20,D1)` hard stop,
   no target, and a 1,500-point spread ceiling.
7. Close at the next normalized broker week or after ten elapsed days as
   stale repair. Never retry, trail, partially close, scale in, grid,
   martingale, or pyramid.

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

`framework/scripts/research_dedup_check.py` scanned 4,906 registry rows and
1,516 repository cards. The configured Strategy Wiki root was unavailable;
that limitation remains explicit in
`artifacts/qm5_candidate_wti_reframp_wclv_cont_dedup_preallocation_20260910.json`.
No exact identity was found. Three fuzzy family neighbors require manual
resolution:

- `QM5_41080` is year-round and symmetric, uses strict outer-fifth thresholds,
  and sells lower-fifth negative states. This candidate is April-July,
  upper-tercile, and long-only.
- `QM5_41081` uses XNG, not WTI.
- `QM5_41422` reads one completed week's open-to-close sign and only April-May.
  This candidate reads two adjacent packages, uses parent-close to newest-close
  return, requires newest-week range-location confirmation, and includes the
  June-July utilization-ramp window. An opening gap can make the two return
  signs disagree, so neither signal contains the other.

The May-July daily compression-breakout and pullback builds use current D1
price patterns, not completed-week endpoint/range state. Verdict:
`DISTINCT_WTI_APRIL_JULY_REFINERY_RAMP_PARENT_CLOSE_RETURN_UPPER_TERCILE_WEEKLY_CONTINUATION`.

## Kill And Safety Boundary

Q02 must retire below five completed positions in any full post-warm-up year,
at zero trades or nonpositive governed economics, or on any calendar, package,
endpoint, close-location, direction, attempt, risk, lifecycle, or determinism
defect. This approval excludes manual backtests; live, demo, shadow, stress,
and optimization presets; terminal control; AutoTrading; `T_Live`; deploy or
live manifests; portfolio-gate changes; portfolio admission; decorrelation
claims; and correlation waivers.
