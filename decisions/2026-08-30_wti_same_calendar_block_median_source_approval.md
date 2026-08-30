# WTI Same-Calendar Rolling Two-Year Block-Median Seasonality — Source Approval

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

- proposed slug: `wti-samecal-blockmed`
- proposed strategy ID:
  `KELOHARJU-MOP-WTI-SAMECAL-BLOCKMED-2026_S01`
- proposed source ID: `KELOHARJU-MOP-WTI-SAMECAL-BLOCKMED-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1
- decision clock: first executable host D1 tick after a genuine normalized
  broker-month transition
- state: the even median of four rolling chronological two-year means formed
  from the exact prior five matching-calendar-month WTI log returns
- lifecycle: follow the block-median sign for one broker month, with one
  consumed attempt and a 40-calendar-day survivor repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Approved Source Basis And Complete-Read Evidence

The following bounded source records were read completely before this
decision:

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
3. The already governed block-aggregation boundary is
   `strategy-seeds/sources/MOP-WTI-BLOCKMED-2026/source.md`, SHA-256
   `427CEDFC797791818811265DD5054478BCC2BBB7AB8C6D582C550D140D0BE347`,
   last committed as `c67c543eff9dca0e6d919590b39b444bb4f70199`.

Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar commodity
return information, monthly renewal, a five-year history floor, and explicit
crude-oil membership. Moskowitz, Ooi, and Pedersen supply explicit NYMEX WTI
membership, own-return direction, and monthly renewal. The third packet
records a pre-result QM convention for retaining magnitude inside fixed
chronological blocks and taking only the central block location.

No paper tests this exact conjunction. The four overlapping two-year means,
their even median, the exact five-year sample, the continuous Darwinex CFD,
fixed-dollar
risk, ATR stop, spread cap, attempt ledger, and operational lifecycle are
transparent QM falsification choices. No source return, coefficient,
significance, alpha, Sharpe ratio, drawdown, density, cost, WTI-only result,
CFD equivalence, decorrelation, or portfolio result transfers.

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
3. Order the five returns chronologically from `Y-5` through `Y-1`. Form four
   immutable rolling two-year arithmetic means, sort only those four means,
   and average the two central values:

   ```text
   b[0] = (r[Y-5] + r[Y-4]) / 2
   b[1] = (r[Y-4] + r[Y-3]) / 2
   b[2] = (r[Y-3] + r[Y-2]) / 2
   b[3] = (r[Y-2] + r[Y-1]) / 2
   s = sort_ascending(b)
   location = (s[1] + s[2]) / 2
   ```

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
8. Never retry, scale in, pyramid, grid, martingale, optimize, use a full-sample
   mean or individual-return median fallback, or add a result-conditioned
   filter.

Exact calendar-year membership, overlapping chronological pairing, two-return
divisors, sorting only the four rolling means, even-median indexes one and two,
sign, consumed attempt, fixed risk, hard stop, and monthly lifecycle are
load-bearing.

## Reputable-Source Criteria

- R1 `PASS_WITH_BLOCK_AGGREGATION_AND_CFD_TRANSLATION_RISK`: two named-author,
  DOI-bearing, peer-reviewed trading papers with complete-read evidence
  support the same-calendar information object, explicit WTI carrier,
  own-return direction, and monthly renewal. The exact block statistic is
  disclosed as untested.
- R2 `PASS`: month clock, label normalization, exact-year endpoints,
  exact five-year sample, rolling-pair membership, divisors, median indexes,
  side, epsilon,
  attempt state, risk, stop, spread, and exits are deterministic and locked.
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
`artifacts/qm5_wti_samecal_blockmed_preallocation_dedup_20260830.json`,
SHA-256
`25B7F707486998A95E9909EABA1D88DF42587F8439541E43080A1573EBE3C871`,
scanned 4,726 registry identities, 1,364 cards, and all 45 current Strategy
Wiki nodes. It found no exact identity and one expected slug-family fuzzy
neighbor, `QM5_20099_wti-samecal`, for mandatory manual review.

Manual executable review establishes non-equivalence:

- `QM5_20099_wti-samecal` takes the arithmetic mean of all valid historical
  returns and permits five through ten values. For chronological returns
  `[-0.10,-0.10,+0.001,+0.10,+0.001]`, the rolling means are
  `[-0.10,-0.0495,+0.0505,+0.0505]`. This candidate buys from the `+0.0005`
  even block median while 20099 sells from the `-0.0196` full-sample mean.
- `QM5_41055_wti-medcal` sorts individual annual returns. For chronological
  returns `[-0.10,-0.10,+0.001,+0.001,+0.001]`, that EA buys from the
  `+0.001` individual-return median while this candidate sells from the
  `-0.02425` even median of rolling means
  `[-0.10,-0.0495,+0.001,+0.001]`.
- `QM5_20287_wti-blockmed-mom` forms four non-overlapping three-month blocks
  from twelve consecutive recent returns. This candidate forms four
  overlapping two-year means from five observations of one named calendar
  month across separate years. Their endpoint set, overlap, block width,
  sample clock, and seasonal versus contiguous-trend hypotheses differ.
- `QM5_41199`, `QM5_41201`, `QM5_41202`, and `QM5_41204` trim, take a
  Hodges-Lehmann pseudomedian, winsorize, or iteratively Huber-weight
  individual same-calendar returns; none preserves the four rolling two-year
  means and selects their even median.
- `QM5_41223_wti-samecal-expw4` applies fixed recency weights to four annual
  returns. `QM5_41224_wti-samecal-regimeshift` requires ten annual returns
  and trades only when recent and older five-year means oppose. This candidate
  uses exactly five returns and has neither recency weights nor a block-sign
  disagreement gate.

Verdict:
`FUZZY_FAMILY_MATCH_RESOLVED_AS_SEMANTICALLY_DISTINCT_EXACT_FIVE_YEAR_SAME_CALENDAR_FOUR_ROLLING_TWO_YEAR_MEAN_EVEN_MEDIAN_WTI_MONTHLY_SLEEVE`.

## Kill And Safety Boundary

Expected cadence is approximately ten to twelve completed WTI positions per
full post-warm-up year. Q02 retires on zero positions, fewer than five in any
full scored year, nonpositive governed economics, wrong normalized endpoints,
missing exact years, wrong chronological pairing, incorrect divisors or
median, current-month leakage, wrong side, repeated entry, missing stop,
wrong lifecycle, nondeterminism, invalid risk mode, or insufficient history.
Failure may not be rescued by changing the sample, blocks, statistic,
direction, carrier, stop, spread, hold, or retry policy.

The WTI carrier and recurring calendar clock target an exposure outside the
certified XAU/SP500/NDX/XNG set, but they do not prove low correlation. Only
unchanged Q09 may measure realized portfolio overlap.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
if the governed exact-path tester count and whole-host CPU checks pass. At a
ceiling, stop before queue mutation and record a non-live handoff.
