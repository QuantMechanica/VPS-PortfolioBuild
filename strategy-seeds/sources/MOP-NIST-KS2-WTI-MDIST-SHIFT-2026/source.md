---
source_id: MOP-NIST-KS2-WTI-MDIST-SHIFT-2026
title: WTI twelve-month fixed-block signed ECDF distribution-shift trend extraction
publisher: QuantMechanica governed extraction of peer-reviewed trading and official statistical-method research
source_type: peer_reviewed_official_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-27_wti_monthly_ks_distribution_shift_trend_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
method_source_id: NIST-DATAPLOT-KS2SAMP
created: 2026-08-27
created_by: Research+Development
cards_extracted:
  - wti-mks-shift-tr
---

# WTI Fixed-Block Signed ECDF Distribution-Shift Trend Source Packet

## Approved Sources Of Record

The trading lineage is Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje
Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. The governed packet
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
records an end-to-end read of the 23-page published paper, monthly own-price
continuation, monthly renewal, and explicit NYMEX WTI membership.

The statistical method record is the official NIST Dataplot Reference Manual
page "Kolmogorov-Smirnov Two-Sample Goodness of Fit Test":
`https://www.itl.nist.gov/div898/software/dataplot/refman1/auxillar/ks2samp.htm`.
The complete 271-line page was read. Its reproducible receipt is
`retrieval_route_20260827.json`; the retrieved UTF-8 content SHA-256 is
`15EB4DF37FB991D41A6AE16CEF8CD341124C24DB8A7B7078B11DC42E2C90A289`.
It defines two empirical distribution functions evaluated at the observations
from both samples and a statistic based on their maximum absolute separation.

NIST also warns that the statistic and any tabulated critical values must use
consistent scaling. This packet imports no critical value, p-value, or
significance interpretation. It uses an integer ECDF-count gap only as a
locked, auditable distribution-shift effect-size gate.

## Source Findings And Claim Boundary

Moskowitz, Ooi, and Pedersen support a falsifiable monthly WTI own-price
continuation experiment. NIST supplies the operative two-sample ECDF and
maximum-gap construction. Together they motivate a new question: when the
distribution of the latest six completed WTI month-end levels is visibly
displaced from the prior six, does that displacement persist for one month?

Neither source tests this exact rule. The fixed six-plus-six split, strict-tie
rejection, signed gap, `3/6` boundary, direction, continuous-CFD mapping,
fixed-dollar risk, spread cap, stop, consumed attempt, and lifecycle are
transparent QM hypotheses.

No source return, alpha, probability, Sharpe ratio, drawdown, trade density,
WTI-only result, transaction cost, CFD equivalence, significance,
decorrelation, or portfolio-correlation statistic transfers.

## Exact Statistical Contract

For twelve positive, finite, pairwise-distinct completed WTI month-end closes
`C[0]..C[11]`, oldest to newest, define fixed blocks:

```text
O = C[0..5]   # older six
N = C[6..11]  # newer six

old_seen = 0
new_seen = 0
D_plus_count = 0
D_minus_count = 0

scan the twelve combined values from smallest to largest:
    increment old_seen when the value belongs to O, otherwise new_seen
    delta = old_seen - new_seen
    D_plus_count  = max(D_plus_count,  delta)
    D_minus_count = max(D_minus_count, -delta)

require 0 <= D_plus_count <= 6
require 0 <= D_minus_count <= 6

BUY  iff D_plus_count >= 3 and D_plus_count > D_minus_count
SELL iff D_minus_count >= 3 and D_minus_count > D_plus_count
FLAT otherwise
```

Dividing either count by six gives the corresponding one-sided ECDF gap. A
positive `old_seen-new_seen` maximum means lower thresholds contain more old
observations, so the newer block is displaced higher and the continuation
side is BUY. The opposite maximum produces SELL. Equal maxima consume the
month flat. No critical table, p-value, fitted distribution, variable split,
rank sum, median, mean, endpoint fallback, slope, regression, seasonal
direction, moving average, oscillator, external series, or prior-result gate
exists.

## Pre-Result Density Boundary

With no ties, the statistic depends only on which six of the twelve combined
ranks belong to the older block. Exact enumeration of all `C(12,6)=924`
assignments gives:

- 218 BUY assignments at the signed `3/6` boundary or beyond;
- 218 SELL assignments;
- 488 flat assignments, including the two assignments whose directional
  maxima tie at three; and
- directional qualification rate `436/924 = 109/231`, approximately
  `0.4718614719`.

Equivalently, 226,022,400 of all `12! = 479,001,600` strict chronological
rank paths qualify. At twelve monthly decisions this is approximately 5.662
opportunities per random-rank year. This is exact combinatorics used only to
set a pre-market density prior near but above the unchanged five-trades/year
Q02 floor; it is not a market probability, independence claim, or statistical
rejection level.

