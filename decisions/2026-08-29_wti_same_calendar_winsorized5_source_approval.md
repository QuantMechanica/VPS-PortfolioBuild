# WTI Five-Year Same-Calendar Winsorized Seasonality - Source Approval

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

- proposed slug: `wti-samecal-win5`
- proposed strategy ID: `KELOHARJU-WINSOR-WTI-SAMECAL5-2026_S01`
- proposed source ID: `KELOHARJU-WINSOR-WTI-SAMECAL5-2026`
- carrier / host: exact `XTIUSD.DWX`, D1, slot 0
- clock: first executable D1 tick after each genuine broker-month transition
- state: exact prior-five-year returns for the upcoming calendar month
- statistic: sort five returns, cap the minimum at the second order statistic
  and the maximum at the fourth, then average all five retained terms
- lifecycle: follow the Winsorized sign until the next month

The atomic governed allocator owns the EA ID. This source decision neither
predicts nor reserves an ID.

## Approved Source Basis And Claim Boundary

The complete bounded packet is
`strategy-seeds/sources/KELOHARJU-WINSOR-WTI-SAMECAL5-2026/source.md`. Its two
peer-reviewed parent packets were read completely and are bound by
`artifacts/qm5_wti_samecal_win5_source_provenance_20260829.json`.

Keloharju, Linnainmaa, and Nyberg (2016), *Journal of Finance* 71(4),
1557-1590, DOI `10.1111/jofi.12398`, supply same-calendar return seasonality,
explicit crude-oil membership, monthly renewal, and a five-year eligibility
floor. The governed Moskowitz, Ooi, and Pedersen (2012), *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`, extraction supplies explicit WTI own-return
lineage and exact fixed-tail Winsorization arithmetic.

Neither source tests the exact conjunction, one-per-tail five-observation
Winsorization, a standalone continuous CFD, the locked execution plumbing, or
the current book. No source economics, significance, density, cost,
futures/CFD equivalence, or decorrelation result transfers.

## Locked Mechanic

On the first executable `XTIUSD.DWX` D1 tick after a genuine broker-calendar
month transition in `(Y,M)`:

1. Repair prior owned exposure and persist `yyyymm` before every fallible gate.
   No flat, rejected, failed, stopped, or restarted outcome retries.
2. Under one uniform native or `+1` energy D1-label convention, reconstruct
   exactly the completed log return for calendar month `M` in each year
   `Y-1` through `Y-5`; require strict endpoints and all five exact years.
3. Sort the five finite returns `s[0] <= ... <= s[4]`, replace `s[0]` with
   `s[1]` and `s[4]` with `s[3]`, and calculate
   `(2*s[1] + s[2] + 2*s[3]) / 5`.
4. BUY above `+1e-12`, SELL below `-1e-12`, and consume flat otherwise.
5. Use one `RISK_FIXED=1000` position with a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point positive-spread
   ceiling.
6. Close at the next broker-month boundary; 35 elapsed days is repair only.

Both news axes, legacy news mode, and framework Friday close are OFF. There is
no raw mean/median/trim/pseudomedian fallback, trend, fixed-month direction,
oscillator, inventory, event, curve, volume, optimizer artifact, or external
runtime feed.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_ESTIMATOR_AND_CFD_TRANSLATION_RISK`: two complete
  peer-reviewed lineages support the information object, WTI carrier, and
  governed Winsorization arithmetic; the exact conjunction remains untested.
- R2 `PASS`: exact years, endpoints, sort, replacement indexes, five-term
  divisor, sign band, attempt, risk, stop, spread, and lifecycle are locked.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`: registered
  native `XTIUSD.DWX` D1 and MT5-native state provide every runtime field.
- R4 `PASS`: deterministic date, log-return, sort, fixed replacement,
  comparison, ATR-risk, and execution arithmetic only; no trained output,
  banned signal indicator, external feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,701 registry identities, 1,347 cards, and all
45 current Strategy Wiki nodes. It found no exact collision and surfaced five
expected same-calendar fuzzy neighbors. Receipt:
`artifacts/qm5_wti_samecal_win5_preallocation_dedup_20260829.json`, SHA-256
`6D713EC4B7A3D231EE05D483C4D706E7B69727ECB3F6F7034945B2052BBF3448`.

Manual review establishes functional non-equivalence:

- `QM5_20099`, `QM5_41055`, `QM5_41059`, and `QM5_41191` use respectively a
  raw mean, raw median, positive-hit rule, and ten-year signed-rank score.
- `QM5_41199` deletes the same five-return sample's minimum and maximum and
  averages only three observations. This rule retains five terms and caps,
  rather than deletes, each extreme, giving the second and fourth order
  statistics two weights apiece.
- `QM5_41201` expands the five observations into fifteen inclusive pair
  averages and selects their central order statistic.
- `QM5_20277` Winsorizes two observations per tail from twelve contiguous
  recent monthly returns. It neither uses exact same-calendar years nor the
  one-per-tail five-term statistic.

For `[-12,-11,3,9,10]`, this rule is `-0.2` while the middle-three trimmed
mean is `+1/3`, the median is `+3`, and three of five returns are positive.
For `[-12,-9,3,8,9]`, this rule is `+0.2` while the raw mean is `-0.2` and
the fifteen-pair Hodges-Lehmann central value is `-0.5`. The cap, retained
weights, divisor, information set, and direction are therefore load bearing.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_ONE_TAIL_WINSORIZED_MEAN_SIGN_MONTHLY_RENEWAL`.

## Kill And Safety Boundary

Q02 retires at zero trades, fewer than five completed positions in any full
post-warm-up year, nonpositive governed economics, or any label, endpoint,
exact-year, sort, replacement, weight, divisor, sign, attempt, risk, stop,
lifecycle, or determinism defect. No failed result may be rescued by changing
years, tail count, estimator, direction, risk, hold, spread, or retry rules.

Direct WTI adds crude-oil exposure absent from the stated certified book, but
only unchanged Q09 owns realized decorrelation. This approval excludes manual
backtests; live/demo/shadow/stress/optimization setfiles; terminal control;
AutoTrading; `T_Live`; deploy or live manifests; portfolio-gate changes;
portfolio admission; and correlation waivers.
