---
source_id: SCHWEIKERT-COX-STUART-CME-XAUXAG-MPAIRSIGN-RV-2026
title: XAU/XAG fourteen-month Cox-Stuart paired-sign ratio reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed, exchange, and official statistical research
source_type: peer_reviewed_exchange_official_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-26_xauxag_monthly_cox_stuart_paired_sign_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026
  - MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026
parent_sha256:
  SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026: D5E8C4CD0112724D66E64C13B20B7B41CCE1B4CDC2061BA21A979374F04531A8
  MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026: 7E0D0F9595CCBDB2CA2B2FEDD02BE2E969CC129CE293C48F44C42BDDC9CBC629
created: 2026-08-26
created_by: Research+Development
cards_extracted:
  - xauxag-mcoxstuart-rv
---

# XAU/XAG Fourteen-Month Cox-Stuart Paired-Sign Ratio Reversion Source Packet

## Approved Sources Of Record

The primary relationship source is Karsten Schweikert (2018), "Are gold and
silver cointegrated? New evidence from quantile cointegrating regressions,"
*Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`.

The governed composite packet
`strategy-seeds/sources/SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026/source.md`
preserves the named peer-reviewed gold/silver evidence and the official CME
Group "Gold & Silver Ratio Spread" carrier evidence. It records complete reads
of its bounded parent packets. The findings used here are deliberately narrow:
gold and silver can have a related but state-dependent long-run relation; CME
presents their ratio as an intermarket spread; and the two metals share some
precious-metal and USD drivers while differing in monetary, safe-haven,
industrial, and business-cycle exposure.

The method packet is
`strategy-seeds/sources/MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026/source.md`.
It preserves D. R. Cox and Alan Stuart (1955), "Some Quick Sign Tests for Trend
in Location and Dispersion," *Biometrika* 42(1-2), 80-95, DOI
`10.1093/biomet/42.1-2.80`, through the official publisher record and the
complete official NIST Dataplot "Cox Stuart Test" algorithm. The original
paper body is paywalled and is not represented as completely read. The NIST
record fixes `c=n/2` for an even ordered sample, pairs `X_i` with `X_(i+c)`,
and applies a sign test to the paired differences.

Both governed packets were read completely before the durable OWNER source
approval at
`decisions/2026-08-26_xauxag_monthly_cox_stuart_paired_sign_reversion_source_approval.md`.
No blocked body text, inferred source table, or ungoverned performance claim is
used.

## Source Findings Used

Schweikert supports testing a related but state-dependent gold/silver price
relation while warning against assuming a universal constant equilibrium. CME
supports the intermarket-ratio carrier and identifies an economic reason for
relative displacement: gold and silver share some broad drivers but have
different use and demand profiles. Cox-Stuart and NIST supply a fixed,
distribution-free paired-sign trend summary.

These records support a falsifiable ratio-reversion experiment, not a claim
that a 5-of-7 Cox-Stuart direction predicts reversal. The exact fourteen-month
sample, threshold, synchronized CFD mapping, contrarian sides, fixed-dollar
risk, stops, spread caps, atomic order sequence, attempt state, and lifecycle
are transparent QM choices.

No source return, alpha, probability, statistical significance, trade density,
Sharpe ratio, drawdown, cost, hedge ratio, neutrality, CFD equivalence,
decorrelation, or portfolio-correlation statistic transfers.

## Exact Statistical Contract

For fourteen synchronized, positive, finite completed month-end close pairs,
oldest to newest:

```text
s[i] = ln(XAU_close[i]) - ln(XAG_close[i]), i = 0..13

positive = 0
negative = 0
for i = 0..6:
  d[i] = s[i+7] - s[i]
  require finite(d[i]) and d[i] != 0
  positive += 1 if d[i] > 0 else 0
  negative += 1 if d[i] < 0 else 0

require positive + negative == 7

SELL XAU / BUY XAG iff positive >= 5
BUY XAU / SELL XAG iff negative >= 5
FLAT otherwise
```

Every pair spans exactly seven month indexes and the seven comparisons use all
fourteen endpoints exactly once. The current decision month contributes no
endpoint. A tie, invalid count, 4/3 split, or nonfinite value consumes the
month flat. Difference magnitudes never change direction or risk. There is no
fallback to endpoint displacement, cumulative-horizon vote, adjacent-sign
count, all-pairs Mann-Kendall score, slope, regression, rolling center or
scale, oscillator, calendar direction, external series, or prior pipeline
result.

The threshold is fixed from a density requirement before observing a market
result. In a fair independent-sign thought experiment only, the two
directional tails contain `2*(21+7+1)=58` of 128 sign vectors, or 45.3125%.
Twelve monthly decisions would therefore imply 5.4375 qualifying paths/year.
This calculation is not evidence about gold/silver dependence, direction, or
profitability.

## Exact Event And Execution Contract

1. Require exact host `XAUUSD.DWX`, exact companion `XAGUSD.DWX`, D1, and an
   entry attempt no later than 180 elapsed minutes after the raw current host
   D1 bar open in a genuine new broker month.
2. Persist the broker `yyyymm` before every fallible gate. A flat result,
   invalid state, reject, stop, partial fill, or restart never retries the
   month.
3. From a bounded native D1 buffer, select the latest exactly timestamp-
   matched close pair in each of the immediately prior fourteen consecutive
   broker months. Require positive finite closes, strict chronology, the
   immediately prior newest month, and no more than ten calendar days of
   newest-endpoint staleness. The current month contributes no signal close.
4. Reverse the selected pairs into chronological order, compute the fourteen
   gold-minus-silver log ratios and exactly seven fixed half-sample
   differences, and require at least five strict signs in one direction. Any
   tie or 4/3 split is flat.
5. Fade a positive qualified sign with SELL XAU / BUY XAG and a negative
   qualified sign with BUY XAU / SELL XAG. Open at most one equal-target-
   absolute-USD-notional package under aggregate `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
