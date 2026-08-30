# WTI Same-Calendar Exponential-Weight Seasonality - Source Approval

Date: 2026-08-30

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced Q02 enqueue if the active factory remains below its hard CPU
ceiling. Enqueue does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It requests one genuinely new structural,
low-frequency commodity or energy sleeve outside the certified
XAU/SP500/NDX/XNG book, requires reputable-source criteria and
`RISK_FIXED` backtests, and forbids live and portfolio-gate work.

## Candidate Identity

- proposed slug: `wti-samecal-expw4`
- proposed strategy ID:
  `KELOHARJU-MOP-WTI-SAMECAL-EXPW4-2026_S01`
- proposed source ID: `KELOHARJU-MOP-WTI-SAMECAL-EXPW4-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1
- clock: first executable D1 tick after each genuine normalized broker-month
  transition
- state: exponentially recency-weighted mean of up to ten exact prior-year
  WTI log returns for the upcoming calendar month, with at least five valid
  observations and a fixed four-year half-life
- lifecycle: follow the weighted seasonal sign until the next broker month

The atomic governed allocator owns the EA ID. This source decision neither
predicts nor reserves an ID.

## Approved Source Basis And Claim Boundary

Extraction may use only these governed records, read completely after this
approval becomes durable:

1. `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, SHA-256
   `54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0`,
   covering Keloharju, Linnainmaa, and Nyberg (2016), "Return
   Seasonalities," *The Journal of Finance* 71(4), 1557-1590, DOI
   `10.1111/jofi.12398`. It binds the prior-year same-calendar information
   object, crude-oil membership, monthly renewal, and five-year floor.
2. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
   covering Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum,"
   *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. It binds WTI membership, own-return
   direction, and monthly lifecycle, not the same-calendar or decay rule.
3. `strategy-seeds/sources/MOP-WTI-EXPW-2026/source.md`, SHA-256
   `144B72109066D6330875406DAE332A7CFE0C7B878351B75B66B0AA7068459D7C`,
   a governed bounded translation that fixes deterministic base-two
   exponential weighting arithmetic and explicitly records that neither the
   paper nor the packet validates an exact half-life.

No source tests the exact WTI same-calendar/exponential-weight conjunction,
the four-year half-life, a Darwinex continuous CFD, fixed-risk sizing, ATR
stops, spread ceilings, or the current portfolio. No source or sibling return,
alpha, significance, profit factor, drawdown, density, cost, futures/CFD
equivalence, decorrelation, or portfolio result transfers. The decay kernel
is a transparent pre-result QM falsification choice.

## Locked Mechanic

At the first executable `XTIUSD.DWX` D1 tick after a genuine normalized
broker-calendar month transition in `(Y,M)`:

1. Repair owned exposure and persist broker `yyyymm` before every fallible
   entry gate. Never retry that month after any downstream outcome.
2. Under one uniform native or `+1` energy D1-label convention, reconstruct
   completed WTI log returns for calendar month `M` in exact years
   `Y-1..Y-10`. Require strict adjacent-month endpoints and a confirming
   following bar. Missing years are skipped without replacement; no
   current-month price enters the signal. Require at least five observations.
3. For exact year lag `k` in `1..10`, assign calendar age `k-1` and fixed
   weight `w_k = 2^(-(k-1)/4.0)`. A missing year contributes neither return
   nor weight and does not compress later ages.
4. Compute `weighted_mean = sum(w_k*r_k)/sum(w_k)`. Require every included
   weight to be finite and positive, the total weight to be finite and
   positive, and the result to be finite.
5. At `weighted_mean > +1e-12`, buy WTI. At
   `weighted_mean < -1e-12`, sell WTI. Equality or invalid state consumes the
   month flat. Signal magnitude never changes risk.
