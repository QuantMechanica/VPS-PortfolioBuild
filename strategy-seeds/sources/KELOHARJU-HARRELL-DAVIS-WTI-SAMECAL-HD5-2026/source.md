---
source_id: KELOHARJU-HARRELL-DAVIS-WTI-SAMECAL-HD5-2026
source_type: governed_composite_peer_reviewed_and_author_maintained_numerical_implementation
status: cards_ready
created: 2026-08-30
created_by: Research+Development
source_approval: decisions/2026-08-30_wti_same_calendar_harrell_davis5_source_approval.md
---

# WTI Exact-Five-Year Same-Calendar Harrell-Davis Median Source Packet

## Approval And Extraction Boundary

The durable source approval is
`decisions/2026-08-30_wti_same_calendar_harrell_davis5_source_approval.md`,
committed as `3c278ece5` before this extraction. It authorizes exactly one
structural, low-frequency, single-WTI Strategy Card and non-live build under
the current OWNER commodity/energy portfolio mission.

This packet joins three bounded ideas:

1. recurring same-calendar commodity return information;
2. WTI own-return direction with monthly renewal; and
3. the Harrell-Davis distribution-free quantile estimator at the median,
   reduced to exact fixed weights for a five-observation sample.

No source tests the conjunction. It is a falsifiable QM implementation
hypothesis, not a source-reported WTI strategy result.

## Completely Read Source Records

### 1. Keloharju, Linnainmaa, and Nyberg (2016)

Keloharju, Matti; Linnainmaa, Juhani T.; and Nyberg, Peter, "Return
Seasonalities," *The Journal of Finance* 71(4), 1557-1590, DOI
`10.1111/jofi.12398`.

The complete 57-page open NBER Working Paper 20815 review is preserved at
`strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, SHA-256
`54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0`.
That governed record was read completely for this extraction.

The usable findings are bounded:

- the paper tests recurring returns in the same calendar month;
- its commodity universe explicitly contains crude oil;
- its portfolio construction requires at least five years of history;
- it renews the seasonal ranking monthly; and
- its evidence is a broad cross-section, not a standalone WTI CFD result.

The source uses a longer history when available and ranks many futures. The
exact-five-year WTI-only estimated-median sign port below is not a replication.

### 2. Moskowitz, Ooi, and Pedersen (2012)

Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje, "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

The complete published-paper review is preserved at
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
That governed record was read completely for this extraction.

The usable findings are bounded:

- Appendix A explicitly includes NYMEX WTI crude oil;
- the trading family maps an instrument's own completed return sign to the
  following holding period;
- the source tests monthly formation and holding periods; and
- the reported evidence pools commodities and does not establish a WTI-only
  continuous-CFD result.

Only carrier membership, own-return orientation, and the monthly lifecycle
transfer. Volatility scaling, pooled performance, and source return numbers do
not transfer.

### 3. Harrell and Davis (1982)

Harrell, Frank E.; and Davis, C. E., "A New Distribution-Free Quantile
Estimator," *Biometrika* 69(3), 635-640, DOI
`10.1093/biomet/69.3.635`.

The Oxford Academic publisher record and abstract were read completely on
2026-08-30:
`https://academic.oup.com/biomet/article/69/3/635/221346`.
They establish the named estimator as a linear combination of order
statistics and identify the peer-reviewed article, authors, volume, pages,
date, and DOI. The full paper is paywalled; this packet does not claim a full-
paper read or import its efficiency conclusions.

### 4. Author-Maintained Hmisc Documentation And Source

Frank Harrell's `Hmisc` documentation for `hdquantile` and the complete
relevant implementation body in `R/Misc.s` were read on 2026-08-30:

- `https://search.r-project.org/CRAN/refmans/Hmisc/html/hdquantile.html`
- `https://github.com/harrelfe/Hmisc/blob/master/R/Misc.s`

The documentation defines the estimator as a weighted linear combination of
order statistics and cites Harrell and Davis (1982). The implementation fixes
the numerical convention:

