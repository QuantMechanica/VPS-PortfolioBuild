# WTI Five-Year Same-Calendar Hodges-Lehmann Seasonality - Source Approval

Date: 2026-08-29

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced Q02 enqueue if the active factory remains below its CPU ceiling.
Enqueue does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It requests one genuinely new structural,
low-frequency commodity or energy sleeve outside the certified
XAU/SP500/NDX/XNG book, names direct WTI trend/seasonality as an acceptable
missing exposure, requires reputable-source criteria and `RISK_FIXED`
backtests, and forbids live and portfolio-gate work.

## Candidate Identity

- proposed slug: `wti-samecal-hl5`
- proposed strategy ID: `KELOHARJU-HL-WTI-SAMECAL5-2026_S01`
- proposed source ID: `KELOHARJU-HL-WTI-SAMECAL5-2026`
- carrier / host: exact `XTIUSD.DWX`, D1, slot 0
- clock: first executable D1 tick after each genuine broker-month transition
- state: exact prior-five-year returns for the upcoming calendar month,
  expanded into all fifteen inclusive pair averages
- lifecycle: follow the odd central pair-average sign until the next month

The governed allocator owns the EA ID. This source decision neither predicts
nor reserves an ID.

## Approved Source Basis And Claim Boundary

The complete bounded packet is
`strategy-seeds/sources/KELOHARJU-HL-WTI-SAMECAL5-2026/source.md`. Its two
peer-reviewed parent packets were read completely and are bound by the
reproducible receipt
`artifacts/qm5_wti_samecal_hl5_source_provenance_20260829.json`.

Keloharju, Linnainmaa, and Nyberg (2016), *Journal of Finance* 71(4),
1557-1590, DOI `10.1111/jofi.12398`, supply same-calendar return seasonality,
explicit crude-oil membership, monthly renewal, and a five-year eligibility
floor. The governed Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial
Economics* 104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, extraction
supplies explicit WTI own-return lineage and exact inclusive-pair
Hodges-Lehmann-style arithmetic.

Neither source tests the exact conjunction, standalone continuous CFD,
parameter set, execution plumbing, or current book. No source economics,
significance, density, cost, futures/CFD equivalence, or decorrelation result
transfers.

## Locked Mechanic

On the first executable `XTIUSD.DWX` D1 tick after a genuine broker-calendar
month transition in `(Y,M)`:

1. Process prior-position repair and persist `yyyymm` before every fallible
   gate. No flat, rejected, failed, stopped, or restarted outcome retries.
2. Under one uniform native or `+1` energy D1-label convention, reconstruct
   exactly the completed log return for calendar month `M` in each year
   `Y-1` through `Y-5`; require strict endpoints and all five exact years.
3. Form `(r[i]+r[j])/2` for all `0<=i<=j<=4`, require exactly fifteen values,
   sort ascending, and select zero-based index `7`.
4. BUY above `+1e-12`, SELL below `-1e-12`, and consume flat otherwise.
5. Use one `RISK_FIXED=1000` position with a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point positive-spread
   ceiling.
6. Close at the next broker-month boundary; 35 elapsed days is repair only.

Both news axes, legacy news mode, and framework Friday close are OFF. There is
no raw mean/median/trim fallback, trend, fixed-month direction, oscillator,
inventory, event, curve, volume, optimizer artifact, or external runtime feed.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_ESTIMATOR_AND_CFD_TRANSLATION_RISK`: two complete
  peer-reviewed lineages support the information object, WTI carrier, and
  governed estimator arithmetic; the exact conjunction remains untested.
- R2 `PASS`: exact years, endpoints, pair enumeration, pair count, central
  index, sign band, attempt, risk, stop, spread, and lifecycle are locked.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`: registered
  native `XTIUSD.DWX` D1 and MT5-native state provide every runtime field.
- R4 `PASS`: deterministic date, log, pair, sort, comparison, ATR risk, and
  execution arithmetic only; no trained output, banned signal indicator,
  external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,700 registry identities, 1,346 cards, and all
45 current Strategy Wiki nodes. It found no exact collision and surfaced four
expected same-calendar fuzzy neighbors. Receipt:
`artifacts/qm5_wti_samecal_hl5_preallocation_dedup_20260829.json`, SHA-256
`E632AB3679B349289275889DF63AD84699F756F09B4F04B0CB112F95A05F9B7E`.

Manual review establishes functional non-equivalence:

- `QM5_20099` uses a raw arithmetic mean; `QM5_41055` a raw median;
  `QM5_41059` a positive-hit boundary; and `QM5_41191` a ten-year absolute-
  rank signed score.
- `QM5_41199` uses the same exact five seasonal returns but drops the minimum
  and maximum and averages only the middle three. This rule instead retains
  every return through five self-pairs plus ten cross-pairs and selects the
  central value of the fifteen expanded averages.
- `QM5_20276` uses twelve contiguous recent monthly returns; `QM5_41139` uses
  daily returns inside one completed month. Neither has the disjoint exact-
  year same-calendar information object.

The fixed vectors `[-11,-9,-8,10,12]` and `[-12,-11,5,9,10]` prove opposite
directional disagreements between this pseudomedian and the raw mean, median,
and middle-three trim. Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_15_WALSH_AVERAGE_HODGES_LEHMANN_SIGN_MONTHLY_RENEWAL`.

## Kill And Safety Boundary

Q02 retires at zero trades, fewer than five completed positions in any full
post-warm-up year, nonpositive governed economics, or any label, endpoint,
exact-year, pair-count, self-pair, sort, index, sign, attempt, risk, stop,
lifecycle, or determinism defect. No failed result may be rescued by changing
years, estimator, direction, risk, hold, spread, or retry rules.

Direct WTI adds crude-oil exposure absent from the stated certified book, but
only unchanged Q09 owns realized decorrelation. This approval excludes manual
backtests; live/demo/shadow/stress/optimization setfiles; terminal control;
AutoTrading; `T_Live`; deploy or live manifests; portfolio-gate changes;
portfolio admission; and correlation waivers.
