# WTI Hurricane-Season Positive-Week Reversion - Source Approval

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

- proposed slug: `wti-hurr-posweek-fade`
- proposed strategy ID: `EIA-YANG-WTI-HURR-POSWEEK-FADE-20260911_S01`
- proposed source ID: `EIA-YANG-WTI-HURR-POSWEEK-FADE-20260911`
- carrier: exact `XTIUSD.DWX`, D1, one slot
- clock: first tradable D1 bar of each normalized broker week
- calendar: Monday-anchor month August, September, or October
- state: strictly positive open-to-close log return in the immediately
  completed normalized broker week
- direction and lifecycle: short WTI reversion for one normalized broker week

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The following committed records were read completely before this approval:

1. `strategy-seeds/sources/EIA-WTI-HURRICANE-2025/index.md`, SHA-256
   `F45086ADE9D8D16DE96962783077680DD3B3ACB228E01EBF81F909FAEFF23A8E`;
2. `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`, SHA-256
   `52DBFDAC58E6444D14AACFC97D26E4F8FA0010B6A10F0768DBE56067055ED7F7`.

The U.S. Energy Information Administration is the official U.S. government
energy publisher. Its governed packet records the Atlantic hurricane-season
window, peak late-summer/early-autumn timing, and Gulf Coast petroleum supply-
chain outage exposure. Yang, Goncu, and Pantelous provide academic commodity-
futures reversal lineage. Neither source tests this three-month broker
calendar, a single completed broker week, a one-week short-only WTI CFD
position, or the Darwinex continuous CFD. No efficacy, density, CFD-
equivalence, causal attribution, or decorrelation result transfers.

## Locked Mechanic

1. At the first tradable D1 bar of each Monday-anchored broker week, persist
   the attempt before every fallible entry gate.
2. Continue only when the anchor month is August, September, or October.
3. Reconstruct exactly the immediately completed normalized broker week with
   three through five valid, unique, ordered D1 sessions.
4. Compute `r = ln(final_close / first_open)`.
5. Sell only when `r > 0`. Equality, a nonpositive return, malformed history,
   or nonfinite arithmetic consumes the week flat. There is no long branch.
6. Use `RISK_FIXED>0`, `RISK_PERCENT=0`, a frozen `3.5*ATR(20,D1)` hard stop,
   no target, and a 1,500-point spread ceiling.
7. Close at the next normalized broker week or after ten elapsed days as stale
   repair. Never retry, trail, partially close, scale in, grid, martingale, or
   pyramid.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_SHORT_HORIZON_TRANSLATION_RISK`: complete
  official EIA context plus complete-read academic commodity-reversal lineage;
  the exact conjunction remains untested.
- R2 `PASS`: calendar, completed-week membership, endpoint, strict sign,
  direction, attempt, risk, stop, spread, and lifecycle are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history supplies every runtime market input.
- R4 `PASS`: deterministic native arithmetic and V5 state only; no ML,
  trained output, banned signal indicator, external runtime feed, grid, or
  martingale.

## Non-Duplicate Decision

`framework/scripts/research_dedup_check.py` scanned 4,913 registry rows and
1,523 repository cards. The configured Strategy Wiki root was unavailable;
that limitation remains explicit in
`artifacts/qm5_candidate_wti_hurr_posweek_fade_dedup_preallocation_20260911.json`.
No exact identity was found. Six fuzzy results were reported, with the five
material family neighbors manually resolved:

- `QM5_41430` has the same positive completed week and hurricane calendar but
  buys continuation. This candidate sells reversion, so the direction and
  hypothesis are opposite.
- `QM5_41431` uses the same reversal lineage and hurricane calendar but buys
  only after a negative completed week. Its admitted sign and side are both
  opposite.
- `QM5_41432` sells only after a negative week as continuation. The signal
  states are mutually exclusive and the economic mechanism differs.
- `QM5_41424` has the same positive-week/short package only in the refinery-
  maintenance calendar of February, March, September, and October. This card
  adds August and excludes February-March under a distinct hurricane-season
  hypothesis.
- `QM5_41421` admits negative weeks in the maintenance calendar and therefore
  differs in sign, calendar, and continuation/reversion premise.

The verdict is
`DISTINCT_WTI_HURRICANE_SEASON_POSITIVE_WEEK_SHORT_REVERSION`.

## Kill And Safety Boundary

Q02 must retire below five completed positions in any full post-warm-up year,
at zero trades or nonpositive governed economics, or on any contract defect.
This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal control; AutoTrading; `T_Live`; deploy or live
manifests; portfolio-gate changes; portfolio admission; decorrelation claims;
and correlation waivers.
