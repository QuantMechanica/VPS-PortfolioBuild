---
source_id: MOP-THEILSEN-KOENKER-SIEGEL-WTI-MROBUST3-AGREE-2026
title: WTI thirteen-month robust-three unanimous-slope trend extraction
publisher: QuantMechanica governed extraction of peer-reviewed trading and statistical research
source_type: peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-26_wti_monthly_robust_three_consensus_trend_source_approval.md
parent_source_ids:
  - MOP-WTI-THEILSEN-2026
  - MOP-KOENKER-BASSETT-WTI-LAD-2026
  - MOP-SIEGEL-WTI-REPMEDIAN-2026
parent_sha256:
  MOP-WTI-THEILSEN-2026: F83880B74B1DB645F6C20A58B76825DA96787E327C461D0E798CA01CAB72535E
  MOP-KOENKER-BASSETT-WTI-LAD-2026: 7F4630DCF4D10D2004F94FA098712810048E05F56A9E8EFF45F85079F3752D5A
  MOP-SIEGEL-WTI-REPMEDIAN-2026: 199D39CB5ECAFC7B57F19BA7932DBEF6558529DD68AE00B66AD4531C7FA48E91
created: 2026-08-26
created_by: Research+Development
cards_extracted:
  - wti-mrobust3-agree-tr
---

# WTI Thirteen-Month Robust-Three Consensus Trend Source Packet

## Approved Sources Of Record

The trading lineage is Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje
Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. The governed parent
packet `strategy-seeds/sources/MOP-WTI-THEILSEN-2026/source.md` preserves the
complete-paper provenance, explicit NYMEX WTI membership, monthly cadence,
and bounded thirteen-month WTI endpoint contract.

The LAD lineage is the complete governed packet
`strategy-seeds/sources/MOP-KOENKER-BASSETT-WTI-LAD-2026/source.md`. It binds
the MOP carrier to the complete-read Karsten Schweikert (2018) author preprint,
*Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`, including Koenker-Bassett check-loss
regression, adverse findings, and the exact finite LAD breakpoint reduction.

The repeated-median lineage is
`strategy-seeds/sources/MOP-SIEGEL-WTI-REPMEDIAN-2026/source.md`. It preserves
the official Oxford Academic bibliographic and abstract record for Andrew F.
Siegel (1982), "Robust Regression Using Repeated Medians," *Biometrika*
69(1), 242-244, DOI `10.1093/biomet/69.1.242`, and exact nested-median
arithmetic. The paywalled body is not represented as completely read.

All three bounded parent records were read completely before the durable
OWNER source approval at
`decisions/2026-08-26_wti_monthly_robust_three_consensus_trend_source_approval.md`.
No new online route, blocked content, inferred source table, or ungoverned
performance claim is used.

## Source Findings Used

- MOP tests each instrument's own return across monthly lags, reports broad
  first-year continuation, renews positions monthly, and explicitly includes
  NYMEX WTI in its commodity universe.
- The governed Theil-Sen carrier computes the central value of all 78
  pairwise slopes across thirteen completed WTI month-end log prices.
- The governed LAD record profiles a residual-median intercept and minimizes
  total absolute vertical error across the same thirteen observations.
- The Siegel record supplies nested-median robust-regression lineage; the
  governed WTI packet fixes thirteen pivot-specific slope medians and their
  outer median.

These sources support a falsifiable WTI own-price trend experiment and three
different deterministic robust slope views. They do not establish that
requiring unanimous signs improves returns or robustness. The conjunction,
sample, continuous-CFD mapping, fixed-dollar risk, stops, spread cap, attempt
state, and lifecycle are transparent QM choices.

No source return, alpha, probability, Sharpe ratio, drawdown, trade density,
cost, WTI-only result, CFD equivalence, estimator superiority, decorrelation,
or portfolio-correlation statistic transfers.

## Exact Statistical Contract

For thirteen positive finite completed month-end closes `C[0]..C[12]`, oldest
to newest:

```text
y[i] = ln(C[i]), i = 0..12

pair_slopes = []
for i = 0..11:
  for j = i+1..12:
    pair_slopes.append((y[j] - y[i]) / (j - i))
require len(pair_slopes) == 78

theilsen = mean(ascending(pair_slopes)[38:40])

for every candidate b in pair_slopes:
  residual[i] = y[i] - b*i
  intercept = ascending(residual)[6]
  loss[b] = sum(abs(y[i] - intercept - b*i), i=0..12)
minimum_loss = min(loss)
minimizers = every candidate b with abs(loss[b]-minimum_loss) <= 1e-12
lad = ordinary_median(ascending(minimizers))

for pivot i=0..12:
  pivot_slopes = forward-oriented slope from i to each j != i
  require len(pivot_slopes) == 12
  pivot_median[i] = mean(ascending(pivot_slopes)[5:7])