```text
m = n + 1
a = p*m
b = (1-p)*m
A_j = I_(j/n)(a,b), j=0..n
w_i = A_i - A_(i-1), i=1..n
Q_HD(p) = sum(i=1..n, w_i * x_(i))
```

Here `I_z(a,b)` is the regularized beta CDF and `x_(i)` are ascending order
statistics. The candidate uses only `n=5` and `p=0.5`; no runtime library or
general incomplete-beta routine is required.

## Exact Five-Observation Reduction

For `n=5`, `p=0.5`, `m=6`, the beta parameters are exactly `a=b=3`. The
regularized beta CDF is the elementary polynomial:

```text
I_z(3,3) = 10*z^3 - 15*z^4 + 6*z^5
```

Evaluating it at the fixed fifths and differencing adjacent values gives:

```text
A = [0, 0.05792, 0.31744, 0.68256, 0.94208, 1]
w = [0.05792, 0.25952, 0.36512, 0.25952, 0.05792]
  = [181, 811, 1141, 811, 181] / 3125
```

For sorted returns `s[0] <= ... <= s[4]`, the exact candidate statistic is:

```text
hd_median = (181*s[0] + 811*s[1] + 1141*s[2]
             + 811*s[3] + 181*s[4]) / 3125
```

The implementation computes this rational form and independently computes
the five decimal weights. The two results must agree within `1e-12`. Every
weight is positive, the weights sum exactly to one, and sign reflection of
all inputs reverses the statistic. These invariants are executable reference
tests, not adjustable parameters.

This estimator is neither:

- the arithmetic mean, whose five weights are all `0.2`;
- the ordinary median, whose center weight is one;
- the middle-three trimmed mean, whose central weights are `1/3` each;
- the endpoint-Winsorized mean, whose sorted weights are
  `[0,0.4,0.2,0.4,0]`;
- Tukey's trimean, whose central weights are `[0,0.25,0.5,0.25,0]`;
- the midhinge, whose central weights are `[0,0.5,0,0.5,0]`;
- the Gastwirth five-sample reduction, whose central weights are
  `[0,0.2,0.6,0.2,0]`; or
- a pseudomedian, shortest interval, chronological block statistic, Huber or
  bisquare iteration, MAD-capped mean, or sign-count score.

## Locked Market Mechanization

At the first executable D1 tick after a genuine normalized WTI broker-month
transition in year `Y`, month `M`:

1. repair malformed owned exposure and close the prior monthly position;
2. persist the broker `yyyymm` attempt before every fallible entry gate;
3. under one uniform native or `+1` energy D1 label convention, reconstruct
   the completed WTI log return for calendar month `M` in each exact year
   `Y-5..Y-1`;
4. require strict adjacent-month endpoints, a confirming later D1 bar,
   positive finite closes, and all five exact returns;
5. sort the five returns ascending, compute the fixed Harrell-Davis median
   through both locked representations, and require their invariant;
6. buy WTI only above `+1e-12`, sell only below `-1e-12`, and consume the
   month flat inside the inclusive band;
7. attach one frozen `3.5 * ATR(20,D1)` hard stop, no target, and admit only
   finite non-crossed quotes with modeled spread from zero through 1,500
   points; and
8. close at the next genuine broker-month transition, with a 40-calendar-day
   stale guard only for a survivor.

The one position consumes one aggregate `RISK_FIXED=1000` budget with
`RISK_PERCENT=0` and `PORTFOLIO_WEIGHT=1`. Both current news axes, legacy news
mode, and framework Friday close are OFF. Runtime reads only native MT5 D1
prices, ATR risk plumbing, broker time, quotes, symbol metadata, positions,
deals, and terminal-global attempt state.

There is no retry, current-month signal, substitute year, shorter sample,
unconditional fallback, runtime beta function, fitted weight, magnitude
sizing, target, trail, partial close, scale-in, pyramid, grid, martingale,
trained output, banned signal indicator, or external runtime feed.

