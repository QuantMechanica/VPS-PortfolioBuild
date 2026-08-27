---
source_id: VILLAR-COX-STUART-XTIXNG-MPAIRSIGN-RV-2026
title: XTI/XNG fourteen-month Cox-Stuart paired-sign ratio reversion extraction
publisher: QuantMechanica governed extraction of government, peer-reviewed, and official statistical research
source_type: government_peer_reviewed_official_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-27_xtixng_monthly_cox_stuart_paired_sign_reversion_source_approval.md
parent_source_ids:
  - VILLAR-RAMBERG-OILGAS-2026
  - MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026
parent_sha256:
  VILLAR-RAMBERG-OILGAS-2026: 4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604
  MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026: 7E0D0F9595CCBDB2CA2B2FEDD02BE2E969CC129CE293C48F44C42BDDC9CBC629
created: 2026-08-27
created_by: Research+Development
cards_extracted:
  - xtixng-mcoxstuart-rv
---

# XTI/XNG Fourteen-Month Cox-Stuart Paired-Sign Ratio Reversion Source Packet

## Approved Sources Of Record

The economic carrier packet is
`strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`. It preserves a
complete read of Jose A. Villar and Frederick L. Joutz (2006), *The
Relationship Between Crude Oil and Natural Gas Prices*, U.S. Energy
Information Administration, and a complete read of David J. Ramberg and John
E. Parsons (2012), "The Weak Tie Between Natural Gas and Oil Prices," *The
Energy Journal* 33(2), DOI `10.5547/01956574.33.2.2`. It also preserves the
complete adverse EIA record that oil and natural-gas markets can remain
regionally differentiated and weakly correlated.

The statistical-method packet is
`strategy-seeds/sources/MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026/source.md`.
It preserves D. R. Cox and Alan Stuart (1955), "Some Quick Sign Tests for
Trend in Location and Dispersion," *Biometrika* 42(1-2), DOI
`10.1093/biomet/42.1-2.80`, through the official publisher record and the
complete official NIST Dataplot "Cox Stuart Test" algorithm. The original
paper body is paywalled and is not represented as completely read. NIST fixes
`c=n/2` for an even ordered sample, pairs `X_i` with `X_(i+c)`, and applies a
sign test to those paired differences.

Both governed parent packets were read completely before the durable OWNER
source approval at
`decisions/2026-08-27_xtixng_monthly_cox_stuart_paired_sign_reversion_source_approval.md`.
No blocked body text, inferred source table, or ungoverned performance claim
is used.

## Source Findings Used

Villar-Joutz identify substitution, co-production, drilling, finance, and
oil-indexed LNG channels linking oil and natural gas, while documenting
temporary decoupling and model instability. Ramberg-Parsons reject a fixed
energy-content or price-ratio rule, find materially greater gas volatility,
and show that the relationship changes across regimes. EIA supplies adverse
modern context that the benchmarks can remain weakly tied. These records
support a falsifiable state-dependent relative-value carrier, not a permanent
equilibrium or a fixed hedge ratio.

Cox-Stuart and NIST supply a fixed distribution-free paired-sign summary. They
do not establish that a 5-of-7 sign threshold forecasts reversal in an
oil-minus-gas ratio. The fourteen-month sample, threshold, contrarian mapping,
synchronized CFD carrier, equal-notional construction, fixed-dollar risk,
stops, spread caps, atomic order sequence, attempt state, and lifecycle are
transparent QM hypotheses.

No source return, alpha, probability, statistical significance, trade density,
Sharpe ratio, drawdown, cost, hedge ratio, neutrality, CFD equivalence,
decorrelation, or portfolio-correlation statistic transfers.

## Exact Statistical Contract

For fourteen synchronized positive finite completed month-end close pairs,
oldest to newest:

```text
s[i] = ln(XTI_close[i]) - ln(XNG_close[i]), i = 0..13

positive = 0
negative = 0
for i = 0..6:
  d[i] = s[i+7] - s[i]
  require finite(d[i]) and d[i] != 0
  positive += 1 if d[i] > 0 else 0
  negative += 1 if d[i] < 0 else 0

require positive + negative == 7

SELL XTI / BUY XNG iff positive >= 5
BUY XTI / SELL XNG iff negative >= 5
FLAT otherwise
```

Every comparison spans exactly seven month indexes and all fourteen endpoints
are used exactly once. The current decision month contributes no endpoint. A
zero difference, invalid count, 4/3 split, or nonfinite value consumes the
month flat. Difference magnitudes never change direction or risk. There is no
fallback to endpoint displacement, rolling center or scale, cumulative vote,
all-pairs rank score, variable split, slope, regression, oscillator, external
series, calendar direction, or prior pipeline result.

The 5-of-7 boundary is fixed from a density requirement before market testing.
Under an explicitly non-empirical fair independent-sign thought experiment,
the two directional tails contain `2*(C(7,5)+C(7,6)+C(7,7))=58` of 128 sign
vectors, or 45.3125%. Twelve monthly decisions imply 5.4375 qualifying paths
per year under that thought experiment only. Real ratio signs are not asserted
independent or fair.

## Exact Event And Execution Contract

1. Require exact host `XTIUSD.DWX`, exact companion `XNGUSD.DWX`, D1, and one
   attempt no later than 180 elapsed minutes after the raw current host D1 bar
   open in a genuine new broker month.
2. Persist the broker `yyyymm` before history, signal, news, spread, quote,
   ATR, sizing, margin, or order gates. A flat result, invalid state, reject,
   stop, partial fill, or restart never retries the month.
