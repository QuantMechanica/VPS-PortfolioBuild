---
source_id: MOP-FOSTER-STUART-WTI-MRECORD-TREND-2026
title: WTI thirteen-month Foster-Stuart forward-record-count trend extraction
publisher: QuantMechanica governed extraction of peer-reviewed trading and statistical research
source_type: peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-26_wti_monthly_foster_stuart_record_count_trend_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-26
created_by: Research+Development
cards_extracted:
  - wti-foster-record-tr
---

# WTI Thirteen-Month Foster-Stuart Forward-Record-Count Trend Source Packet

## Approved Sources Of Record

The trading lineage is Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje
Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. The complete governed
packet `strategy-seeds/sources/MOP-TSMOM-2012/source.md` records an end-to-end
read of the 23-page author-hosted published paper, PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`,
monthly own-price continuation, monthly renewal, and explicit NYMEX WTI
membership.

The statistical lineage is F. G. Foster and A. Stuart (1954),
"Distribution-Free Tests in Time-Series Based on the Breaking of Records,"
*Journal of the Royal Statistical Society, Series B* 16(1), 1-22, DOI
`10.1111/j.2517-6161.1954.tb00143.x`. The official Oxford Academic record at
`https://academic.oup.com/jrsssb/article/16/1/1/7026737` confirms the authors,
journal, issue, pages, DOI, and abstract. The abstract says the paper proposes
linear functions of upper- and lower-record counts, including a consistent
test against trend in the mean. The original body is not represented as
completely read.

The exact public algorithm record is Jorge Castillo-Mateo's `RecordTest`
repository, the source of the CRAN package and companion to Castillo-Mateo,
Cebrian, and Asin (2023), "RecordTest: An R Package to Analyze
Non-Stationarity in the Extremes Based on Record-Breaking Events," *Journal
of Statistical Software* 106(5), 1-28, DOI `10.18637/jss.v106.i05`.
Repository commit `463cca629cec54ed58dfe0f03140d29be6c8f2aa` was read through
the public GitHub API after the deterministic source router returned
`ROUTE_GITHUB_API`. Complete relevant-file hashes and retrieval evidence are
in `retrieval_route_20260826.json`.

At that fixed commit, `R/foster.test.R` defines the unweighted forward
Foster-Stuart location statistic `d` as the sum of forward-upper indicators
minus forward-lower indicators. `R/I.record.R` defines a strict upper record
as a value greater than every previous value, a strict lower record as a
value less than every previous value, and the first value as both trivial
records. The two trivial indicators cancel in `d`.

These bounded records were reviewed before the durable OWNER approval at
`decisions/2026-08-26_wti_monthly_foster_stuart_record_count_trend_source_approval.md`.
No blocked text, inferred table, executed third-party code, or ungoverned
performance claim is used.

## Source Findings Used

- Moskowitz, Ooi, and Pedersen support a falsifiable monthly WTI own-price
  continuation experiment and monthly position renewal.
- Foster and Stuart provide peer-reviewed distribution-free record-count
  trend-in-location lineage.
- The complete public `RecordTest` files fix the forward `d` statistic and
  strict record definitions used by this extraction.

The records do not establish that `abs(d)>=2` predicts WTI or is a published
significance boundary. The thirteen-endpoint sample, threshold, direct-CFD
mapping, fixed-dollar risk, stop, spread cap, attempt state, and lifecycle are
transparent QM choices.

No source return, alpha, probability, Sharpe ratio, drawdown, WTI-only result,
trade density, transaction cost, CFD equivalence, estimator superiority,
decorrelation, or portfolio-correlation statistic transfers.

## Exact Statistical Contract

For thirteen positive finite completed month-end closes `C[0]..C[12]`, oldest
to newest:

```text
running_high = C[0]
running_low  = C[0]
upper = 0
lower = 0
neutral = 0

for i = 1..12:
  if C[i] > running_high:
    upper += 1
    running_high = C[i]
  else if C[i] < running_low:
    lower += 1
    running_low = C[i]
  else:
    neutral += 1

d = upper - lower
require upper + lower + neutral == 12

BUY  iff d >=  2
SELL iff d <= -2
FLAT otherwise
```

All comparisons are strict. An equality is not a weak record and belongs to
the neutral count. A nonpositive or nonfinite close, wrong endpoint count,
wrong chronology, impossible count, or nonfinite state consumes the month
flat. Record magnitude never changes direction or risk. There is no p-value,
normal approximation, backward-record statistic, endpoint-return fallback,
all-pairs rank score, slope, moving average, oscillator, calendar direction,
external series, or prior pipeline result.

The threshold is fixed before observing a market result. Across all `13!`
equally likely distinct-rank permutations under an explicitly non-empirical
IID thought experiment, `2,963,909,390 / 6,227,020,800`, or
47.5975508224%, have `abs(d)>=2`. Twelve decisions imply 5.7117060987
qualifying paths/year. This is a density prior only; WTI month ends are not
asserted IID, continuous, or rank-uniform.

## Exact Event And Execution Contract

