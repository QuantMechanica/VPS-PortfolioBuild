# WTI Same-Calendar Shortest-Half Midmean Seasonality — Source Approval

Date: 2026-08-30

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and one-slot magic allocation, one branch-only non-live build, strict
Q01 validation, and one paced Q02 enqueue if the governed tester and whole-host
CPU ceilings permit. This decision does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy sleeve mission on
branch `agents/board-advisor`. The mission requires one genuinely different,
structural, low-frequency commodity exposure outside the certified
XAU/SP500/NDX/XNG book, requires reputable-source criteria and a
`RISK_FIXED` backtest preset, and excludes live and portfolio-gate work.

## Candidate Identity

- proposed slug: `wti-samecal-shorth5`
- proposed strategy ID:
  `KELOHARJU-MOP-WTI-SAMECAL-SHORTH5-2026_S01`
- proposed source ID: `KELOHARJU-MOP-WTI-SAMECAL-SHORTH5-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1
- decision clock: first executable host D1 tick after a genuine normalized
  broker-month transition
- state: shortest-half midmean of the exact prior five matching-calendar-month
  WTI log returns: sort the five observations, select the narrowest adjacent
  three-value interval, and average its three values
- lifecycle: follow the location sign for one broker month, with one consumed
  attempt and a 40-calendar-day survivor repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Approved Source Basis And Complete-Read Evidence

The following bounded source records and arithmetic reference were read
completely before this decision:

1. Keloharju, Matti; Linnainmaa, Juhani T.; and Nyberg, Peter (2016),
   "Return Seasonalities," *The Journal of Finance* 71(4), 1557-1590,
   DOI `10.1111/jofi.12398`. The complete open NBER Working Paper 20815 is
   represented by
   `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, SHA-256
   `54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0`,
   last committed as `a1dd9e7751f843db82c0b230a46ed7fe6526accd`.
2. Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012),
   "Time Series Momentum," *Journal of Financial Economics* 104(2),
   228-250, DOI `10.1016/j.jfineco.2011.11.003`. The complete-paper review
   record is `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
   last committed as `1c312453ad3a61978bc59c3aa0d3f51153daf93c`.
3. NIST/SEMATECH Dataplot, "Shortest Half Midmean," official statistical
   reference at
   `https://www.itl.nist.gov/div898/software/dataplot/refman2/auxillar/shmm.htm`,
   complete 136-line page read 2026-08-30. It defines the location family as
   the mean of the observations in the most compact half of the sorted sample,
   cites Andrews et al. (1972), Duewer (2008), and Rousseeuw (1985), and warns
   that the statistic has lower efficiency than the median.

Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar commodity
return information, monthly renewal, a five-year history floor, and explicit
crude-oil membership. Moskowitz, Ooi, and Pedersen supply explicit NYMEX WTI
membership, own-return direction, and monthly renewal. NIST supplies an
independent public definition and limitation disclosure for the shortest-half
midmean arithmetic.

No source tests this exact trading conjunction. The shortest-three location,
exact five-year sample, deterministic tie break, single continuous Darwinex
CFD, fixed-dollar risk, ATR stop, spread cap, attempt ledger, and operational
lifecycle are transparent QM falsification choices. No source return,
coefficient, significance, alpha, Sharpe ratio, drawdown, density, cost,
WTI-only result, CFD equivalence, decorrelation, or portfolio result transfers.

## Locked Mechanic

At the first executable `XTIUSD.DWX` D1 tick after a genuine normalized
broker-calendar month transition in `(Y,M)`:

1. Repair malformed owned exposure and close the prior package before
   entry-only gates. Persist broker `yyyymm` before history, signal, news,
   spread, quote, ATR, sizing, or submission; never retry that month.
2. Under one uniform native or `+1` energy D1-label convention, reconstruct
   the completed WTI log return for calendar month `M` in each exact year
   `Y-5..Y-1`. Require strict adjacent-month endpoints, a confirming later
   D1 bar, positive finite closes, and all five returns. Missing or invalid
   history consumes the month flat; no substitute year or shorter sample is
   permitted.
3. Sort the five returns ascending as `x[0] <= ... <= x[4]`. Compute the
   three adjacent three-value spans and select the smallest index attaining
   the minimum. Average exactly that three-value interval:

   ```text
   span[0] = x[2] - x[0]
   span[1] = x[3] - x[1]
   span[2] = x[4] - x[2]
   k = first index in {0,1,2} attaining min(span)
   location = (x[k] + x[k+1] + x[k+2]) / 3
   ```

   Implement the tie rule by initializing `k=0` and replacing it only when a
   later span is strictly smaller. Sort once; do not reorder chronologically,
   average multiple tied windows, or use a midpoint/range substitute.
4. Above `+1e-12`, buy WTI. Below `-1e-12`, sell WTI. Equality inside the
   inclusive epsilon band consumes the month flat. Signal magnitude never
   changes risk.
