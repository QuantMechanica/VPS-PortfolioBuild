# WTI Monthly Signed-Rank Trend - Source Approval

Date: 2026-09-01

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced Q02 enqueue. Enqueue does not authorize manual tester execution or
work above the active whole-host CPU ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It asks for exactly one new structural,
low-frequency commodity or energy edge outside the certified
XAU/SP500/NDX/XNG book, identifies direct WTI trend or seasonality as eligible,
requires reputable-source criteria and `RISK_FIXED` backtests, and excludes
the portfolio gate, live manifests, `T_Live`, and AutoTrading.

## Candidate Identity

- proposed slug: `wti-msigned-rank-tr`
- proposed strategy ID:
  `AI-CODEX-WTI-MSIGNED-RANK-TREND-20260901_S01`
- proposed source ID: `AI-CODEX-WTI-MSIGNED-RANK-TREND-20260901`
- proposed symbol / host: exact `XTIUSD.DWX`, D1, slot 0
- decision clock: first executable tick after a genuine broker-month
  transition
- signal: direction of the centered one-sample signed absolute-rank score over
  the latest twelve consecutive completed WTI monthly log returns, admitted
  only at inclusive `|S| >= 18`

The deterministic registry owns the EA ID. This source decision neither
predicts nor reserves an identity.

## Approved Source Basis

The following bounded records were read completely before this decision:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
   It preserves a complete 23-page read of Moskowitz, Ooi, and Pedersen
   (2012), *Time Series Momentum*, *Journal of Financial Economics* 104(2),
   228-250, DOI `10.1016/j.jfineco.2011.11.003`. The record documents monthly
   own-return continuation through twelve lags, defines sign-based monthly
   trend positions, and identifies NYMEX WTI in the commodity universe.
2. `strategy-seeds/sources/KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026/source.md`,
   SHA-256
   `57FF7096210C5E48A7236DAD6799A3E6CE706E726BD704416064D5A803D10B98`.
   This approved complete-read method packet preserves the pinned R Core Team
   `stats` implementation and manual evidence for the one-sample signed-rank
   statistic at R source commit
   `bac583951b728e97b9786804d3b4081f0fe18df5`: rank `abs(x-mu)` and sum the
   ranks attached to positive observations. The parent receipt records all
   1,137 implementation lines and all 262 manual lines as read, with blob and
   SHA-256 identities.
3. `decisions/2026-08-28_wti_same_calendar_signed_rank_source_approval.md`,
   SHA-256
   `2663F9C9D1A36A1101F7C0C7780196E0F1E1FEB574AD6CA28B269DE2E01FB501`.
   It fixes the method evidence boundary: the R record supplies arithmetic,
   not trading efficacy, and the original Wilcoxon article body is not
   represented as read.

No newly routed generic webpage is used. The deterministic public-source
router returned `DEFERRED:SOURCE_POLICY` for exploratory generic NIST and DOI
routes, so their snippets, bodies, and claims are excluded from this source
decision.

Moskowitz, Ooi, and Pedersen do not test this WTI-only signed-rank filter. R
Core defines the statistic but does not claim return predictability. The
continuous CFD, twelve-return sample, zero and absolute-tie rejection,
inclusive score boundary, fixed-dollar risk, stop, spread ceiling, consumed
attempt, and lifecycle are transparent pre-result QM choices. No source
return, alpha, p-value, probability, density, drawdown, cost, CFD equivalence,
decorrelation, or portfolio result transfers.

## Locked Mechanic

At the first executable `XTIUSD.DWX` D1 tick after a genuine broker-month
transition:

1. Persist the current broker `yyyymm` before every fallible entry gate. One
   month may produce at most one consumed attempt.
2. Exclude the current month. Reconstruct thirteen consecutive completed
   broker-month-end closes and the twelve adjacent log returns from the oldest
   endpoint to the newest.
3. Require every endpoint and return finite, every close positive, every
   return nonzero beyond `1e-12`, and every pair of absolute returns distinct
   beyond `1e-12`. Invalid state consumes the month flat; there is no zero or
   average-rank convention.
4. Rank absolute returns from 1 (smallest) through 12 (largest). Compute
   `V_plus` as the sum of ranks whose original return is positive,
   `T=12*13/2=78`, and centered score `S=2*V_plus-T`. Require the rank sum to
   equal 78 and `-78 <= S <= 78`.
5. BUY only when `S >= 18`; SELL only when `S <= -18`; otherwise consume the
   month flat. Score magnitude never changes risk.
6. Open at most one position under `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`, sized against one frozen `3.5*ATR(20,D1)` broker hard
   stop. Attach no target and reject a genuinely positive entry spread above
   1,500 points.
