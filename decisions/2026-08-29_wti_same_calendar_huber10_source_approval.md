# WTI Ten-Year Same-Calendar Huber Seasonality - Source Approval

Date: 2026-08-29

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced Q02 enqueue if the active factory remains below its CPU ceiling.
Enqueue does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It requests one genuinely new structural,
low-frequency commodity or energy sleeve outside the certified
XAU/SP500/NDX/XNG book, names direct WTI trend/seasonality as acceptable
missing exposure, requires reputable-source criteria and `RISK_FIXED`
backtests, and forbids live and portfolio-gate work.

## Candidate Identity

- proposed slug: `wti-samecal-huber10`
- proposed strategy ID: `KELOHARJU-HUBER-WTI-SAMECAL10-2026_S01`
- proposed source ID: `KELOHARJU-HUBER-WTI-SAMECAL10-2026`
- carrier / host: exact `XTIUSD.DWX`, D1, slot 0
- clock: first executable D1 tick after each genuine broker-month transition
- state: exact prior-ten-year returns for the upcoming calendar month
- statistic: fixed-scale 32-update Huber M-location initialized from the even
  median and scaled by the even raw MAD
- lifecycle: follow the strict Huber-location sign until the next month

The atomic governed allocator owns the EA ID. This source decision neither
predicts nor reserves an ID.

## Approved Source Basis And Claim Boundary

The complete bounded packet is
`strategy-seeds/sources/KELOHARJU-HUBER-WTI-SAMECAL10-2026/source.md`. Its two
complete-read parent packets and exact hashes are bound by
`artifacts/qm5_wti_samecal_huber10_source_provenance_20260829.json`.

Keloharju, Linnainmaa, and Nyberg (2016), *Journal of Finance* 71(4),
1557-1590, DOI `10.1111/jofi.12398`, supply same-calendar return seasonality,
explicit crude-oil membership, monthly renewal, and a five-year eligibility
floor. Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, supply WTI own-return
lineage. Huber (1964), *Annals of Mathematical Statistics* 35(1), 73-101,
DOI `10.1214/aoms/1177703732`, supplies bounded-influence location lineage;
the exact fixed-scale iteration is already governed in the complete
`MOP-WTI-HUBER-2026` packet.

No source tests the exact ten-year same-calendar Huber conjunction, a
standalone continuous CFD, the locked execution plumbing, or the current
book. No performance, significance, density, cost, drawdown, CFD-equivalence,
decorrelation, or portfolio result transfers.

## Locked Mechanic

At the first executable `XTIUSD.DWX` D1 tick after a genuine broker-calendar
month transition in `(Y,M)`:

1. Repair owned exposure and persist `yyyymm` before every fallible entry
   gate. Never retry the month after any downstream outcome.
2. Under one uniform native or `+1` energy D1-label convention, reconstruct
   the exact completed calendar-month log return for month `M` in every year
   `Y-1..Y-10`; require all ten exact years and strict adjacent endpoints.
3. Compute the even median and even raw MAD, freeze
   `delta=1.5*1.4826*MAD`, and run exactly 32 Huber reweighted-mean updates.
4. BUY above `+1e-12`, SELL below `-1e-12`, and consume flat otherwise.
5. Use one `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1` position with a frozen `3.5*ATR(20,D1)` hard stop,
   no target, and a 1,500-point positive-spread ceiling.
6. Close at the next broker-month boundary; 35 elapsed days is repair only.

Both news axes, legacy news mode, and framework Friday close are OFF. No
fallback estimator, current-month input, trend confirmation, magnitude
sizing, inventory, event, curve, volume, optimizer artifact, trained output,
or external runtime feed is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_ESTIMATOR_AND_CFD_TRANSLATION_RISK`: complete-read,
  peer-reviewed lineages support the information object, WTI carrier, and
  bounded-influence arithmetic; the exact conjunction is untested.
- R2 `PASS`: exact years, endpoints, median/MAD, constants, weight equation,
  update count, sign band, attempt, risk, stop, spread, and lifecycle are
  locked before Q02.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native `XTIUSD.DWX` D1 and MT5 state provide all inputs; history,
  label, roll, fill, and CFD-basis risks remain explicit.
- R4 `PASS`: deterministic calendar, logarithm, sort, absolute-deviation,
  fixed arithmetic, ATR-risk, and execution state only; no trained output,
  banned signal indicator, or external feed.

## Non-Duplicate Decision

The canonical checker scanned 4,703 registry identities, 1,349 cards, and all
45 current Strategy Wiki nodes. It found no exact collision and returned only
the expected raw-mean same-calendar fuzzy neighbor. Receipt:
`artifacts/qm5_wti_samecal_huber10_preallocation_dedup_20260829.json`.

Manual review separates the executable identity:

- `QM5_20099` is a raw same-calendar mean with no robust scale or iteration;
- `QM5_20285` uses the Huber family on twelve adjacent recent broker-month
  returns, not ten disjoint exact-year returns for one recurring month;
- `QM5_41191` uses a centered signed absolute-rank sum, not a return location;
- `QM5_41199`, `QM5_41201`, and `QM5_41202` use exact-five-year trim,
  inclusive-pair pseudomedian, and Winsorized statistics.

The disclosed disagreement vector yields a negative Huber location while the
raw mean and centered signed-rank score are positive. Information set,
median/MAD scale, bounded residual weights, 32 updates, and direction are load
bearing. Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_EXACT_TEN_YEAR_SAME_CALENDAR_FIXED_SCALE_HUBER_LOCATION_SIGN_MONTHLY_RENEWAL`.

## Kill And Safety Boundary

Q02 retires the unchanged candidate at zero trades, below five completed
positions in any full post-warm-up year, with nonpositive governed economics,
or on any label, endpoint, exact-year, median, MAD, scale, weight, iteration,
side, attempt, risk, stop, lifecycle, or determinism defect. No failed result
may be rescued by changing the sample, estimator, tuning, update count,
direction, risk, hold, spread, or retry rules.

Direct WTI adds crude-oil exposure absent from the stated certified book, but
only unchanged Q09 owns realized decorrelation. This approval excludes manual
backtests; live/demo/shadow/stress/optimization setfiles; terminal control;
AutoTrading; `T_Live`; deploy or live manifests; portfolio-gate changes;
portfolio admission; and correlation waivers.
