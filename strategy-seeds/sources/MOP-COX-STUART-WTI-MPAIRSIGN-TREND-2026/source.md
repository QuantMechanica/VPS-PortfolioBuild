---
source_id: MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026
title: WTI fourteen-month Cox-Stuart paired-sign trend extraction
publisher: QuantMechanica governed extraction of peer-reviewed trading and statistical research
source_type: peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-26_wti_monthly_cox_stuart_paired_sign_trend_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-26
created_by: Research+Development
cards_extracted:
  - wti-coxstuart-tr
---

# WTI Fourteen-Month Cox-Stuart Paired-Sign Trend Source Packet

## Approved Sources Of Record

The trading lineage is Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje
Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. The complete governed
packet `strategy-seeds/sources/MOP-TSMOM-2012/source.md` records a complete
read of the 23-page author-hosted published paper, PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`,
monthly own-price continuation, and explicit NYMEX WTI membership.

The method lineage is D. R. Cox and Alan Stuart (1955), "Some Quick Sign
Tests for Trend in Location and Dispersion," *Biometrika* 42(1-2), 80-95,
DOI `10.1093/biomet/42.1-2.80`. The official Oxford Academic record at
`https://academic.oup.com/biomet/article-abstract/42/1-2/80/241199` confirms
the bibliographic metadata. Its body is paywalled and is not represented as
completely read.

The exact public algorithm record is the official NIST Dataplot reference,
"Cox Stuart Test," at
`https://itl.nist.gov/div898/software/dataplot/refman1/auxillar/coxstuar.htm`,
reviewed 2026-08-26. For ordered `X_1..X_n`, it defines `c=n/2` for even `n`,
pairs `X_i` with `X_(i+c)`, and applies a sign test to the paired differences.

These bounded records were reviewed before the durable OWNER approval at
`decisions/2026-08-26_wti_monthly_cox_stuart_paired_sign_trend_source_approval.md`.
No blocked body text, inferred source table, or ungoverned performance claim
is used.

## Source Findings Used

- Moskowitz, Ooi, and Pedersen test each instrument's own return at monthly
  lags, report broad first-year continuation, renew positions monthly, and
  explicitly include NYMEX WTI in the commodity universe.
- Cox and Stuart provide peer-reviewed sign-test-for-trend lineage.
- NIST fixes the even-sample half-to-half pairing used here: for fourteen
  ordered observations, pair indexes `0..6` with indexes `7..13`.

The records support a falsifiable monthly WTI own-price trend experiment and a
distribution-free paired-sign summary. They do not establish that a 5-of-7
threshold forecasts WTI or constitutes a conventional significance boundary.
The threshold, fourteen-endpoint sample, continuous-CFD mapping, fixed-dollar
risk, stop, spread cap, attempt state, and lifecycle are transparent QM
choices.

No source return, alpha, probability, Sharpe ratio, drawdown, trade density,
cost, WTI-only result, CFD equivalence, estimator superiority, statistical
significance, decorrelation, or portfolio-correlation statistic transfers.

## Exact Statistical Contract

For fourteen positive finite completed month-end closes `C[0]..C[13]`, oldest
to newest:

```text
y[i] = ln(C[i]), i = 0..13

positive = 0
negative = 0
for i = 0..6:
  d[i] = y[i+7] - y[i]
  require finite(d[i]) and d[i] != 0
  positive += 1 if d[i] > 0 else 0
  negative += 1 if d[i] < 0 else 0

require positive + negative == 7

BUY  iff positive >= 5
SELL iff negative >= 5
FLAT otherwise
```

Every pair spans exactly seven month indexes. The pairs use fourteen distinct
endpoints. The current decision month contributes no endpoint. A tie, invalid
count, 4/3 split, or nonfinite value consumes the month flat. Difference
magnitudes never change the decision or risk. There is no fallback to an
endpoint return, cumulative-horizon vote, adjacent-sign count, all-pairs
Mann-Kendall score, slope, regression, moving average, oscillator, calendar
direction, external series, or prior pipeline result.

