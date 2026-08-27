---
source_id: MOP-NIST-WTI-MEDRUN-TREND-2026
title: WTI thirteen-month median-runs persistence trend extraction
publisher: QuantMechanica governed extraction of peer-reviewed trading and official statistical-method research
source_type: peer_reviewed_official_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-27_wti_monthly_median_runs_persistence_trend_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
method_source_id: NIST-RUNS-TEST-EDA35D
created: 2026-08-27
created_by: Research+Development
cards_extracted:
  - wti-median-runs-tr
---

# WTI Thirteen-Month Median-Runs Persistence Trend Source Packet

## Approved Sources Of Record

The trading lineage is Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje
Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. The governed packet
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
records a complete read of the 23-page published paper, monthly own-price
continuation, monthly renewal, and explicit NYMEX WTI membership.

The statistical method record is the official NIST/SEMATECH e-Handbook of
Statistical Methods, section 1.3.5.13, "Runs Test for Detecting
Non-randomness":
`https://www.itl.nist.gov/div898/handbook/eda/section3/eda35d.htm`. The page
was read completely. Its reproducible receipt is
`retrieval_route_20260827.json`; the retrieved UTF-8 content SHA-256 is
`9ACBE3A27118ABDF934FDD0EA75C4C1FFF52378BF7528271C0C751FB0531D374`.
It defines a chronological dichotomous sequence by coding observations above
the sample median positive and observations below it negative, then counts
consecutive same-sign runs. For six observations on each side of the median,
its expected-run formula gives exactly seven.

The source names Bradley (1968) and discusses significance procedures, but no
unretrieved publication body, large-sample approximation, small-sample table,
p-value, or significance claim is imported. No blocked or inferred content is
used.

## Source Findings And Claim Boundary

Moskowitz, Ooi, and Pedersen support a falsifiable monthly WTI own-price
continuation experiment. NIST supplies the complete operative median coding,
run definition, count, and expected-count formula. Together they support a
new question: does a low-or-equal-to-expectation number of chronological
above/below-median regimes identify a persistent WTI price state worth
continuing for one month?

Neither source tests that conjunction. The thirteen endpoints, omission of
the unique median, inclusive seven-run gate, newest-observation direction,
continuous-CFD mapping, fixed-dollar risk, spread cap, stop, consumed attempt,
and lifecycle are transparent QM hypotheses.

No source return, alpha, probability, Sharpe ratio, drawdown, trade density,
WTI-only result, transaction cost, CFD equivalence, significance,
decorrelation, or portfolio-correlation statistic transfers.

## Exact Statistical Contract

For thirteen positive, finite, pairwise-distinct completed WTI month-end
closes `C[0]..C[12]`, oldest to newest, assign strict ranks `rank[i]` from 1
through 13. The unique sample median has rank 7.

```text
B = empty chronological sequence
for i = 0..12:
    if rank[i] < 7: append -1 to B
    if rank[i] > 7: append +1 to B
    if rank[i] = 7: omit it

require len(B) = 12
require count(B = -1) = 6 and count(B = +1) = 6

R = 1 + sum(B[k] != B[k-1]) for k = 1..11
require 2 <= R <= 12

BUY  iff R <= 7 and rank[12] > 7
SELL iff R <= 7 and rank[12] < 7
FLAT iff R > 7 or rank[12] = 7
```

The median observation is omitted exactly as the above/below-median coding
requires. It does not bridge a run with its own sign; after omission, its two
neighbors are adjacent in `B`. The direction is the newest completed
observation's median regime, not the sign of the endpoint return. A newest
rank exactly equal to seven consumes the month flat. No p-value, normal
approximation, magnitude weight, return-sign run, endpoint fallback, slope,
regression, seasonal direction, moving average, oscillator, external series,
or prior-result gate exists.

For `n1=n2=6`, NIST's formula gives expected runs
`2*6*6/(6+6)+1 = 7`; the card uses the inclusive boundary only as a locked
persistence-oriented density gate, not as statistical rejection.

## Pre-Result Density Boundary

For thirteen no-tie ranks, remove the median. Each of the `C(12,6)=924`
six-low/six-high binary orders occurs equally often, and the median can occupy
any of thirteen chronological positions. Exact enumeration of these 12,012
representations gives:

- 6,744 qualifying representations at `R<=7` with a nonmedian newest point;
- 3,372 BUY and 3,372 SELL representations;
- 5,268 flat representations; and
- qualification rate `6744/12012 = 562/1001 = 0.5614385614385614`.

