# XNG Same-Calendar Bernoulli Sign-Score Seasonality - Source Approval

Date: 2026-08-30

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced Q02 enqueue if the active factory remains below its hard CPU
ceiling. Enqueue does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It asks for one genuinely new structural,
low-frequency commodity or energy sleeve, explicitly permits a second XNG
edge only when its logic differs from `QM5_12567`, requires reputable-source
criteria and `RISK_FIXED` backtests, and forbids live and portfolio-gate work.

## Candidate Identity

- proposed slug: `xng-samecal-signscore`
- proposed strategy ID:
  `KELOHARJU-PAPAILIAS-RCORE-XNG-SAMECAL-SIGNSCORE-2026_S01`
- proposed source ID:
  `KELOHARJU-PAPAILIAS-RCORE-XNG-SAMECAL-SIGNSCORE-2026`
- host / slot 0: exact `XNGUSD.DWX`, D1
- clock: first executable D1 tick after each genuine normalized broker-month
  transition
- state: nonnegative count across up to ten exact prior-year XNG log returns
  for the upcoming calendar month, with at least five observations
- statistic: signed one-sample Bernoulli score against null probability 0.5
- lifecycle: follow only a sign imbalance outside a strict one-standard-error
  abstention band until the next broker month

The atomic governed allocator owns the EA ID. This source decision neither
predicts nor reserves an ID.

## Approved Source Basis And Claim Boundary

Extraction may use only these completely read governed records:

1. `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, SHA-256
   `54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0`,
   covering Keloharju, Linnainmaa, and Nyberg (2016), "Return
   Seasonalities," *The Journal of Finance* 71(4), 1557-1590, DOI
   `10.1111/jofi.12398`, including the complete 57-page NBER review. It
   explicitly includes natural-gas futures and governs the same-calendar
   information object, monthly renewal, and five-year floor.
2. `strategy-seeds/sources/PAPAILIAS-RSM-2021/source.md`, SHA-256
   `5EFDB021EE4D1B00A2D7CE356A5EACA85511896C4FD999A5B069B5F936ABA32F`,
   covering Papailias, Liu, and Thomakos (2021), "Return Signal Momentum,"
   *Journal of Banking & Finance* 124, 106063, DOI
   `10.1016/j.jbankfin.2021.106063`, including the complete accepted
   manuscript and appendices. It explicitly includes natural gas and
   supplies the nonnegative-return binary map, equal sign weighting, and
   monthly lifecycle.
3. The complete governed arithmetic packet
   `strategy-seeds/sources/KELOHARJU-PAPAILIAS-RCORE-WTI-SAMECAL-SIGNSCORE-2026/source.md`,
   SHA-256
   `147874FE17B0531E02E49AD5D97910EA47B0CD6F0FA88E2811EEF52B009E9795`,
   and its provenance record
   `artifacts/qm5_wti_samecal_signscore_source_provenance_20260830.json`,
   SHA-256
   `4E82FE44A3DBBFEFFEEB214649E2EC0BB27FF7EED35E31CA13FCDBC267DBB13C`.
   That record binds the complete read of R Core `prop.test.R` at commit
   `9deb2ebef8d0a2fe5cae965697ee4751af857bd1`, blob
   `fc38bd4be1ba8630dbd224162ab5873ae6ac5261`, and the official manual.

No source tests this exact XNG same-calendar sign-score conjunction, the
strict score band, a Darwinex continuous CFD, fixed-risk sizing, ATR stops,
spread ceilings, or the current portfolio. No source or sibling return,
alpha, significance, profit factor, drawdown, density, cost, futures/CFD
equivalence, decorrelation, or portfolio result transfers. The locked
`abs(score)>1` rule is a QM falsification threshold, not a conventional
significance claim; runtime never computes a p-value.

## Locked Mechanic

At the first executable `XNGUSD.DWX` D1 tick after a genuine normalized
broker-calendar month transition in `(Y,M)`:

1. Repair owned exposure and persist broker `yyyymm` before every fallible
   entry gate. Never retry that month after any downstream outcome.
2. Under one uniform native or `+1` energy D1-label convention, reconstruct
   completed XNG log returns for calendar month `M` in exact years
   `Y-1..Y-10`. Require strict adjacent-month endpoints and a confirming
   following bar. Missing older years are skipped without replacement; no
   current-month price enters the signal. Require at least five observations.
3. Map every finite return to `1` when nonnegative and `0` when negative. Let
   `x` be the nonnegative count and `n` the valid observation count.
4. With null `p0=0.5` and no continuity correction, compute the signed score
   `z=(x-n*p0)/sqrt(n*p0*(1-p0))=(2*x-n)/sqrt(n)`. Require integer
   `0<=x<=n`, a finite positive denominator, and a finite score.
5. At `z > +1.0 + 1e-10`, buy XNG. At `z < -1.0 - 1e-10`, sell XNG.
   Equality, the inclusive interior band, or invalid state consumes the month
   flat. Score magnitude never changes risk.
6. Use one `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
   fixed-risk budget. Attach a frozen `3.5*ATR(20,D1)` hard stop and no target.