5. Apply exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`. Attach one frozen `3.5 * ATR(20,D1)` broker hard
   stop, no target, and reject crossed or negative-spread quotes plus a
   genuinely positive spread above 1,500 points.
6. Close at the first later normalized broker-month boundary. A forty-day
   elapsed-calendar guard repairs only a survivor. Close duplicate,
   wrong-symbol, invalid-side, wrong-magic, or stopless owned exposure
   immediately.
7. Lock both current news axes and legacy news mode OFF and disable framework
   Friday flattening because the structural hold spans weekends.
8. Never retry, scale in, pyramid, grid, martingale, optimize, use a raw mean,
   median, trimmed/Winsorized mean, or other fallback center, or add a
   result-conditioned filter.

Exact calendar-year membership, sorting, three fixed adjacent windows,
full-span comparison, earliest-index tie break, selected-triplet divisor,
sign, consumed attempt, fixed risk, hard stop, and monthly lifecycle are
load-bearing.

## Reputable-Source Criteria

- R1 `PASS_WITH_SHORTEST_HALF_AND_SINGLE_CFD_TRANSLATION_RISK`: two
  named-author, DOI-bearing, peer-reviewed trading papers with complete-read
  evidence support the same-calendar information object, explicit WTI
  carrier, own-return direction, and monthly renewal. The official NIST
  reference defines and limits the location arithmetic. The exact conjunction
  remains explicitly untested.
- R2 `PASS`: month clock, label normalization, exact-year endpoints, exact
  five-year sample, ascending sort, three spans, earliest-index tie break,
  divisor, side, epsilon, attempt state, risk, stop, spread, and exits are
  deterministic and locked.
- R3 `PASS_WITH_FIVE_YEAR_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native `XTIUSD.DWX` D1 history plus MT5-native broker time,
  quotes, symbol metadata, positions, deals, and terminal state supply every
  runtime field. History, label, roll, financing, gap, and CFD-basis risks
  remain binding.
- R4 `PASS`: timestamps, completed closes, logarithms, finite arithmetic,
  sorting, comparisons, ATR risk controls, and execution state only; no
  trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_shorth5_preallocation_dedup_20260830.json`,
SHA-256
`1746429DEBD16310E7E5A7A55311DC447CF751EF8D65EF30A1FDEC6A951C4F94`,
scanned 4,727 registry identities, 1,365 cards, and all 45 current Strategy
Wiki nodes. It found no exact identity and one expected slug-family fuzzy
neighbor, `QM5_20099_wti-samecal`, for mandatory manual review.

Manual executable review establishes non-equivalence:

- Sorted returns `[-0.20,-0.19,+0.001,+0.20,+0.21]` have spans
  `[0.201,0.390,0.209]`, so this candidate selects the first interval and
  sells from location `-0.1296666667`. `QM5_20099` buys from full-sample mean
  `+0.0042`; the ordinary individual-return median is `+0.001`; the middle
  three-value trimmed mean is `+0.0036666667`; and endpoint replacement makes
  the five-value Winsorized mean `+0.0042`. The candidate therefore takes the
  opposite side of four existing location families on one fixed fixture.
- On the exact-binary grid
  `[-0.03125,-0.015625,0,+0.015625,+0.03125]`, all three spans equal
  `0.03125`. The locked earliest-window rule selects the first triplet and
  sells from `-0.015625`, while the full mean and individual median are flat.
  This proves the tie rule is executable state, not prose decoration.
- `QM5_41199`, `QM5_41201`, `QM5_41202`, `QM5_41204`, and `QM5_41055`
  use a fixed central trim, all inclusive pair averages, endpoint
  Winsorization, iterative Huber location, or an ordinary sample median.
  None selects a data-dependent narrowest three-return cluster.
- `QM5_41227_wti-samecal-blockmed` preserves chronological order and takes
  the even median of four overlapping adjacent-year pair means. This
  candidate destroys year order after endpoint reconstruction and chooses one
  shortest interval in return space. The state object, order dependency,
  number of retained values, tie behavior, and estimator are different.
- Contiguous WTI shorth/robust-return families, if any, use recent consecutive
  months or within-month daily returns rather than one named calendar month
  across exact separate years. Their information clocks are not substitutes.

Verdict:
`FUZZY_FAMILY_MATCH_RESOLVED_AS_SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_SHORTEST_THREE_MIDMEAN_SIGN_MONTHLY_SLEEVE`.

## Kill And Safety Boundary

Expected cadence is approximately ten to twelve completed WTI positions per
full post-warm-up year. Q02 retires on zero positions, fewer than five in any
full scored year, nonpositive governed economics, wrong normalized endpoints,
missing exact years, wrong sort/window/span/tie/divisor, current-month leakage,
wrong side, repeated entry, missing stop, wrong lifecycle, nondeterminism,
invalid risk mode, or insufficient history. Failure may not be rescued by
changing the sample, window size, statistic, direction, carrier, stop, spread,
hold, or retry policy.

The WTI carrier and recurring calendar clock target an exposure outside the
certified XAU/SP500/NDX/XNG set, but they do not prove low correlation. Only
unchanged Q09 may measure realized portfolio overlap.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
if the governed exact-path tester count and whole-host CPU checks pass. At a
ceiling, stop before queue mutation and record a non-live handoff.