## Reproducible Disagreement Fixtures

These fixtures are part of the extraction boundary and must be duplicated by
an independent reference test:

1. For sorted returns `[-0.30,-0.30,+0.05,+0.25,+0.25]`, Harrell-Davis gives
   `+0.002384` and buys. The raw mean and endpoint-Winsorized mean are both
   `-0.01`, the middle-three trimmed mean is flat, and the midhinge is
   `-0.025`.
2. For sorted returns `[-0.30,-0.20,-0.05,+0.30,+0.30]`, Harrell-Davis gives
   `+0.007696` and buys. The ordinary median and Gastwirth location are
   `-0.05` and `-0.01`, while Tukey's trimean is flat.
3. For sorted returns `[-0.30,-0.30,+0.05,+0.20,+0.20]`, Harrell-Davis gives
   `-0.013488` and sells while the ordinary median and Gastwirth location are
   `+0.05` and `+0.01` and buy.
4. Reflecting and sign-reversing each fixture must reverse every strict
   candidate decision.
5. A location of exactly `+1e-12`, `-1e-12`, or zero is flat because the
   entry comparisons are strict outside the inclusive epsilon band.

## Non-Duplicate Boundary

The preallocation receipt
`artifacts/qm5_wti_samecal_hd5_preallocation_dedup_20260830.json`, SHA-256
`08046E588E84E3AE010A4C3CA5F32F68CA1097D961731C5AD5401366D81E35A9`,
found no exact identity across 4,733 registry rows, 1,371 cards, and 45
Strategy Wiki nodes. Its 13 fuzzy results are expected same-calendar family
neighbors, not exact mechanics.

Manual review covers the raw same-calendar mean and median plus
`QM5_41191`, `QM5_41199`, `QM5_41201`, `QM5_41202`, `QM5_41204`,
`QM5_41211`, `QM5_41212`, `QM5_41223`, `QM5_41224`, and `QM5_41227` through
`QM5_41233`. Those cards use different sample sizes, information gates,
order-statistic maps, iterations, or weights. The exact five-year membership,
beta(3,3) interval-mass weights, positive tail weights, and independent
rational invariant are jointly load-bearing; altering any of them creates a
different lineage.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_HARRELL_DAVIS_MEDIAN_SIGN_MONTHLY_SLEEVE`.

## Reputable-Source Verdict And Limitations

- R1: `PASS_WITH_QUANTILE_ESTIMATOR_AND_SINGLE_CFD_TRANSLATION_RISK`. Two
  complete-read peer-reviewed trading papers support the calendar information
  object, WTI membership, sign orientation, and monthly renewal. A
  peer-reviewed *Biometrika* citation plus the originating author's maintained
  documentation and source make the estimator reproducible. No source tests
  the conjunction.
- R2: `PASS`. Calendar membership, normalized endpoints, exact sample, sort,
  beta parameters, fixed rational weights, invariant, epsilon, side, attempt,
  fixed risk, stop, spread, and lifecycle are locked before Q02.
- R3: `PASS_WITH_FIVE_YEAR_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`.
  Registered `XTIUSD.DWX` D1 history and native MT5 state supply every runtime
  field; history, labels, rolls, gaps, financing, and CFD equivalence remain
  test risks.
- R4: `PASS`. The strategy uses dates, completed closes, logarithms, sorting,
  fixed weighted sums, comparisons, ATR risk plumbing, and execution state
  only. No ML or prohibited signal component exists.

The expected cadence is approximately ten to twelve completed positions per
full post-warm-up year, but that is a prior, not a result. Q02 must retire the
unchanged candidate on zero trades, fewer than five completed positions in a
full scored year, nonpositive governed economics, or any endpoint, sample,
sort, weight, invariant, side, attempt, stop, risk, lifecycle, or determinism
defect.

Direct WTI and a recurring calendar clock target a sleeve outside the
certified XAU/SP500/NDX/XNG carrier set. They do not prove low correlation;
unchanged Q09 alone may establish realized portfolio diversification.
