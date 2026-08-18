# WTI Same-Calendar Hit-Rate - Source Approval

Date: 2026-08-18

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if the tester and host-CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission directs one new market-neutral or
structural low-frequency commodity edge, names WTI trend/seasonality as an
allowed carrier, requires reputable sources and `RISK_FIXED` backtests, and
forbids live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `wti-samecal-hit`
- proposed strategy ID:
  `KELOHARJU-PAPAILIAS-WTI-SAMECALHIT-2026_S01`
- proposed source ID: `KELOHARJU-PAPAILIAS-WTI-SAMECALHIT-2026`
- carrier: exact `XTIUSD.DWX`, D1, one direct symmetric position
- decision clock: first executable D1 tick of each genuine normalized broker
  month
- state: strict majority of up to ten prior completed occurrences of that
  same calendar month's WTI return sign, requiring at least five samples
- lifecycle: hold to the next normalized broker month

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The bounded governed packets below were read completely before this approval:

1. Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities,"
   *The Journal of Finance* 71(4), 1557-1590, DOI
   `10.1111/jofi.12398`, through the complete-read record at
   `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`. It supplies
   recurring same-calendar-month return information, a five-year history
   floor, and explicit crude-oil membership in the commodity universe.
2. Papailias, Liu, and Thomakos (2021), "Return Signal Momentum,"
   *Journal of Banking & Finance* 124, 106063, DOI
   `10.1016/j.jbankfin.2021.106063`, through the complete accepted-manuscript
   record at `strategy-seeds/sources/PAPAILIAS-RSM-2021/source.md`. It supplies
   the binary completed-return sign map, equal-weight positive-frequency
   estimator, monthly renewal, and explicit WTI membership.
3. The joined bounded lineage at
   `strategy-seeds/sources/KELOHARJU-PAPAILIAS-WTI-SAMECALHIT-2026/source.md`,
   which records the exact translation and adverse boundaries.

Keloharju et al. use magnitude-based same-calendar averages and diversified
cross-sectional portfolios. Papailias et al. count signs across twelve
consecutive recent months and use a `0.4` threshold. Neither source tests
same-calendar sign frequency, a strict-majority boundary, a single Darwinex
continuous WTI CFD, fixed cash risk, ATR stops, or this portfolio. The
conjunction is an explicit QM hypothesis. No source efficacy, density,
drawdown, transaction-cost, CFD-equivalence, or decorrelation result transfers.

## Locked Mechanic

On the first executable D1 tick of a genuine normalized broker month:

1. Repair malformed, duplicate, wrong-symbol, wrong-magic, missing-stop,
   later-month, or stale owned exposure before all entry-only gates.
2. Require exact host `XTIUSD.DWX`, D1, and one uniformly selected native or
   governed `+1` energy-label convention. Reject mixed or ambiguous labels.
3. Persist the broker `yyyymm` attempt before history, signal, news, spread,
   quote, ATR, sizing, or order gates. A late attachment consumes the month
   flat and may not backfill.
4. For years `Y-1` through `Y-10`, reconstruct only the exact completed return
   of calendar month `M`: logarithm of the last normalized D1 close in month
   `M` over the last normalized D1 close before month `M`. Reject partial or
   current-month endpoints; skip an invalid historical year without
   substitution.
5. Require five to ten valid returns. Map a non-negative return to `1` and a
   negative return to `0`, then compute the equal-weight positive frequency.
   Return magnitudes never enter the state.
6. BUY only above `0.5`, SELL only below `0.5`, and consume an exact tie flat.
   The fixed strict-majority boundary has no optimization surface.
7. Use one frozen `3.5 * ATR(20,D1)` hard stop, no target, a 1,500-point
   spread ceiling, and one `RISK_FIXED=1000` risk budget. Signal confidence
   never scales size.
8. Keep both news axes OFF and framework Friday close disabled. Close at the
   first observed boundary of a later normalized month or after 35 calendar
   days as a stale repair. Never retry, scale in, pyramid, grid, or martingale.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: two complete-read peer-reviewed
  finance sources with explicit WTI membership and a disclosed conjunction.
- R2 `PASS`: exact endpoints, sample bounds, binary map, frequency,
  strict-majority direction, attempt, risk, and lifecycle are locked.
- R3 `PASS_WITH_DISCLOSED_BASIS_RISK`: registered native WTI D1 history
  supplies every signal input; Q02 owns CFD-basis and history sufficiency.
- R4 `PASS`: deterministic native arithmetic and V5 state only; no banned
  signal, ML, external runtime data, adaptive fit, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,546 registry rows and 625 cards. It
found no exact or fuzzy identity. Manual review establishes that
`QM5_20099_wti-samecal` uses an arithmetic mean of return magnitudes,
`QM5_41055_wti-medcal` uses the sample median magnitude,
`QM5_20251_wti-cal-rsm` joins an arithmetic same-calendar mean to a separate
recent sign-momentum state, and `QM5_13150_wti-signmom` counts the immediately
preceding twelve months at a different threshold. None counts equal-weight
signs across prior occurrences of the named calendar month and trades their
strict majority. `QM5_12567` remains a short-horizon XNG oscillator pullback.

Verdict:
`CLEAN_WTI_SAME_CALENDAR_POSITIVE_RETURN_FREQUENCY_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is ten to twelve monthly positions per full post-warm-up
year. Q02 must retire the unchanged identity below five completed positions
per year, at zero trades or nonpositive governed economics, or on any endpoint,
label, sign-count, majority, attempt, risk, lifecycle, or determinism defect.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and host-CPU checks are below their ceilings. At
the ceiling, stop before queue mutation and record a non-live handoff.