The threshold is fixed from a density requirement before observing a market
result. In a fair independent-sign thought experiment only, the two directional
tails contain `2*(21+7+1)=58` of 128 sign vectors, or 45.3125%; twelve monthly
decisions would therefore imply 5.4375 qualifying paths/year. This calculation
is not evidence about WTI dependence, direction, or profitability.

## Exact Event And Execution Contract

1. Require exact `XTIUSD.DWX`, D1, slot zero, and an entry attempt no later
   than 180 elapsed minutes after the raw current D1 bar open in a genuine new
   broker month.
2. Persist the broker `yyyymm` before all fallible gates. A flat result,
   invalid state, reject, stop, or restart never retries the month.
3. Select the latest close in each of the immediately prior fourteen
   consecutive broker months. Require positive finite closes, strict
   chronology, the immediately prior newest month, and no more than ten
   calendar days of endpoint staleness. The current month contributes no
   signal close.
4. Compute exactly seven fixed Cox-Stuart differences and require at least
   five strict signs in one direction. Any tie or 4/3 split is flat.
5. Follow the qualified sign with at most one WTI position under
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

The fail-closed canonical checker scanned 4,666 registry identities, 1,317
cards, and 45 Strategy Wiki nodes. It found no exact or fuzzy match. The
receipt is `artifacts/qm5_wti_coxstuart_tr_preallocation_dedup_20260826.json`,
SHA-256 `60CFBF3306A8EC69CD34B439D8EDFF300B05BB644E705D89224FAE0C94ABE8B7`.

Manual review fixes a new statistic:

- The WTI Mann-Kendall card compares every ordered endpoint pair; this rule
  compares only the seven Cox-Stuart half-sample pairs.
- The quarterly vote card compares four three-month block returns; this rule
  compares seven seven-month paired differences.
- The monthly half-agreement card splits daily returns inside one completed
  month; this rule reads only fourteen completed month ends.
- The robust-slope cards retain magnitude and slope geometry; this rule
  discards magnitude after each fixed comparison.
- The first locked rank vector makes this rule buy while Mann-Kendall,
  endpoint, and quarterly-vote neighbors do not buy. The second makes this
  rule flat while all three neighbors buy. Exact vectors and scores are in the
  approval decision.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not monthly WTI paired-sign continuation.

The WTI carrier, fourteen consecutive endpoints, seven fixed lag-seven pairs,
strict no-tie rule, 5-of-7 directional count, consumed month, fixed risk, and
renewal clock are jointly load-bearing. Verdict:
`CLEAN_WTI_MONTHLY_COX_STUART_SEVEN_PAIR_FIVE_SIGN_TREND`.

## Reputable-Source Criteria

- R1: `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`. Named-author
  peer-reviewed WTI trading evidence with complete-paper provenance, official
  peer-reviewed Cox-Stuart record, and complete official NIST pairing
  description. The paywalled original method body and exact trading
  conjunction are not claimed as read or tested.
- R2: `PASS`. Observation order, pair indexes, count, ties, threshold,
  direction, attempt, risk, stop, and lifecycle are exact.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered `XTIUSD.DWX` D1
  history plus native MT5 state supply every runtime input.
- R4: `PASS`. Deterministic logarithms, comparisons, integer counts, finite
  arithmetic, calendar, ATR risk controls, and execution state only; no
  trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Claim, Kill, And Safety Boundary

The source supports testing monthly WTI trend using Cox-Stuart pairing, not
the efficacy or significance of the 5-of-7 trading rule. Q02 must retire below
five completed positions in any full post-warm-up year, at zero trades, with
nonpositive governed economics, or on a state, pair, tie, count, side, risk,
attempt, or lifecycle defect. Downstream gates alone own robustness and
correlation.

No failure may be rescued by changing the sample, pairing, threshold,
direction, carrier, stop, hold, spread cap, or retry contract. This packet
supports one V5 card, one non-live build, strict compile/Q01, and one paced
Q02 handoff only. It does not authorize a manual backtest, live artifact,
`T_Live`, AutoTrading, deploy manifest, portfolio-gate change, portfolio
admission, correlation waiver, terminal control, or claim that the sleeve is
already profitable, certified, or uncorrelated.