6. Split the aggregate stop-risk budget equally and size each leg against its
   frozen `3.5*ATR(20,D1)` broker hard stop. Attach no target, cap spread at
   1,500 XAU points and 500 XAG points, and require realized absolute-notional
   mismatch no greater than 20%.
7. Submit XAU first and XAG second. Retain the package only when exactly one
   correctly directed, registered, stop-protected position exists in each
   slot. Flatten every owned leg immediately after any second-leg or final-
   package validation failure.
8. Close both legs on the first tick in a later broker month or after forty
   calendar days. Immediately repair an orphaned, duplicated, same-side,
   wrong-symbol, wrong-magic, stopless, stale, or notional-invalid package.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered MT5 D1 histories, timestamps, calendar, quotes, symbol metadata,
ATR, positions, deals, and terminal-persistent state.

## Non-Duplicate Boundary

The fail-closed canonical checker scanned 4,667 registry identities, 1,318
cards, and 45 Strategy Wiki nodes. It found no exact or fuzzy match. The
receipt is
`artifacts/qm5_xauxag_mcoxstuart_rv_preallocation_dedup_20260826.json`,
SHA-256 `B89423A13EFCE50F40FE8977561924FADA69281C8ACAFB475AEC6B8D701BE594`.

Manual review fixes a new statistic:

- `QM5_41167_wti-coxstuart-tr` applies the same fixed comparisons to one
  outright WTI series, follows the sign, and owns one position. This packet
  constructs a synchronized paired-metal ratio, fades the sign, and owns an
  atomic equal-notional package.
- The XAU/XAG Theil-Sen, LAD, repeated-median, and robust-three cards retain
  ratio-path magnitude and slope geometry. This rule discards magnitude after
  seven disjoint comparisons and computes no slope.
- Endpoint return, Mann-Kendall, quarterly block-vote, within-month half,
  sign-breadth, path, sequence, location, regression, quantile, and z-score
  cards observe different state objects.
- The first locked fourteen-point rank vector makes this rule short the ratio
  while endpoint, Mann-Kendall, and quarterly-vote neighbors do not share that
  action. The second makes this rule flat while all three neighbors qualify a
  short-ratio action. Exact vectors and scores are in the approval decision.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not a monthly paired-metal sign-reversion package.

The paired carrier, fourteen consecutive synchronized month-end ratios, fixed
seven lag-seven comparisons, strict no-tie rule, 5-of-7 contrarian count,
durable consumed month, equal-notional aggregate fixed risk, atomic lifecycle,
and next-month exit are jointly load-bearing. Verdict:
`CLEAN_XAUXAG_MONTHLY_COX_STUART_SEVEN_PAIR_FIVE_SIGN_RATIO_REVERSION`.

## Reputable-Source Criteria

- R1: `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`. Named-author peer-
  reviewed gold/silver research with DOI, official exchange carrier research,
  an official peer-reviewed Cox-Stuart record, and a complete official NIST
  pairing description. The exact trading conjunction is untested.
- R2: `PASS`. Observation order, synchronization, pair indexes, count, ties,
  threshold, contrarian sides, attempt, aggregate risk, stops, atomicity, and
  lifecycle are exact.
- R3: `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state supply every
  runtime input.
- R4: `PASS`. Deterministic timestamps, logarithms, comparisons, integer sign
  counts, finite arithmetic, calendar, ATR risk controls, and execution state
  only; no trained output, banned signal indicator, external runtime feed,
  grid, martingale, scale-in, or pyramid.

## Claim, Kill, And Safety Boundary

The source supports testing a monthly gold/silver relative-value reversion
using Cox-Stuart pairing, not the efficacy or significance of the 5-of-7
trading rule. Q02 must retire below five completed packages in any full post-
warm-up year, at zero trades, with nonpositive governed economics, or on a
timestamp, month, ratio, pair, tie, count, side, risk, attempt, atomicity, or
lifecycle defect. Downstream gates alone own robustness and correlation.

Opposite equal-notional legs reduce some common outright-metal direction but
do not prove dollar, beta, volatility, factor, market, or portfolio neutrality.
No failure may be rescued by changing the sample, pairing, threshold,
direction, carrier, stop, hold, spread caps, or retry contract.

This packet supports one V5 card, deterministic allocation, one branch-only
non-live build, strict compile/Q01, and one paced logical-basket Q02 handoff
only. It does not authorize a manual backtest, live artifact, `T_Live`,
AutoTrading, deploy manifest, portfolio-gate change, portfolio admission,
correlation waiver, terminal control, or claim that the sleeve is already
profitable, certified, or uncorrelated.
