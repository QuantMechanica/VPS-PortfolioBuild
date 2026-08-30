---
source_id: KELOHARJU-GASTWIRTH-GSL-WTI-SAMECAL-GAST5-2026
source_type: governed_composite_peer_reviewed_and_official_numerical_documentation
status: cards_ready
created: 2026-08-30
created_by: Research+Development
source_approval: decisions/2026-08-30_wti_same_calendar_gastwirth5_source_approval.md
---

# WTI Exact-Five-Year Same-Calendar Gastwirth Location Source Packet

## Approval And Extraction Boundary

The durable source approval is
`decisions/2026-08-30_wti_same_calendar_gastwirth5_source_approval.md`,
committed as `04322a80a` before this extraction. It authorizes exactly one
structural, low-frequency, single-WTI Strategy Card and non-live build under
the current OWNER commodity/energy portfolio mission.

This packet joins three bounded ideas:

1. recurring same-calendar commodity return information;
2. WTI own-return direction with monthly renewal; and
3. a named robust location estimator with a fixed numerical quantile
   convention.

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
exact-five-year WTI-only sign port below is therefore not a replication.

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

### 3. Gastwirth (1966)

Gastwirth, Joseph L., "On Robust Procedures," *Journal of the American
Statistical Association* 61(316), 929-948, DOI
`10.1080/01621459.1966.10482185`.

The named paper develops robust location procedures for symmetric unimodal
families. Its citation was verified against the author's George Washington
University bibliography and DOI metadata. This packet uses the Gastwirth name
only for the fixed L-estimator below. It does not import an efficiency claim,
distributional guarantee, small-sample optimality claim, or financial result.

### 4. GNU Scientific Library 2.8

The official GNU Scientific Library Statistics documentation sections
"Median and Percentiles" and "Gastwirth Estimator" were read completely on
2026-08-30:

`https://www.gnu.org/software/gsl/doc/html/statistics.html`

The documentation defines the Gastwirth location as:

```text
G = 0.3 * Q(1/3) + 0.4 * Q(1/2) + 0.3 * Q(2/3)
```

It separately fixes the quantile interpolation used by the library. For an
ascending array `x[0..n-1]` and fraction `f`:

```text
h     = (n - 1) * f
i     = floor(h)
delta = h - i
Q(f)  = (1 - delta) * x[i] + delta * x[i+1]
```

This explicit convention removes a material ambiguity: software packages use
multiple incompatible finite-sample quantile definitions. The EA must use the
GSL formula above and no other quantile type.

## Exact Five-Observation Reduction

The candidate requires exactly five completed matching-calendar-month WTI log
returns. After sorting them as `s[0] <= ... <= s[4]`, the official GSL formula
reduces to:

```text
Q(1/3) = (2*s[1] + s[2]) / 3
Q(1/2) = s[2]
Q(2/3) = (s[2] + 2*s[3]) / 3

G = 0.3*Q(1/3) + 0.4*Q(1/2) + 0.3*Q(2/3)
  = 0.2*s[1] + 0.6*s[2] + 0.2*s[3]
```

The implementation computes the quantiles and the named aggregation, then
independently checks the simplified invariant within `1e-12`. The extrema
remain required because all five exact years determine the sorted order, but
the finite-sample estimator gives them zero direct weight.

This is neither:

- a three-value trimmed mean, whose central weights are `1/3,1/3,1/3`;
- Tukey's trimean under the same GSL quartile convention, whose central
  weights are `1/4,1/2,1/4`;
- a midhinge, whose central weights are `1/2,0,1/2`;
- an ordinary median, whose central weights are `0,1,0`;
- endpoint Winsorization, a pseudomedian, a shortest interval, a block
  median, a Huber or bisquare iteration, or a MAD-capped mean.

## Locked Market Mechanization

At the first executable D1 tick after a genuine normalized WTI broker-month
transition in year `Y`, month `M`:

1. repair malformed owned exposure and close the prior monthly package;
2. persist the broker `yyyymm` attempt before every fallible entry gate;
3. under one uniform native or `+1` energy D1 label convention, reconstruct
   the completed WTI log return for calendar month `M` in each exact year
   `Y-5..Y-1`;
4. require strict adjacent-month endpoints, a confirming later D1 bar,
   positive finite closes, and all five exact returns;