6. Use one `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
   fixed-risk budget. Attach a frozen `3.5*ATR(20,D1)` hard stop and no target.
7. Reject crossed quotes, negative modeled spread, or genuinely positive
   spread above 1,500 WTI points.
8. Close at the next genuine normalized broker-month boundary; 40 elapsed
   calendar days is survivor repair only.

Both news axes, legacy news mode, and framework Friday close are OFF. There
is no moving average, oscillator, fixed month direction, sample sort, clipping,
rank, sign vote, confidence statistic, current-month input, curve, inventory,
storage, event, volume, optimizer artifact, trained output, banned signal
indicator, or external runtime feed.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_DECAY_AND_SINGLE_CARRIER_CFD_TRANSLATION_RISK`:
  complete DOI-bearing peer-reviewed lineages support recurring
  same-calendar commodity information, explicit crude-oil/WTI membership,
  own-return direction, and monthly renewal; the exact conjunction and
  four-year decay remain untested QM translations.
- R2 `PASS`: calendar, normalized endpoints, exact-year ages, missing-year
  treatment, sample floor, base, exponent, half-life, normalization, side,
  attempt, fixed risk, hard stop, spread, and lifecycle are deterministic and
  locked before Q02.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native WTI D1 history and MT5 state provide every runtime field;
  history, label, roll, financing, gap, and CFD-basis risks remain explicit.
- R4 `PASS`: timestamps, completed prices, logarithms, fixed powers,
  additions, division, comparisons, ATR-risk controls, and execution state
  only; no trained output, banned signal indicator, or external runtime feed.

## Non-Duplicate Decision

The corrected-root canonical checker scanned 4,722 registry identities,
1,360 card files, and all 45 current Strategy Wiki nodes. It found no exact
collision and returned one expected fuzzy neighbor. Receipt:
`artifacts/qm5_wti_samecal_expw4_preallocation_dedup_20260830.json`, SHA-256
`60C966AE7522F051B4FE658923935C253C160CE2D054070D245CC5554FDD760F`.

Manual review fixes the executable boundary:

- `QM5_20099_wti-samecal` gives every available exact prior-year calendar
  return equal weight. This candidate assigns fixed calendar-age decay. For
  recent-to-old returns
  `[-0.04,-0.04,-0.04,+0.03,+0.03,+0.03,+0.03,+0.03,+0.03,+0.03]`,
  the equal mean is `+0.009` and buys, while the locked four-year-half-life
  weighted sum is negative and this candidate sells.
- `QM5_20279_wti-expw-mom` applies a three-month half-life to twelve
  contiguous recent monthly returns. This candidate samples one matching
  calendar month from each prior year, uses calendar-year ages and a four-year
  half-life, and ignores every intervening month.
- `QM5_41204_wti-samecal-huber10` uses equal-calendar-age input followed by
  median/MAD scaling and fixed-step Huber location. This candidate never
  sorts, clips, estimates scale, or iterates; age alone changes influence.
- `QM5_41211_wti-samecal-tstat` uses an equal-weight mean divided by sample
  standard error and can abstain inside a confidence band. This candidate has
  no sample-variance state or confidence gate.
- `QM5_41212_wti-samecal-signscore` discards magnitudes into Bernoulli signs.
  This candidate retains return magnitude and deterministic calendar-age
  decay.

The exact same-calendar sample, uncompressed year ages, four-year exponential
kernel, normalized weighted sign, monthly attempt, and single-WTI carrier are
jointly load bearing. Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_SAMECAL_EXPONENTIAL_YEAR_DECAY_DIRECTION`.

## Kill And Safety Boundary

Q02 retires the unchanged candidate on zero positions, fewer than five
completed positions in any full post-warm-up year, nonpositive governed
economics, or any label, endpoint, age, weight, normalization, side, attempt,
fixed-risk, stop, lifecycle, or determinism defect. A failed result may not be
rescued by changing the sample, half-life, tie rule, direction, carrier, stop,
hold, spread, retry rule, or adding a fallback.

Direct WTI is a genuinely different carrier from the certified
XAU/SP500/NDX/XNG book, but structural distinction does not prove factor or
portfolio independence. Only an unchanged Q09 may judge realized overlap.
This approval excludes manual backtests; live/demo/shadow/stress/optimization
setfiles; terminal control; AutoTrading; `T_Live`; deploy or live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers.
