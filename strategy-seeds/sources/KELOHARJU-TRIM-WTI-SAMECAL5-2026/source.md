---
source_id: KELOHARJU-TRIM-WTI-SAMECAL5-2026
title: WTI exact-five-year same-calendar-month trimmed-mean seasonality extraction
publisher: QuantMechanica governed extraction of peer-reviewed finance research
source_type: peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-29_wti_same_calendar_trimmed_mean_source_approval.md
parent_source_ids:
  - KELOHARJU-RETSEAS-2016
  - MOP-WTI-TRIMMEAN-2026
parent_sha256:
  KELOHARJU-RETSEAS-2016: 54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0
  MOP-WTI-TRIMMEAN-2026: 63F8C5FC06BAE2D90B50673C6B7B966FBAF5962150D70F695DD3DA8DBB221FA8
created: 2026-08-29
created_by: Research+Development
cards_extracted:
  - wti-samecal-trim5
---

# WTI Exact-Five-Year Same-Calendar Trimmed-Mean Source Packet

## Approval And Complete-Read Boundary

The durable approval is
`decisions/2026-08-29_wti_same_calendar_trimmed_mean_source_approval.md`,
committed as `6c4c38322` before this extraction. The complete-read provenance
record is
`artifacts/qm5_wti_samecal_trim5_source_provenance_20260829.json`.

The empirical parent is
`strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, SHA-256
`54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0`.
It preserves a complete review of Keloharju, Linnainmaa, and Nyberg (2016),
*Return Seasonalities*, *Journal of Finance* 71(4), 1557-1590, DOI
`10.1111/jofi.12398`, and its open 57-page NBER version. The governed record
explicitly includes crude oil in the 24-futures commodity panel, fixes prior
returns from the matching calendar month as the operative information object,
and records a five-year history floor.

The arithmetic parent is
`strategy-seeds/sources/MOP-WTI-TRIMMEAN-2026/source.md`, SHA-256
`63F8C5FC06BAE2D90B50673C6B7B966FBAF5962150D70F695DD3DA8DBB221FA8`.
It preserves the peer-reviewed Moskowitz, Ooi, and Pedersen (2012) WTI
time-series-momentum lineage and an approved exact sort/delete/retain/average
mechanization for a bounded WTI return sample.

Both parent packets were read completely. No new public retrieval, blocked
content, source table, or inferred result is used.

## Source Findings Used

Keloharju et al. support a falsifiable same-calendar-month commodity-return
experiment, explicitly include crude oil, and require at least five years of
history. Their portfolio ranks a broad futures cross-section using historical
arithmetic-average returns. It is not a direct WTI time-series strategy.

The governed trimmed-mean parent fixes the mechanical idea of sorting a WTI
return sample, removing fixed observations from both tails, and averaging
only the retained center. That parent uses twelve contiguous recent monthly
returns and removes two per tail. It does not use same-calendar observations.

This packet joins the same-calendar information object with a fixed
five-observation, one-per-tail trimmed mean. That exact conjunction, sample,
carrier, and lifecycle are untested QM translations. No source return,
significance, coefficient, probability, hit rate, cost, drawdown, WTI-only
result, continuous-CFD equivalence, decorrelation, or portfolio statistic
transfers.

## Exact Calendar Contract

At the first executable `XTIUSD.DWX` D1 tick after a genuine broker-month
transition in decision year `Y` and target month `M`:

1. Normalize all D1 session dates under exactly one convention: native date
   labels or a uniform `+1` calendar-day energy offset. The normalized current
   D1 date must equal the current broker date.
2. Persist current broker `yyyymm` before every fallible entry gate.
3. For each exact historical year `H=Y-1..Y-5`, select the final normalized
   D1 close inside `(H,M)`.
4. Require its immediately preceding D1 bar to normalize into the immediately
   preceding calendar month and a following D1 bar to normalize into the
   immediately following calendar month. These checks prove a complete
   target month and exact adjacent endpoints.
5. Form `r(H,M)=ln(end_close(H,M)/pre_close(H,M))`.
6. Require all five exact years, positive finite endpoint prices, finite
   returns, chronological endpoints, and no substituted or skipped year.

The decision month contributes no price to its own signal. A missing exact
year consumes the current month flat rather than broadening the historical
window.

## Exact Trimmed-Mean Contract

Let `r[0]..r[4]` be the five exact historical same-calendar-month log returns:

```text
sorted = ascending copy of r[0..4]
require sorted is finite and nondecreasing

discard sorted[0] and sorted[4]
retained_sum = sorted[1] + sorted[2] + sorted[3]
trimmed_mean = retained_sum / 3