## Locked Trading Translation

At the first executable `XTIUSD.DWX` D1 tick after a genuine broker-month
transition:

1. Persist the current broker `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or order gates. Never retry the month.
2. Exclude the current month. Reconstruct the latest D1 close from each of
   exactly twelve immediately prior consecutive completed broker months.
   Reject missing or duplicate months, nonchronological timestamps,
   nonpositive/nonfinite/equal closes, or a newest endpoint more than ten
   calendar days stale.
3. Keep the oldest six and newest six fixed, scan their combined strict order,
   calculate both signed ECDF-gap counts, and continue the dominant side only
   when its count is at least three. Central, tied, or invalid states consume
   the month flat.
4. Open at most one WTI position under `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`, sized against a frozen
   `3.5*ATR(20,D1)` broker hard stop. Attach no target and reject spread above
   1,500 points.
5. Close on the first processed tick in a later broker month or after forty
   calendar days. Immediately repair duplicate, wrong-symbol, wrong-magic,
   wrong-side, invalid-volume, or stopless owned exposure.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered MT5 D1 history, timestamps, calendar, quotes, symbol metadata,
ATR, positions, deals, terminal global variables, and V5 services.

## Non-Duplicate Functional Boundary

The fail-closed checker explicitly bound the current Company Reference vault
and scanned 4,682 registry identities, 1,333 card files, and 45 Strategy Wiki
nodes. It found no exact or fuzzy match. The receipt is
`artifacts/qm5_wti_mks_shift_tr_preallocation_dedup_20260827.json`.

Manual review separates the rule from its nearest WTI neighbors:

- `QM5_41176_wti-mwilcoxon-shift-tr` sums all 36 old/new ordinal wins; this
  rule keeps only the largest vertical ECDF separation and therefore depends
  on where the separation occurs, not the total pair count.
- `QM5_41172_wti-mpettitt-shift-tr` searches twelve possible change points in
  thirteen observations and requires a unique central maximum; this rule
  never searches or relocates the fixed split after month six.
- `QM5_20264_wti-rank-trend` counts all 78 chronological pairs across thirteen
  endpoints; this rule ignores within-block chronology and uses twelve points.
- `QM5_41173_wti-mspearman-tr` weights every price rank by its calendar-rank
  displacement; this rule is invariant to order inside each six-month block.
- `QM5_41182_wti-median-runs-tr` counts chronological high/low regime runs
  around a thirteen-point median; this rule has no sample median or run count.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day natural-gas
  pullback, not a symmetric monthly WTI distribution-shift continuation rule.

For chronological rank path
`[1,2,3,5,11,12,4,6,7,8,9,10]`, this rule buys at
`D_plus_count=3`, `D_minus_count=2`, while Mann-Whitney stays flat at
`U_new=23`. Path `[1,2,4,6,8,10,3,5,7,9,11,12]` stays flat here at maxima
`(2,0)` while Mann-Whitney buys at `U_new=26`. Their side-reflected paths
provide the symmetric SELL separations.

Verdict:
`CLEAN_WTI_MONTHLY_FIXED_SIX_BY_SIX_SIGNED_KS_ECDF_GAP3_DISTRIBUTION_SHIFT_CONTINUATION`.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: complete-read,
  peer-reviewed JFE trading evidence with explicit WTI membership plus a
  complete official NIST two-sample method page; exact trading conjunction
  untested.
- R2 `PASS`: month clock, endpoint reconstruction, fixed blocks, strict ties,
  combined scan, both gap counts, boundary, direction, attempt, risk, stop,
  and lifecycle are fixed.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 history
  and MT5-native state supply every runtime input.
- R4 `PASS`: deterministic comparisons, counts, timestamps, ATR risk controls,
  and execution state only; no trained output, prohibited signal, external
  feed, grid, martingale, scale-in, or pyramid.

## Falsification And Safety Boundary

Retire at zero trades, fewer than five completed positions in any full post-
warm-up year, nonpositive governed economics, downstream gate failure, or any
month, endpoint, split, tie, ECDF-count, threshold, side, attempt, risk,
lifecycle, or determinism defect. No failed result may be rescued by changing
the sample, split, boundary, direction, risk, hold, carrier, or by adding
another gate.

WTI is a direct crude-oil carrier absent from the stated XAU/SP500/NDX/XNG
book, but that does not prove low realized correlation. Q09 alone owns
overlap. This packet authorizes no manual backtest; live/demo/shadow/stress or
optimization preset; AutoTrading; `T_Live`; deploy or live manifest;
portfolio-gate change; portfolio admission; correlation waiver; terminal
control; or second queue row.