require len(pivot_median) == 13
repeated_median = ascending(pivot_median)[6]

BUY  iff theilsen > 0 and lad > 0 and repeated_median > 0
SELL iff theilsen < 0 and lad < 0 and repeated_median < 0
FLAT otherwise
```

Every denominator is a positive integer month-index distance. LAD loss is
summed in chronological observation order. Ordinary median means the middle
element for an odd count and the arithmetic mean of the two central elements
for an even count. Exact zero, sign disagreement, invalid counts, or nonfinite
arithmetic consumes the month flat. There is no fallback, majority vote,
weight, threshold, confidence score, fitted scale, direction flip, signal-
magnitude sizing, OLS, moving average, oscillator, calendar gate, external
series, or prior pipeline result.

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
4. Compute all three exact slope functionals and require one unanimous strict
   sign. Log their values and signs. No constituent may be skipped.
5. Follow the unanimous sign with at most one WTI position under
   `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Size against
   a frozen `3.5*ATR(20,D1)` hard stop, attach no target, and cap entry spread
   at 1,500 points.
6. Close on the first tick in a later broker month or after forty calendar
   days. Immediately repair duplicate, wrong-symbol, wrong-magic, wrong-side,
   or stopless owned exposure.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered MT5 D1 history, timestamps, calendar, quotes, symbol metadata, ATR,
positions, deals, and terminal-persistent state.

## Non-Duplicate Boundary

The fail-closed canonical checker scanned 4,664 registry identities, 1,315
cards, and 45 Strategy Wiki nodes. It found no exact match and one expected
fuzzy match to `wti-theilsen-tr_card.md` at `0.5833333333333334`. The receipt
is `artifacts/qm5_wti_mrobust3_agree_tr_preallocation_dedup_20260826.json`,
SHA-256
`469540A81B2615A7EAA97A071763BF72713D1B51B0934CEC02028F17D32F61F6`.

Manual review fixes a new conjunction rather than an alias:

- Theil-Sen, LAD, and repeated-median WTI systems each trade one estimator's
  strict sign. This rule computes all three and trades only their unanimous
  intersection.
- For `[0,.01,.06,.11,.14,.13,.11,.12,.09,.04,.02,.05,.10]`, Theil-Sen and
  LAD are positive while repeated median is negative. This rule is flat while
  every constituent takes a position.
- For `[0,.02,0,0,-.06,-.09,-.05,-.05,.03,.06,-.02,-.03,.05]`, LAD is
  negative while the other two are positive. This rule is again flat.
- For the strict line `y[i]=0.01*i`, all three slopes are `0.01` and this rule
  buys.
- Return-sign votes, endpoint, OLS, adjacent-return, range, flow, volatility,
  and calendar cards estimate different objects. Certified
  `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG oscillator
  pullback, not a monthly direct-WTI robust-slope conjunction.

The carrier, thirteen endpoints, all three full estimators, unanimous strict
sign, consumed month, fixed risk, and renewal clock are jointly load-bearing.
Verdict: `CLEAN_AFTER_EXPECTED_THEILSEN_FUZZY_AND_FUNCTIONAL_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_ENSEMBLE_TRANSLATION_RISK`. Named-author peer-reviewed
  trading and statistical records, complete-paper/preprint provenance where
  represented, DOI records, and explicit WTI membership. The exact ensemble
  is untested and labeled as such.
- R2: `PASS`. Observation order, all three estimators, counts, medians,
  objective, tie guard, signs, attempt, risk, stop, and lifecycle are exact.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered `XTIUSD.DWX` D1
  history plus native MT5 state supply every runtime input.
- R4: `PASS`. Deterministic logarithms, sorting, absolute loss, finite
  arithmetic, comparisons, ATR risk controls, and execution state only; no
  trained output, prohibited signal indicator, external feed, grid,
  martingale, scale-in, or pyramid.

## Claim, Kill, And Safety Boundary

The pre-result density prior is five to twelve completed positions per full
post-warm-up year and is not market evidence. Q02 must retire below five in
any full year, at zero trades, with nonpositive governed economics, or on any
statistical, consensus, attempt, risk, lifecycle, or determinism defect.

WTI supplies direct crude-oil exposure distinct from the current certified
XAU/SP500/NDX/XNG carriers, but no realized low-correlation claim is made.
Unchanged Q09 alone owns that verdict. No result may be rescued by changing
the carrier, sample, estimator, consensus, direction, risk, hold, or adding a
new gate.

This packet supports one Strategy Card, deterministic allocation, one branch-
only V5 build, strict compile/Q01, and one paced non-live Q02 handoff only. It
does not authorize a manual backtest, live artifact, `T_Live`, AutoTrading,
deploy manifest, portfolio-gate change, portfolio admission, correlation
waiver, terminal control, or claim that the sleeve is certified.
