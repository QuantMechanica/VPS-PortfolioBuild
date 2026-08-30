# WTI Same-Calendar Five-Sample Midhinge — Source Approval

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

- proposed slug: `wti-samecal-midhinge5`
- proposed strategy ID:
  `KELOHARJU-MOP-WTI-SAMECAL-MIDHINGE5-2026_S01`
- proposed source ID: `KELOHARJU-MOP-WTI-SAMECAL-MIDHINGE5-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1
- decision clock: first executable host D1 tick after a genuine normalized
  broker-month transition
- state: midpoint of the fixed lower and upper hinges of the exact prior five
  matching-calendar-month WTI log returns
- lifecycle: follow the midhinge sign for one broker month, with one consumed
  attempt and a 40-calendar-day survivor repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Approved Source Basis And Complete-Read Evidence

The following durable repository records were read completely before this
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
3. The approved governed order-statistic packet
   `strategy-seeds/sources/MOP-WTI-TRIMEAN-2026/source.md`, SHA-256
   `C44845663B3A12C24796E0D5337B23DB54250FF6CB0CE3AA6632BD191D5F8491`,
   last committed as `e2fc269c38d80702d721cbd09543ecfed01bd505`.
   It fixes ascending order-statistic handling and the explicit boundary that
   robust-location arithmetic is a QM mechanization rather than a paper
   result.

The official NIST/SEMATECH *e-Handbook of Statistical Methods*, DOI
`10.18434/M32189`, was also read at its complete "Measures of Location" and
"Box Plot" pages on 2026-08-30. NIST defines lower and upper quartiles as the
25th and 75th percentiles, describes their middle-50% interpretation, and
explains why tail-resistant location summaries are considered for non-normal
or heavy-tailed data. NIST does not prescribe this card's five-item hinge
index convention, the average of the two hinges, or a trading rule. Those are
locked QM choices, not transferred NIST results.

Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar commodity
return information, monthly renewal, a five-year history floor, and explicit
crude-oil membership. Moskowitz, Ooi, and Pedersen supply explicit NYMEX WTI
membership, own-return direction, and monthly renewal. The order-statistic
and NIST records support a transparent middle-50% location construction and
its limitations.

No source tests this exact conjunction. The exact five-year sample, five-item
hinge convention, hinge-only midpoint, single continuous Darwinex CFD,
fixed-dollar risk, ATR stop, spread cap, attempt ledger, and operational
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
3. Sort the five returns ascending as `x[0] <= ... <= x[4]`. Define the
   five-sample hinges and midhinge exactly:

   ```text
   lower_hinge = x[1]
   upper_hinge = x[3]
   location    = (lower_hinge + upper_hinge) / 2
   ```

   Sort once. Do not interpolate, use either extreme, include or double the
   median, select a data-dependent interval, iterate a fitted location, or
   use a fallback center.
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
   ordinary median, trimmed/Winsorized mean, trimean, pseudomedian,
   shortest interval, fitted robust location, or result-conditioned filter.

Exact calendar-year membership, ascending sort, hinge indexes, exclusion of
the median and extremes, divisor two, sign, consumed attempt, fixed risk,
hard stop, and monthly lifecycle are load-bearing.

## Reputable-Source Criteria

- R1 `PASS_WITH_HINGE_ONLY_AND_SINGLE_CFD_TRANSLATION_RISK`: two named-author,
  DOI-bearing, peer-reviewed trading papers with complete-read evidence
  support the same-calendar information object, explicit WTI carrier,
  own-return direction, and monthly renewal. NIST supplies reputable
  quartile, middle-50%, and robust-location context. The exact hinge-only
  trading conjunction remains explicitly untested.
- R2 `PASS`: month clock, label normalization, exact-year endpoints, exact
  five-year sample, ascending sort, hinge indexes, divisor, side, epsilon,
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
`artifacts/qm5_wti_samecal_midhinge5_preallocation_dedup_20260830.json`,
SHA-256
`73AE30B9E4B499FC0D09175B2AC3EF8E95025B27C6620A2FB4203EFE32576802`,
scanned 4,729 registry identities, 1,367 cards, and all 45 current Strategy
Wiki nodes. It found no exact identity and one expected slug-family fuzzy
neighbor, `QM5_20099_wti-samecal`, for mandatory manual review.

Manual executable review establishes non-equivalence:

- Sorted returns `[-6,-4,-3,+5,+5.5]` make this candidate buy from midhinge
  `+0.5`. The full mean is `-0.5`, median `-3`, middle-three mean
  `-0.6666666667`, endpoint-Winsor mean `-0.2`, five-sample trimean `-1.25`,
  and shortest-three midmean `-4.3333333333`; all those siblings sell.
- Sorted returns `[-6,-5,+2,+3,+12]` make this candidate sell from midhinge
  `-1`. The full mean is `+1.2`, median `+2`, and five-sample trimean `+0.5`;
  those siblings buy. The fixed fixture proves that neither the raw mean,
  median, nor trimean determines this card's side.
- `QM5_41055` and `QM5_20099` use an ordinary historical median or raw mean.
  `QM5_41199`, `QM5_41201`, `QM5_41202`, and `QM5_41204` use an equal-weight
  middle-three trim, all fifteen inclusive pair averages, endpoint
  Winsorization, or a ten-sample iterative Huber location. None discards the
  exact median after using it only to establish order.
- `QM5_41227` preserves year order inside overlapping two-year block means;
  `QM5_41228` selects a data-dependent shortest three-value interval; and
  `QM5_41229` gives the median half of the trimean weight. This candidate
  always reads only fixed sorted indexes `1` and `3`, each at one-half.
- `QM5_20283_wti-trimean-mom` consumes twelve adjacent recent months and six
  even-sample order statistics. This candidate consumes five observations of
  one named calendar month across separate exact years and only two odd-sample
  hinges. It is not a horizon parameter port.

Verdict:
`FUZZY_FAMILY_MATCH_RESOLVED_AS_SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_FIXED_MIDHINGE_SIGN_MONTHLY_SLEEVE`.

## Kill And Safety Boundary

Expected cadence is approximately ten to twelve completed WTI positions per
full post-warm-up year. Q02 retires on zero positions, fewer than five in any
full scored year, nonpositive governed economics, wrong normalized endpoints,
missing exact years, wrong sort/hinges/divisor, current-month leakage, wrong
side, repeated entry, missing stop, wrong lifecycle, nondeterminism, invalid
risk mode, or insufficient history. Failure may not be rescued by changing
the sample, statistic, direction, carrier, stop, spread, hold, or retry policy.

The WTI carrier and recurring calendar clock target an exposure outside the
certified XAU/SP500/NDX/XNG set, but they do not prove low correlation. Only
unchanged Q09 may measure realized portfolio overlap.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
if the governed exact-path tester count and whole-host CPU checks pass. At a
ceiling, stop before queue mutation and record a non-live handoff.
