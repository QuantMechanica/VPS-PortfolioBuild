---
source_id: MOP-SIEGEL-WTI-REPMEDIAN-2026
title: WTI thirteen-month repeated-median robust-trend extraction
publisher: QuantMechanica governed extraction of peer-reviewed trading and statistical research
source_type: peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-25_wti_monthly_repeated_median_trend_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
  - MOP-WTI-THEILSEN-2026
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
  MOP-WTI-THEILSEN-2026: F83880B74B1DB645F6C20A58B76825DA96787E327C461D0E798CA01CAB72535E
created: 2026-08-25
created_by: Research+Development
cards_extracted: []
---

# WTI Thirteen-Month Repeated-Median Robust-Trend Source Packet

## Approved Sources Of Record

The trading source is Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje
Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`.

The governed packet `strategy-seeds/sources/MOP-TSMOM-2012/source.md`
preserves a complete read of the 23-page published paper from author Lasse
Heje Pedersen's NYU faculty site. Its retrieval receipt records 976,459 bytes,
23 pages, PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`,
and the complete scope including appendices and references. The packet itself
has SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

The statistical-method record is Andrew F. Siegel (1982), "Robust Regression
Using Repeated Medians," *Biometrika* 69(1), 242-244, DOI
`10.1093/biomet/69.1.242`. The complete official Oxford Academic
bibliographic and abstract record was read on 2026-08-25 at
`https://academic.oup.com/biomet/article-abstract/69/1/242/243029`. It
identifies the repeated-median algorithm as a nested-median robust regression
family and reports its high breakdown property. The paywalled paper body was
not used or represented as completely read.

The governed arithmetic and lifecycle precedent is
`strategy-seeds/sources/MOP-WTI-THEILSEN-2026/source.md`, SHA-256
`F83880B74B1DB645F6C20A58B76825DA96787E327C461D0E798CA01CAB72535E`.
It fixes the WTI carrier, thirteen consecutive completed month ends,
chronological log-price slopes, monthly attempt, fixed risk, ATR stop, spread
cap, and next-month exit. Its global median-of-78-slopes estimator does not
transfer.

All bounded records were read completely before the durable OWNER source
approval at
`decisions/2026-08-25_wti_monthly_repeated_median_trend_source_approval.md`,
commit `eda96a83f`. No blocked source body, inferred table value, or
ungoverned performance claim is used.

## Source Findings Used

- Section 3.1 of Moskowitz, Ooi, and Pedersen tests each instrument's own
  return at monthly lags one through sixty and reports positive continuation
  over the first twelve monthly lags.
- Section 3.2 forms mechanical time-series-momentum positions from own past
  returns and renews them monthly.
- Appendix A includes NYMEX WTI crude among the commodity futures.
- The source uses rolling liquid futures, excess returns, and ex ante
  volatility scaling; it does not test a Darwinex continuous CFD.
- The Oxford record supplies only the statistical lineage that repeated
  medians use nested medians and are designed for robust bivariate regression.

These findings support a falsifiable test of slow WTI own-price direction
through a robust slope functional. They do not establish this exact estimator,
its direction, its parameters, or its trading performance.

## Bounded QM Mechanization

At the first executable D1 tick of a genuine broker-month transition,
reconstruct thirteen consecutive completed `XTIUSD.DWX` month-end closes,
oldest to newest. Take each close's natural logarithm. For each endpoint as a
pivot, calculate the twelve forward-oriented slopes that join it to every
other endpoint. Take the even-sample median of each pivot's twelve slopes,
then take the odd-sample median of the thirteen pivot medians. Buy when that
repeated median is positive, sell when it is negative, and consume the month
flat when it is exactly zero or invalid. Renew at the next broker-month
boundary.

The thirteen-point sample, discrete month-index denominator, two median
conventions, continuous-CFD mapping, fixed-risk sizing, hard stop, spread cap,
attempt ledger, and lifecycle are transparent QM choices. No source return,
alpha, probability, Sharpe ratio, drawdown, trade count, cost, WTI-only
result, CFD equivalence, robustness improvement, or portfolio-correlation
statistic transfers.

## Exact Statistical Contract

For thirteen positive finite completed month-end closes `C[0]..C[12]`,
oldest to newest:

```text
y[i] = ln(C[i]), i = 0..12

for i = 0..12:
  k = 0
  for j = 0..12, j != i:
    lo = min(i,j)
    hi = max(i,j)
    pivot_slope[k] = (y[hi] - y[lo]) / (hi - lo)
    k += 1
  require k == 12
  sorted_pivot = ascending(pivot_slope[0..11])
  pivot_median[i] = (sorted_pivot[5] + sorted_pivot[6]) / 2

require thirteen finite pivot medians
sorted_medians = ascending(pivot_median[0..12])
repeated_median = sorted_medians[6]

signal = BUY  when repeated_median > 0
         SELL when repeated_median < 0
         FLAT when repeated_median == 0 or state is invalid
```

Every inner denominator is the positive integer forward distance between two
month indexes. Each unordered endpoint pair therefore contributes the same
slope to the two pivot groups that contain its endpoints. There are exactly
156 grouped slope observations, representing 78 unique endpoint pairs twice.
There is no averaging across pivot medians, threshold, confidence score,
fallback to the global slope median, endpoint return, OLS, rank score, moving
average, oscillator, calendar state, external series, or previous result.
Signal magnitude never changes risk.