7. Reject crossed quotes, negative modeled spread, or genuinely positive
   spread above 3,000 XNG points.
8. Close at the next genuine normalized broker-month boundary; 40 elapsed
   calendar days is survivor repair only.

Both news axes, legacy news mode, and framework Friday close are OFF. There
is no p-value lookup, continuity correction, magnitude mean, sample variance,
rank weight, median, Huber fallback, current-month input, contrarian flip,
magnitude sizing, curve, inventory, storage, weather, event, volume,
optimizer artifact, trained output, banned signal indicator, or external
runtime feed.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_STATISTIC_SINGLE_CARRIER_SMALL_SAMPLE_AND_CFD_TRANSLATION_RISK`:
  complete-read, DOI-bearing peer-reviewed lineages support recurring
  same-calendar commodity information, explicit natural-gas membership, and
  binary-return representation; commit-pinned primary software fixes the
  score arithmetic. The exact conjunction and threshold remain untested.
- R2 `PASS`: calendar, normalized endpoints, exact-year bound, sample floor,
  binary map, null, denominator, strict band, side, attempt, fixed risk, hard
  stop, spread, and lifecycle are deterministic and locked before Q02.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native XNG D1 history and MT5 state provide every runtime field;
  history, label, roll, financing, gap, and CFD-basis risks remain explicit.
- R4 `PASS`: timestamps, completed prices, logarithms, integer counts, square
  root, comparisons, ATR-risk controls, and execution state only; no trained
  output, banned signal indicator, or external runtime feed.

## Non-Duplicate Decision

The corrected-root canonical checker scanned 4,713 registry identities,
1,359 card files, and all 45 current Strategy Wiki nodes. It found no exact
collision and returned three expected fuzzy neighbors. Receipt:
`artifacts/qm5_xng_samecal_signscore_preallocation_dedup_20260830.json`,
SHA-256
`F6E5C50549A7A43C7BD047CAA44303A699F2DDF139ACD599EBD5090CFFD80AF4`.

Manual review fixes the executable boundary:

- `QM5_20100_xng-samecal` averages metric XNG returns and follows every
  nonzero mean. This candidate discards magnitude and may stay flat inside a
  sample-size-aware binary-sign band. For
  `[0.09,-0.01,-0.01,-0.01,-0.01]`, the raw mean is positive and the sibling
  buys; this candidate has `z=-3/sqrt(5)<-1` and sells.
- `QM5_41205_xng-samecal-huber10` retains metric distances through an even
  median, MAD scale, and fixed-step Huber location. This candidate reduces
  every observation to an equal-weight Bernoulli outcome and standardizes
  against fixed null variance. Outlier magnitude cannot change its signal.
- `QM5_12567_cum-rsi2-commodity` uses a short-horizon cumulative-RSI(2)
  pullback under a long trend context and short holding lifecycle. This
  candidate has no RSI, oscillator, contiguous pullback, or intramonth
  renewal; its only decision is an exact prior-year calendar sign count once
  per month.
- `QM5_41212_wti-samecal-signscore` supplies the same transparent statistic
  but observes and owns crude oil. It cannot read or trade XNG. The candidate
  is an explicitly permitted governed carrier/mechanic combination, not a
  claim to a globally new anomaly family.
- `QM5_41213_xauxag-samecal-signscore` observes synchronized relative
  gold-minus-silver returns and owns two opposite metal legs. It cannot
  express a single-gas directional state.

The exact XNG information object, null-variance abstention rule, monthly
attempt state, and single-gas position jointly change direction,
participation, and exposure relative to the incumbent XNG logic. They are
load bearing rather than a slug or parameter rename.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XNG_SAMECAL_BERNOULLI_SIGN_SCORE_GATE_MONTHLY_DIRECTIONAL_CARRIER`.

## Kill And Safety Boundary

Q02 retires the unchanged candidate on zero positions, fewer than five
completed positions in any full post-warm-up year, nonpositive governed
economics, or any label, endpoint, sample, sign-map, null, score, threshold,
side, attempt, fixed-risk, stop, lifecycle, or determinism defect. A failed
result may not be rescued by changing the sample, threshold, tie map,
direction, carrier, stop, hold, spread, retry rule, or adding a fallback.

The seasonal XNG clock is structurally different from the certified daily
pullback sleeve but does not prove factor or portfolio independence. Only an
unchanged Q09 may judge realized overlap. This approval excludes manual
backtests; live/demo/shadow/stress/optimization setfiles; terminal control;
AutoTrading; `T_Live`; deploy or live manifests; portfolio-gate changes;
portfolio admission; and correlation waivers.