Equivalently, 3,496,089,600 of all `13! = 6,227,020,800` strict rank paths
qualify, split evenly by side. At twelve monthly decisions this is about
6.737 opportunities per random-order year. This is exact combinatorics used
only to set a pre-market density prior above the unchanged five-trades/year
Q02 floor; it is not a market probability or independence claim.

## Locked Trading Translation

At the first executable `XTIUSD.DWX` D1 tick after a genuine broker-month
transition:

1. Persist the current broker `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or order gates. Never retry the month.
2. Exclude the current month. Reconstruct the latest D1 close from each of
   exactly thirteen immediately prior consecutive completed broker months.
   Reject missing or duplicate months, nonchronological timestamps,
   nonpositive/nonfinite/equal closes, or a newest endpoint more than ten
   calendar days stale.
3. Assign strict ranks, omit rank seven, prove the six/six balance, count
   runs, prove the 2..12 range, and continue the newest nonmedian regime only
   at `R<=7`. A weak path or median newest point consumes flat.
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

The corrected fail-closed checker scanned 4,681 registry identities, 1,332
cards, and 45 current-vault Strategy Wiki nodes. It found no exact or fuzzy
match. The receipt is
`artifacts/qm5_wti_median_runs_tr_preallocation_dedup_20260827.json`.

The first invocation used the checker's obsolete default Wiki root and
correctly returned `INPUT_ERROR_FAIL_CLOSED`; no allocation followed it. The
successful invocation explicitly bound
`G:/My Drive/QuantMechanica - Company Reference/09 Strategy Wiki`.

Manual functional review separates the rule from its nearest WTI neighbors:

- `QM5_20273_wti-signrun-tr` counts the longest consecutive up/down returns;
  this rule classifies price levels around the formation median, omits the
  median, and counts all high/low regime runs.
- `QM5_20264_wti-rank-trend` counts all 78 concordant/discordant endpoint
  pairs; this rule retains only chronological transitions between six lows
  and six highs.
- `QM5_41170_wti-bartels-rank-tr` sums squared adjacent rank jumps;
  this rule discards within-half rank distance.
- `QM5_41171_wti-mturnpoint-tr` counts local peaks and troughs in all thirteen
  prices; this rule counts transitions only after median dichotomization.
- `QM5_41173_wti-mspearman-tr` weights squared displacement from time rank;
  this rule has neither a time rank nor a displacement magnitude.

Fixed rank vector `[10,3,8,5,1,11,7,12,9,13,2,6,4]` sells here at six runs,
while Mann-Kendall is `S=0`, Spearman is `T=-8`, sign-run maxima are `(1,2)`,
Bartels is `NM=406`, and turning points are ten, so all five neighbors remain
flat. Vector `[5,6,9,12,4,8,3,11,2,1,7,13,10]` is flat here at eight runs,
while Bartels and turning-point persistence both buy. These fixtures prove
the function is not a renamed horizon or threshold of those families.

Verdict:
`CLEAN_WTI_MONTHLY_MEDIAN_DICHOTOMY_RUNCOUNT_LE7_NEWEST_REGIME_CONTINUATION`.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: complete-read,
  peer-reviewed JFE trading evidence with explicit WTI membership plus a
  complete official NIST method page; exact trading conjunction untested.
- R2 `PASS`: month clock, endpoint reconstruction, strict ranks, median
  omission, six/six balance, run count, inclusive boundary, direction,
  attempt, risk, stop, and lifecycle are fixed.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 history
  and MT5-native state supply every runtime input.
- R4 `PASS`: deterministic comparisons, ranks, signs, counts, timestamps,
  ATR risk controls, and execution state only; no trained output, banned
  signal, external feed, grid, martingale, scale-in, or pyramid.

## Falsification And Safety Boundary

Retire at zero trades, fewer than five completed positions in any full post-
warm-up year, nonpositive governed economics, downstream gate failure, or any
month, endpoint, rank, median, balance, run-count, threshold, side, attempt,
risk, lifecycle, or determinism defect. No failed result may be rescued by
changing the sample, threshold, direction, risk, hold, carrier, or by adding
another gate.

WTI is a direct crude-oil carrier absent from the stated XAU/SP500/NDX/XNG
book, but that does not prove low realized correlation. Q09 alone owns
overlap. This packet authorizes no manual backtest; live/demo/shadow/stress or
optimization preset; AutoTrading; `T_Live`; deploy or live manifest;
portfolio-gate change; portfolio admission; correlation waiver; terminal
control; or second queue row.