7. Close on the first tick in a later broker month or after forty elapsed
   calendar days. Immediately repair duplicate, wrong-symbol, wrong-magic,
   invalid-volume, or stopless owned exposure.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered MT5 D1 OHLC/timestamps, broker time, quotes, contract metadata,
positions, deals, terminal global variables, and V5 framework services.

## Exact Activity Boundary

With strict ranks 1 through 12, enumerate all `2^12=4,096` sign assignments.
Exactly 1,062 assignments have `S>=18` and 1,062 have `S<=-18`, for total
support `2,124/4,096 = 0.5185546875`. At twelve monthly attempts this is a
market-free prior of 6.22265625 qualified states per year before history,
ties, market, sizing, or execution gates. This is an activity design bound,
not a WTI probability, p-value, critical value, or performance result.

Q02 must retire zero-trade output or fewer than five completed positions in
any full post-warm-up calendar year.

## Non-Duplicate Decision

The fail-closed canonical checker scanned 4,772 registry identities, 1,408
card files, and 45 Strategy Wiki nodes. It found no exact or above-threshold
fuzzy identity. Evidence:
`artifacts/qm5_wti_msigned_rank_tr_preallocation_dedup_20260901.json`,
SHA-256
`AE49BB417E6B8D35EEFBF8EA86FB6B3E1C3786ADACAF62FA6AA2F51EADBCE337`.

Manual semantic review resolves the closest families:

- `QM5_41191_wti-samecal-srank` ranks five-to-ten disjoint observations for
  the upcoming calendar month in prior years and trades every nonzero score.
  This candidate ranks exactly twelve contiguous latest monthly returns and
  requires `|S|>=18`. The history set and admission boundary are both
  load-bearing.
- `QM5_12603_wti-tsmom12m` uses the sign of one metric twelve-month cumulative
  return. For eleven positive returns `.01` through `.11` and one return
  `-1.00`, this candidate has `S=54` and buys while the cumulative return is
  `-0.34` and the pure return-sign rule sells. Negating the vector proves the
  reverse disagreement.
- A zero-threshold contiguous signed-rank rule would buy at `S=2` when only
  absolute ranks `{7,10,11,12}` are positive and all others are negative;
  this candidate consumes that month flat. The exact `18` boundary is not a
  label-only variant.
- A positive-observation count can disagree: seven small positive ranks
  `1..7` versus five larger negative ranks `8..12` gives a positive sign
  majority but `S=-22`, so this candidate sells.
- Certified `QM5_12567_cum-rsi2-commodity` is a two-day long-only XNG
  oscillator pullback and shares neither the WTI carrier, monthly information
  set, signed-rank functional, nor symmetric lifecycle.

Verdict:
`DISTINCT_WTI_MONTHLY_TWELVE_CONTIGUOUS_STRICT_SIGNED_ABSOLUTE_RANK_SCORE_ABS18_CONTINUATION`.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_SOURCE_AND_CONTINUOUS_CFD_TRANSLATION_RISK`: a
  complete-read peer-reviewed WTI trend lineage plus complete pinned primary
  software arithmetic. The exact conjunction is disclosed as untested.
- R2 `PASS`: month clock, endpoints, returns, zero/tie rule, strict ranks,
  centered score, inclusive threshold, side, attempt, risk, stop, spread, and
  lifecycle are deterministic and locked before Q02.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history plus MT5-native state supplies every runtime input;
  futures-to-CFD roll, basis, financing, and gap risks remain falsification
  risks.
- R4 `PASS`: deterministic timestamps, logarithms, sorting, comparisons,
  integer arithmetic, ATR risk controls, and execution state only; no trained
  output, banned signal indicator, external runtime feed, grid, martingale,
  scale-in, or pyramid.

## Kill And Safety Boundary

Retire or fail on any month, endpoint, return, zero/tie, rank, score, side,
attempt, fixed-risk, stop, lifecycle, or determinism defect; fewer than five
completed positions in any full post-warm-up year; zero trades; nonpositive
governed economics; or any downstream gate failure. No failed result may be
rescued by changing the sample, statistic, threshold, carrier, direction,
risk, hold, spread cap, or by adding another filter.

Direct WTI supplies crude-oil exposure absent from the stated
XAU/SP500/NDX/XNG book, but it does not prove factor or portfolio
decorrelation. Unchanged Q09 alone owns overlap. This approval excludes manual
backtests; optimization; live, demo, shadow, and stress presets; AutoTrading;
`T_Live`; deploy or live manifests; portfolio-gate changes; portfolio
admission; correlation waivers; and terminal control.
