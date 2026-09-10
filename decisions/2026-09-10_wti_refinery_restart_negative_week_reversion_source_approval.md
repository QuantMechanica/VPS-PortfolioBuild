# WTI Refinery-Restart Negative-Week Reversion - Source Approval

Date: 2026-09-10

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced Q02 enqueue if tester and host-CPU ceilings permit.

Authority: the current explicit OWNER commodity/energy sleeve mission on the
`agents/board-advisor` branch. The mission requests one new, non-duplicate,
structural low-frequency commodity or energy edge, requires fixed-risk
backtests and reputable sources, and forbids live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `wti-refrestart-negweek-fade`
- proposed strategy ID: `EIA-YANG-WTI-REFRESTART-NEGWEEK-FADE-20260910_S01`
- proposed source ID: `EIA-YANG-WTI-REFRESTART-NEGWEEK-FADE-20260910`
- carrier: exact `XTIUSD.DWX` D1
- calendar: Monday anchor in April or May
- state: the immediately completed normalized broker week has a strictly
  negative open-to-close log return
- direction: long WTI for one normalized broker week

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The following committed records were read completely before this approval:

1. `strategy-seeds/sources/EIA-WTI-REFINERY-MAINT-2026/source.md`, SHA-256
   `4E614C320C567F6BC2C18C4C5DFC272E228686203C9206E0F0EE761EE8491097`;
2. `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`, SHA-256
   `52DBFDAC58E6444D14AACFC97D26E4F8FA0010B6A10F0768DBE56067055ED7F7`.

The U.S. Energy Information Administration is the official U.S. government
energy publisher. Its governed packet records the pre-summer transition from
planned refinery maintenance toward higher utilization. Yang, Goncu, and
Pantelous provide academic commodity-futures reversal lineage. Neither source
tests an April-May, negative-week, long-only, one-week WTI CFD conjunction.
No source efficacy, density, continuous-CFD equivalence, or portfolio-
decorrelation result transfers.

## Locked Mechanic

1. At the first tradable D1 bar of each Monday-anchored broker week, persist
   the attempt before every fallible entry gate.
2. Continue only for April and May anchor months.
3. Reconstruct exactly the immediately completed normalized broker week with
   three through five unique ordered D1 sessions and compute
   `ln(final_close / first_open)`.
4. A strictly negative return opens one long WTI position. Positive, exact
   zero, malformed, stale, or nonfinite history stays flat and consumes the
   week. There is no short branch.
5. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.
6. Close at the next normalized broker week or after ten elapsed days as stale
   repair. Never retry, trail, partially close, scale in, grid, martingale, or
   pyramid.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_SHORT_HORIZON_TRANSLATION_RISK`: official EIA
  post-maintenance context plus named academic commodity-reversal evidence,
  source hashes, and complete-read records.
- R2 `PASS`: calendar, completed-week package, negative sign, long side,
  attempt, risk, stop, spread, and lifecycle are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history supplies every runtime market input.
- R4 `PASS`: deterministic native arithmetic and V5 state only; no banned
  indicator, ML, external runtime feed, grid, or martingale.

## Non-Duplicate Decision

`framework/scripts/research_dedup_check.py` scanned 4,905 registry rows and
1,515 repository cards. The configured Strategy Wiki root was unavailable;
that limitation is retained in
`artifacts/qm5_candidate_wti_refrestart_negweek_fade_dedup_preallocation_20260910.json`
rather than silently converted to a clean result. No exact identity was found.

Manual review resolves both fuzzy neighbors. `QM5_41422` uses the same WTI
restart calendar and long side but admits only a strictly positive completed
week as continuation. This candidate admits only a strictly negative week as
reversion, so their entry states are mutually exclusive. `QM5_41392` trades
XNG rather than WTI, includes the autumn shoulder, and has symmetric long and
short branches. The new identity is jointly defined by the April-May WTI
restart regime, one immediately completed negative week, long-only fade, and
one-week lifecycle. Verdict:
`DISTINCT_WTI_REFINERY_RESTART_NEGATIVE_WEEK_REVERSION`.

## Kill And Safety Boundary

Q02 must retire below five completed positions in any full post-warm-up year,
at zero trades or nonpositive governed economics, or on any calendar, package,
direction, attempt, risk, lifecycle, or determinism defect. This approval
excludes manual backtests; live, demo, shadow, stress, and optimization
presets; terminal control; AutoTrading; `T_Live`; deploy/live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; and
decorrelation claims.