BUY  iff trimmed_mean > +1e-12
SELL iff trimmed_mean < -1e-12
FLAT iff abs(trimmed_mean) <= 1e-12 or any contract check fails
```

Exactly one observation from each tail is deleted. Exactly three observations
are retained with equal weight. The signal magnitude never changes risk.
There is no full-sample mean, ordinary median, hit-rate, rank-sum, Winsorized
replacement, variable trim count, missing-year substitution, or estimator
fallback.

## Execution Contract

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0.
- Decision clock: first normalized D1 bar after a genuine broker-month
  transition; mid-month initialization waits for the next transition.
- Attempt: persist broker `yyyymm` before history, signal, news, spread,
  quote, ATR, sizing, margin, or order checks. Never retry the month.
- Side: follow only the strict trimmed-mean sign.
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Stop: frozen `3.5*ATR(20,D1)` hard stop from completed data; no target.
- Cost gate: a genuinely positive spread above 1,500 points consumes the
  month; modeled zero `.DWX` spread is valid.
- Exit: first tick in a later broker month; 35 elapsed calendar days repairs
  only a survivor.
- Repair: immediately flatten duplicate, wrong-symbol, wrong-magic,
  wrong-side, invalid-volume, or stopless owned exposure.
- Both news axes, legacy news mode, and framework Friday close are OFF.

Runtime uses only registered D1 OHLC/timestamps, broker time, current quotes,
symbol contract metadata, positions, deals, terminal global state, and V5
framework services. There is no external runtime data, scale-in, pyramid,
grid, martingale, hedge, partial exit, target, trailing stop, or optimization
surface.

## Non-Duplicate Functional Boundary

The canonical pre-allocation receipt is
`artifacts/qm5_wti_samecal_trim5_preallocation_dedup_20260829.json`. It
scanned 4,698 registry identities, 1,344 cards, and all 45 current Strategy
Wiki nodes, found no exact identity, and surfaced only the expected fuzzy
same-calendar arithmetic-mean neighbor.

Fixed fixtures establish different executable decisions:

- For sorted returns `[-.30,-.04,-.03,.08,.09]`, this rule drops the two
  extremes and buys because the retained mean is `+.003333...`. The complete
  sample mean is `-.04`, the median is `-.03`, and the centered signed-rank
  score is `-1`; the existing mean, median, and signed-rank rules all sell.
- For sorted returns `[-.30,-.04,.01,.02,.03]`, this rule sells because the
  retained mean is `-.003333...`, while three of five observations are
  positive and the median is `+.01`; the hit-rate and median states are
  favorable.

Existing boundaries remain distinct:

- `QM5_20099_wti-samecal` keeps every valid observation in the arithmetic
  mean.
- `QM5_41055_wti-medcal` uses only the central order statistic.
- `QM5_41059_wti-samecal-hit` counts positive observations against its fixed
  boundary.
- `QM5_41191_wti-samecal-srank` weights return signs by absolute ranks.
- `QM5_20270_wti-trimmean-mom` trims a twelve-return contiguous recent path,
  not five disjoint returns for the upcoming calendar month.
- Fixed-month WTI cards do not recompute a cross-year robust state, and
  certified `QM5_12567` is a short-horizon long-only XNG oscillator pullback.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_MIDDLE_THREE_TRIMMED_MEAN_SIGN_MONTHLY_RENEWAL`.

## Reputable-Source Criteria

- R1 `PASS_WITH_FIXED_SAMPLE_AND_TRIM_TRANSLATION_RISK`: complete
  peer-reviewed same-calendar commodity evidence with explicit crude-oil
  membership plus a complete governed peer-reviewed WTI trimmed-arithmetic
  packet; the exact conjunction is untested.
- R2 `PASS`: calendar labels, exact years, endpoint proof, sample size, sort,
  deleted and retained indexes, divisor, sign band, attempt, risk, stop,
  spread, and lifecycle are deterministic and locked.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  `XTIUSD.DWX` D1 data and native MT5 state provide every field; the five-year
  warm-up, rolls, and futures/CFD basis are binding Q02 risks.
- R4 `PASS`: timestamps, logarithms, sorting, finite arithmetic, comparisons,
  ATR risk controls, and execution state only; no trained signal, banned
  signal indicator, external runtime feed, grid, martingale, scale-in, or
  pyramid.

## Density, Falsification, And Safety

After five exact historical years exist, the rule consumes twelve decisions
per full year and trades whenever the middle-three mean is outside the tie
band. The pre-result prior is ten to twelve completed positions/year; this is
a structural bound, not a performance claim.

Q02 must retire on zero trades, fewer than five completed positions in any
full post-warm-up year, nonpositive governed economics, or any label, month,
endpoint, exact-year, sample, sort, tail deletion, retained sum, divisor,
side, attempt, fixed-risk, stop, lifecycle, or determinism defect. No failed
result may be rescued by changing the sample, trim, estimator, carrier,
direction, risk, hold, spread, or retry contract.

Direct WTI is a crude-oil carrier absent from the stated certified book, but
only unchanged Q09 may establish realized overlap. This packet authorizes
research, one branch-only non-live build, strict Q01, and one paced Q02
handoff. It does not authorize a manual backtest, live artifact, `T_Live`,
AutoTrading, deploy manifest, portfolio-gate change, portfolio admission, or
correlation waiver.