3. From bounded native D1 buffers, retain the latest exactly timestamp-matched
   close pair in each of the immediately prior fourteen consecutive broker
   months. Require positive finite closes, strict chronology, the immediately
   prior newest month, and no more than ten calendar days of endpoint
   staleness. Exclude the current month.
4. Reverse the selected pairs into chronological order, compute fourteen
   oil-minus-gas log ratios and the seven fixed half-sample differences, and
   require at least five strict signs in one direction. Any zero difference or
   4/3 split consumes the month flat.
5. Fade a positive qualified sign with SELL XTI / BUY XNG and a negative
   qualified sign with BUY XTI / SELL XNG. Open at most one equal-target-
   absolute-USD-notional package under aggregate `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
6. Split the aggregate stop-risk budget equally and size each leg against its
   frozen `3.5*ATR(20,D1)` broker hard stop. Attach no target, cap entry spread
   at 1,500 XTI points and 3,000 XNG points, and require realized absolute-
   notional mismatch no greater than 20%.
7. Submit XTI first and XNG second. Retain the package only when exactly one
   correctly directed, registered, stop-protected position exists in each
   slot. Flatten all owned exposure immediately after any second-leg or final-
   package validation failure.
8. Close both legs on the first tick in a later broker month or after forty
   calendar days. Immediately repair an orphaned, duplicated, same-side,
   wrong-symbol, wrong-magic, stopless, stale, or notional-invalid package.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered native MT5 D1 histories, timestamps, calendar, quotes, symbol
metadata, ATR, positions, deals, and terminal-persistent state.

## Non-Duplicate Boundary

The fail-closed canonical checker authenticated 4,678 EA-registry rows, 1,329
card files, and 45 Company Reference Strategy Wiki nodes. It returned `CLEAN`
with no exact or fuzzy match. Evidence is
`artifacts/qm5_xtixng_mcoxstuart_rv_preallocation_dedup_20260827.json`, SHA-256
`E75E18D836E67A898CE5B6EFC6E3D8FC545862DBC5E21F1B01D954F7118DF429`.

Manual functional review fixes a new carrier/statistic conjunction:

- `QM5_41167_wti-coxstuart-tr` uses the same seven fixed comparisons on one
  outright WTI series, follows the sign, and owns one position. This candidate
  constructs a synchronized oil-minus-gas ratio, fades the sign, and owns an
  atomic equal-notional package.
- `QM5_41168_xauxag-mcoxstuart-rv` uses the same statistic and contrarian
  lifecycle on a precious-metal carrier. This candidate is the energy
  relative-value implementation specifically requested to diversify the
  directional index/metal/XNG book; no metal leg is present.
- `QM5_41175_xtixng-mpettitt-rv` scans thirteen ranks for one unique central
  maximum. `QM5_41178_xtixng-mwilcoxon-rv` compares every member of two fixed
  six-ratio blocks. This candidate makes exactly seven disjoint lag-seven
  comparisons and discards magnitude after each comparison.
- On ratio ranks `[1,12,13,6,3,0,5,8,2,4,7,11,9,10]*0.01`, five of seven
  Cox-Stuart pairs rise, so this candidate shorts the ratio. Pettitt is flat
  because its maximum occurs at edge split `K=2`; Mann-Whitney is flat at
  `U_new=22`.
- On ratio ranks `[13,1,11,9,12,3,7,4,2,0,5,10,6,8]*0.01`, Cox-Stuart is flat
  at 3/4, while Pettitt and Mann-Whitney both buy the ratio (`K=4`,
  `U_new=11`).
- Certified `QM5_12567_cum-rsi2-commodity` is a two-day long-only XNG
  oscillator pullback with neither an XTI hedge nor monthly paired-sign state.

Verdict:
`CLEAN_XTIXNG_MONTHLY_COX_STUART_SEVEN_PAIR_FIVE_SIGN_RATIO_REVERSION`.

## Reputable-Source Criteria

- R1: `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`. Complete government and
  peer-reviewed oil/gas relationship evidence including adverse findings, a
  named peer-reviewed Cox-Stuart record, and a complete official NIST method
  description. The exact conjunction is explicitly untested.
- R2: `PASS`. Clock, synchronization, fourteen ratios, seven fixed pairs, tie
  rule, threshold, contrarian sides, durable attempt, aggregate risk, stops,
  atomicity, and exits are deterministic and locked.
- R3: `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` and `XNGUSD.DWX` D1 histories plus native MT5 state supply every
  runtime input.
- R4: `PASS`. Deterministic timestamps, logarithms, comparisons, integer sign
  counts, ATR risk controls, and execution state only; no trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Claim, Kill, And Safety Boundary

The pre-result density prior is five to eight completed packages per full
post-warm-up year. Q02 must retire below five completed packages in any full
post-warm-up year, at zero trades, with nonpositive governed economics, or on
any timestamp, month, ratio, pair, tie, count, side, attempt, risk, atomicity,
lifecycle, or determinism defect.

Opposite equal-notional legs reduce some common outright-energy direction but
do not prove dollar, beta, volatility, factor, market, or portfolio neutrality.
Q09 alone owns realized book correlation. No failed result may be rescued by
changing the sample, pairing, threshold, direction, carrier, risk, hold, or by
adding endpoint, regression, volatility, event, seasonal, external, or prior-
result state.

This packet supports one V5 card, one branch-only non-live build, strict
compile/Q01, and one paced logical-basket Q02 enqueue. It excludes manual
backtests; live, demo, shadow, stress, or optimization setfiles; AutoTrading;
`T_Live`; deploy or T_Live manifests; portfolio-gate changes; portfolio
admission; correlation waivers; terminal control; and any claim that the edge
is already profitable, certified, or uncorrelated.