1. Require exact `XTIUSD.DWX`, D1, slot zero, and an entry attempt no later
   than 180 elapsed minutes after the raw current D1 bar open in a genuine new
   broker month.
2. Persist the broker `yyyymm` before all fallible gates. A flat result,
   invalid state, reject, stop, or restart never retries the month.
3. Select the latest close in each of the immediately prior thirteen
   consecutive broker months. Require positive finite closes, strict
   chronology, the immediately prior newest month, and no more than ten
   calendar days of endpoint staleness. The current month contributes no
   signal close.
4. Compute strict forward upper and lower record counts, require count
   conservation, and follow `d` only at `abs(d)>=2`.
5. Open at most one WTI position under `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   and `PORTFOLIO_WEIGHT=1`. Size against a frozen `3.5*ATR(20,D1)` hard stop,
   attach no target, and cap entry spread at 1,500 points.
6. Close on the first tick in a later broker month or after forty calendar
   days. Immediately repair duplicate, wrong-symbol, wrong-magic, wrong-side,
   invalid-volume, or stopless owned exposure.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered MT5 D1 history, timestamps, calendar, quotes, symbol metadata,
ATR, positions, deals, and terminal-persistent state.

## Non-Duplicate Boundary

The fail-closed canonical checker scanned 4,668 registry identities, 1,319
cards, and 45 Strategy Wiki nodes. It found no exact or fuzzy match. The
receipt is
`artifacts/qm5_wti_foster_record_tr_preallocation_dedup_20260826.json`,
SHA-256 `BB0661A74BC9F28E2D292DDF49A01E131289A0054DB895B3FB76F54255AF7891`.

Manual review fixes a new path statistic:

- `QM5_20264_wti-rank-trend` compares every ordered endpoint pair and uses a
  Mann-Kendall score. This rule compares each endpoint only with the running
  extreme and counts new records.
- `QM5_20261_wti-lr-trend` and the robust-slope family use all price
  magnitudes and fitted geometry. This rule discards magnitude after strict
  record classification.
- `QM5_41167_wti-coxstuart-tr` compares seven fixed lag-seven pairs among
  fourteen endpoints. This rule uses thirteen endpoints, no fixed pairs, and
  a running record frontier.
- `QM5_10473_mql5-spearman` trades H4 zero crossings of a rolling rank
  correlation on FX. This rule has no correlation coefficient or crossing
  event and trades only monthly WTI record imbalance.
- On fourteen distinct ranks
  `[1,8,2,6,9,10,4,12,5,13,11,0,3,7]`, this rule reads the latest thirteen,
  records four new highs and two new lows, and buys at `d=2`; the twelve-month
  endpoint falls, Mann-Kendall is `2`, Cox-Stuart splits 4/3, quarterly blocks
  split 2/2, and the OLS numerator is negative.
- On `[1,2,0,7,4,3,13,10,9,8,11,6,5,12]`, this rule is flat at `d=1`; the
  endpoint rises, Mann-Kendall is `28`, Cox-Stuart is 6/1, all four quarterly
  blocks rise, and the OLS numerator is positive.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not monthly WTI record-count continuation.

The WTI carrier, thirteen consecutive endpoints, strict running-record
frontiers, forward `d`, threshold two, consumed month, fixed risk, and renewal
clock are jointly load-bearing. Verdict:
`CLEAN_WTI_MONTHLY_FOSTER_STUART_FORWARD_RECORD_D2_TREND`.

## Reputable-Source Criteria

- R1: `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`. Named-author,
  peer-reviewed WTI trading evidence with complete-paper provenance; official
  peer-reviewed Foster-Stuart record; and complete public implementation and
  record-definition files from a peer-reviewed statistical package. The
  original 1954 body and exact trading conjunction are not claimed as tested.
- R2: `PASS`. Observation order, strict record definitions, counts,
  threshold, direction, attempt, risk, stop, and lifecycle are exact.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered `XTIUSD.DWX` D1
  history and native MT5 state supply every runtime input.
- R4: `PASS`. Deterministic comparisons, integer counts, calendar, ATR risk
  controls, and execution state only; no trained output, banned signal
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Claim, Kill, And Safety Boundary

The source supports testing monthly WTI trend with a strict Foster-Stuart
forward-record imbalance, not the efficacy or significance of the `d=2`
trading threshold. Q02 must retire below five completed positions in any full
post-warm-up year, at zero trades, with nonpositive governed economics, or on
a state, endpoint, record, count, side, risk, attempt, or lifecycle defect.
Downstream gates alone own robustness and correlation.

No failed result may be rescued by changing the sample, record definition,
threshold, direction, carrier, stop, hold, spread cap, or retry contract. This
packet supports one V5 card, one non-live build, strict compile/Q01, and one
paced Q02 handoff only. It does not authorize a manual backtest, live artifact,
`T_Live`, AutoTrading, deploy manifest, portfolio-gate change, portfolio
admission, correlation waiver, terminal control, or claim that the sleeve is
already profitable, certified, or uncorrelated.