## Exact Event And Execution Contract

1. Require exact `XTIUSD.DWX`, D1, slot zero, and an entry attempt no later
   than 180 elapsed minutes after the raw current D1 bar open in a genuine new
   broker month.
2. Persist the broker `yyyymm` as consumed before history, signal, news,
   spread, quote, ATR, sizing, margin, or order checks. A flat result, invalid
   state, reject, stop, or restart never retries the month.
3. From a bounded native D1 buffer, retain exactly the latest close in each of
   the immediately prior thirteen consecutive broker months. Reject missing
   or duplicate month keys, nonchronological timestamps, nonpositive closes,
   or a newest endpoint more than ten calendar days stale.
4. Reverse the selected endpoints into strict chronological order, compute
   thirteen finite log prices, all twelve slopes in every pivot group, all
   thirteen inner medians, and the one outer median. No alternate statistic or
   agreement filter is allowed.
5. Follow the strict repeated-median sign with one WTI position. Exact zero or
   invalid arithmetic consumes the month flat.
6. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Size
   against a frozen `3.5*ATR(20,D1)` broker hard stop, attach no target, and
   cap entry spread at 1,500 points.
7. Retain only one correctly directed, correctly registered, stop-protected
   position. Close on the first tick in a later broker month or after forty
   calendar days. Immediately repair duplicate, wrong-symbol, wrong-magic,
   wrong-side, or stopless owned exposure.

Both news axes, legacy news mode, and Friday close are OFF for the monthly
hold. Runtime uses only registered MT5 D1 history, timestamps, calendar,
quotes, symbol metadata, ATR, positions, deals, and terminal-persistent state.

## Non-Duplicate Boundary

The fail-closed canonical checker scanned 4,657 registry identities, 1,309
card files, and 45 Strategy Wiki nodes. Its only fuzzy result was
`QM5_20271_wti-theilsen-tr` at score `0.6153846153846154`. The receipt is
`artifacts/qm5_wti_repmedian_tr_preallocation_dedup_20260825.json`, SHA-256
`6AFA0C63B92F90CE78740F10798BEF89FE1B8CCFE5802BE2D03458C7287AC654`.

Manual semantic and functional review fixes a new mechanic:

- Theil-Sen pools 78 unique slopes and takes one global even-sample median.
  This rule takes thirteen separate medians over pivot-specific groups and
  then an outer median. Pair slopes have context and two-stage order-statistic
  influence rather than one pooled rank.
- The fixed log-price path
  `[0,.01,.06,.11,.14,.13,.11,.12,.09,.04,.02,.05,.10]` makes the existing
  Theil-Sen functional `+0.00155555555555556` and this repeated-median
  functional `-0.0045`. The two rules take opposite sides on the same valid
  inputs, proving they are not parameter aliases.
- OLS plus `R^2`, ordinal Mann-Kendall, adjacent-return median/trim/Winsor/
  Huber/Hodges-Lehmann, weighted-return, sign-vote, endpoint, and path-
  efficiency systems estimate different objects or use different aggregation.
- Certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback and shares neither carrier nor mechanic.

The WTI carrier, thirteen consecutive month-end log prices, pivot grouping,
twelve slopes per pivot, forward orientation, inner indexes 5/6, outer index
6, strict direction, consumed attempt, fixed risk, and monthly renewal are
jointly load-bearing. Verdict:
`CLEAN_AFTER_THEILSEN_FUZZY_MATCH_AND_SIGN_DIVERGENCE_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_ESTIMATOR_TRANSLATION_RISK`. Named authors, a complete-read
  peer-reviewed JFE trading paper with DOI and explicit WTI membership, plus
  an official peer-reviewed Biometrika method record with DOI. The conjunction
  is untested and labeled as such.
- R2: `PASS`. Endpoint count/order, logarithm, pivot membership, pair bounds,
  denominator, counts, both median stages, direction, attempt, fixed risk,
  hard stop, rollover, and stale exit are exact.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered `XTIUSD.DWX` D1
  history and native MT5 execution state supply every runtime input.
- R4: `PASS`. Deterministic logarithm, sorting, finite arithmetic, and native
  execution state only; no trained output, prohibited signal indicator,
  external runtime feed, grid, martingale, scale-in, or pyramid.

## Claim And Kill Boundary

The trading source supports testing an own-price WTI carrier, not the efficacy
of the repeated-median transformation. Q02 must retire the card below five
completed positions per full post-warm-up year or on nonpositive governed
economics. Downstream gates alone own robustness and correlation. No failure
may be rescued by changing the pivot definition, median convention, horizon,
direction, carrier, stop, hold, spread cap, or retry contract.

## Safety Boundary

This packet supports one Strategy Card, deterministic allocation, one branch-
only V5 build, strict compile/Q01, and one paced non-live Q02 handoff only. It
does not authorize a manual backtest, live artifact, `T_Live`, AutoTrading,
deploy manifest, portfolio-gate change, portfolio admission, correlation
waiver, terminal control, or claim that the sleeve is already uncorrelated.