5. sort the five returns ascending, compute GSL `Q(1/3)`, `Q(1/2)`, and
   `Q(2/3)`, aggregate `0.3/0.4/0.3`, and verify the five-sample simplified
   invariant;
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
unconditional fallback, optimized quantile type, fitted weight, magnitude
sizing, target, trail, partial close, scale-in, pyramid, grid, martingale,
trained output, banned signal indicator, or external runtime feed.

## Reproducible Disagreement Fixtures

These fixtures are part of the extraction boundary and must be duplicated by
an independent reference test:

1. For sorted returns `[-0.30,-0.28,+0.02,+0.24,+0.26]`, Gastwirth gives
   `+0.004` and buys. The raw mean and middle-three mean are negative and
   sell; the trimean is exactly flat. The three-MAD cap is inactive and stays
   at the negative raw mean, so the MAD-cap sibling sells.
2. For sorted returns `[-0.20,-0.15,+0.04,+0.05,+0.06]`, Gastwirth gives
   `+0.004` and buys. The middle-three mean is `-0.02`, the trimean is
   `-0.005`, the midhinge is `-0.05`, and the endpoint-Winsorized mean is
   `-0.032`; those siblings sell.
3. For sorted returns `[-0.25,-0.20,+0.01,+0.04,+0.05]`, Gastwirth gives
   `-0.026` and sells while the ordinary median buys.
4. Reflecting and sign-reversing each fixture must reverse every strict
   candidate decision.
5. A location of exactly `+1e-12`, `-1e-12`, or zero is flat because the
   entry comparisons are strict outside the inclusive epsilon band.

## Non-Duplicate Boundary

The preallocation receipt
`artifacts/qm5_wti_samecal_gast5_preallocation_dedup_20260830.json`, SHA-256
`C9ADEE43102AC02EDE2BFCD5891EA639A115D59658DF730B9F1A899F0B120F17`,
found no exact match across 4,732 registry identities, 1,370 cards, and 45
Strategy Wiki nodes. It surfaced only the expected fuzzy raw same-calendar
mean sibling `QM5_20099`.

Manual review also covers `QM5_41055`, `QM5_41199`, `QM5_41201`,
`QM5_41202`, `QM5_41204`, `QM5_41211`, `QM5_41212`, `QM5_41223`, and
`QM5_41227` through `QM5_41232`. Those cards use different sample sizes,
statistics, weights, gates, or update rules. The exact five-year membership,
GSL quantile interpolation, and `0.3/0.4/0.3` quantile aggregation are jointly
load-bearing; altering any of them creates a different lineage.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_GSL_GASTWIRTH_LOCATION_SIGN_MONTHLY_SLEEVE`.

## Reputable-Source Verdict And Limitations

- R1: `PASS_WITH_ROBUST_LOCATION_AND_SINGLE_CFD_TRANSLATION_RISK`. Two
  complete-read peer-reviewed trading papers support the calendar information
  object, WTI membership, sign orientation, and monthly renewal. A named JASA
  source and official GNU documentation make the estimator reproducible. No
  source tests the conjunction.
- R2: `PASS`. Calendar membership, normalized endpoints, exact sample, sort,
  quantile interpolation, aggregation, epsilon, side, attempt, fixed risk,
  stop, spread, and lifecycle are locked before Q02.
- R3: `PASS_WITH_FIVE_YEAR_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`.
  Registered `XTIUSD.DWX` D1 history and native MT5 state supply every runtime
  field; history, labels, rolls, gaps, financing, and CFD equivalence remain
  test risks.
- R4: `PASS`. The strategy uses dates, completed closes, logarithms, sorting,
  fixed interpolation, weighted sums, comparisons, ATR risk plumbing, and
  execution state only. No ML or prohibited signal component exists.

The expected cadence is approximately ten to twelve completed positions per
full post-warm-up year, but that is a prior, not a result. Q02 must retire the
unchanged candidate on zero trades, fewer than five completed positions in a
full scored year, nonpositive governed economics, or any endpoint, sample,
quantile, weight, side, attempt, stop, risk, lifecycle, or determinism defect.

Direct WTI and a recurring calendar clock target a sleeve outside the
certified XAU/SP500/NDX/XNG carrier set. They do not prove low correlation;
unchanged Q09 alone may establish realized portfolio diversification.
