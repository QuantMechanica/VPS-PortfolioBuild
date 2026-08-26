---
source_id: SCHWEIKERT-SPEARMAN-CME-XAUXAG-MRANK-RV-2026
title: XAU/XAG thirteen-month Spearman ratio-rank reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed, exchange, and pinned statistical research
source_type: peer_reviewed_exchange_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-27_xauxag_monthly_spearman_rank_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026
  - MOP-SPEARMAN-WTI-MRANK-TREND-2026
parent_sha256:
  SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026: D5E8C4CD0112724D66E64C13B20B7B41CCE1B4CDC2061BA21A979374F04531A8
  MOP-SPEARMAN-WTI-MRANK-TREND-2026: 38B53FD42A8E9CBA533957D5A376D8F8D4E5CA0F8EBB249D8464F761C8D2AB98
created: 2026-08-27
created_by: Research+Development
cards_extracted:
  - xauxag-mspearman-rv
---

# XAU/XAG Thirteen-Month Spearman Ratio-Rank Reversion Source Packet

## Approved Sources Of Record

The relationship source is Karsten Schweikert (2018), "Are gold and silver
cointegrated? New evidence from quantile cointegrating regressions,"
*Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`. The governed parent packet
`strategy-seeds/sources/SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026/source.md`
preserves the named peer-reviewed evidence and official CME Group
"Gold & Silver Ratio Spread" carrier research. It records that gold and
silver can have a related but state-dependent long-run relation, share some
precious-metal and USD drivers, and differ in monetary, safe-haven,
industrial, and business-cycle exposure.

The method parent is
`strategy-seeds/sources/MOP-SPEARMAN-WTI-MRANK-TREND-2026/source.md`. It
preserves C. Spearman (1904), "The Proof and Measurement of Association
between Two Things," *The American Journal of Psychology* 15(1), DOI
`10.2307/1412159`, and the complete R Core Team `stats::cor` implementation
and manual from public `wch/r-source` commit
`7344a2d9d96b3c2b997535d3abc8c3a44af16e82`. The pinned method rank-
transforms both inputs and computes ordinary correlation of those ranks. The
original Spearman body is not represented as completely read; no blocked
text, inferred table, or result is used.

Both parents were read completely before the durable OWNER source approval
at
`decisions/2026-08-27_xauxag_monthly_spearman_rank_reversion_source_approval.md`.

## Source Findings Used

Schweikert supports testing a related but state-dependent gold/silver
relation without assuming a universal fixed equilibrium. CME supports the
intermarket-ratio carrier and distinct demand drivers. Spearman and the
pinned R Core files supply a deterministic rank association statistic.

The records support a falsifiable ratio-reversion experiment, not a claim
that Spearman-ranked ratio drift predicts reversal. The thirteen-month
sample, strict no-tie rule, integer boundary, synchronized CFD mapping,
contrarian sides, equal-notional target, fixed-dollar risk, stops, spread
caps, atomic order sequence, consumed attempt, and lifecycle are transparent
QM choices.

No source return, alpha, probability, statistical significance, density,
Sharpe ratio, drawdown, cost, hedge ratio, neutrality, CFD equivalence,
decorrelation, or portfolio-correlation statistic transfers.

## Exact Statistical Contract

For thirteen positive, finite, exactly timestamp-matched completed month-end
close pairs, oldest to newest:

```text
s[i] = ln(XAU_close[i]) - ln(XAG_close[i]), i = 0..12
require every s[i] pairwise distinct

R[i] = strict rank of s[i] from 1 (smallest) to 13 (largest)
D = sum((R[i] - (i + 1))^2), i = 0..12
T = 364 - D

require sorted(R) = [1,2,...,13]
require 0 <= D <= 728
require -364 <= T <= 364
require D and T even

SELL XAU / BUY XAG iff T >= 104
BUY XAU / SELL XAG iff T <= -104
FLAT otherwise
```

This is algebraically identical to `rho=1-D/364` and
`abs(rho)>=2/7`. Exact ties are rejected rather than average-ranked and no
p-value is calculated. Signal magnitude above the boundary never changes
direction or risk. There is no fallback to endpoint displacement,
Cox-Stuart, Mann-Kendall, slope, regression, rolling center or scale,
oscillator, seasonal direction, external series, or prior pipeline result.

The boundary was fixed before market testing. Exact enumeration of all
`13! = 6,227,020,800` no-tie rank permutations gives 2,139,842,508 qualifying
paths, split symmetrically. The rate `0.3436382463986631` implies about
4.1237 qualifying months per twelve decisions under random ordering only.
This is a density design fact, not evidence about gold/silver behavior.

## Exact Event And Execution Contract

1. Require exact host `XAUUSD.DWX`, companion `XAGUSD.DWX`, D1, and an entry
   attempt no later than 180 elapsed minutes after the raw current host D1 bar
   open in a genuine new broker month.
2. Persist current broker `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or order gates. Never retry the month after a
   flat signal, invalid state, reject, stop, partial fill, or restart.
3. From bounded native D1 buffers, select the latest exactly timestamp-
   matched close pair in each of the immediately prior thirteen consecutive
   broker months. Require positive finite closes, strict chronology, the
   immediately prior newest month, no current-month close, and no more than
   ten calendar days of endpoint staleness.
4. Compute thirteen gold-minus-silver log ratios, reject ties, assign strict
   ranks, prove all integer invariants, and fade only `abs(T)>=104`.
5. Open at most one equal-target-absolute-USD-notional package under aggregate
   `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Split the
   stop-risk budget equally and size each leg against its frozen
   `3.5*ATR(20,D1)` hard stop. Attach no target, cap spreads at 1,500 XAU
   points and 500 XAG points, and require realized notional mismatch no
   greater than 20%.
6. Submit XAU first and XAG second. Retain only one correctly directed,
   registered, stop-protected position in each slot. Flatten all owned legs
   after any partial or final package validation failure.
7. Close both legs on the first tick in a later broker month or after forty
   calendar days. Immediately repair an orphaned, duplicated, same-side,
   wrong-symbol, wrong-magic, stopless, stale, or notional-invalid package.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered MT5 D1 histories, timestamps, calendar, quotes, symbol metadata,
ATR, positions, deals, terminal global variables, and V5 framework services.

## Non-Duplicate Boundary

The fail-closed canonical checker scanned 4,673 registry identities, 1,324
cards, and 45 Strategy Wiki nodes. It found no exact or fuzzy match. The
receipt is
`artifacts/qm5_xauxag_mspearman_rv_preallocation_dedup_20260827.json`.

- `QM5_41173_wti-mspearman-tr` applies the same rank statistic to one outright
  WTI series, follows its sign, and owns one position. This packet constructs
  a synchronized paired-metal ratio, fades the sign, and owns an atomic
  equal-notional package.
- `QM5_41168_xauxag-mcoxstuart-rv` uses fourteen ratios and seven fixed
  half-sample sign comparisons. This rule uses thirteen ratios and every
  observation's exact time-rank displacement.
- XAU/XAG z-score, OLS, CADF, quantile, MAD, variance-ratio, endpoint,
  quarterly-vote, Theil-Sen, LAD, repeated-median, and robust-consensus
  families calculate different state objects and thresholds.
- Rank vector `[3,2,10,1,4,12,11,8,7,9,6,5,13]` gives `T=170` here but an
  existing thirteen-point Mann-Kendall score of only `20`. Vector
  `[13,1,4,12,5,2,3,6,7,8,9,10,11]` gives `T=98` here while Mann-Kendall
  reaches `28`.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not a monthly paired-metal rank basket.

The paired carrier, thirteen consecutive synchronized ratios, strict ranks,
integer displacement score, fixed 104 boundary, contrarian sides, consumed
month, aggregate fixed risk, equal-notional target, atomic lifecycle, and
next-month exit are jointly load-bearing. Verdict:
`CLEAN_XAUXAG_MONTHLY_SPEARMAN_TIME_RATIO_RANK_T104_CONTRARIAN_BASKET`.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: peer-reviewed
  gold/silver relation evidence, official exchange carrier research, named
  original Spearman record, and complete pinned R Core method files; exact
  trading rule untested.
- R2 `PASS`: clock, synchronization, ratio orientation, ranks, integer
  arithmetic, threshold, contrarian sides, attempt, aggregate risk,
  atomicity, and lifecycle are fixed.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  native XAU/XAG D1 histories and MT5 state supply all runtime inputs.
- R4 `PASS`: deterministic logarithms, ranks, integer arithmetic, calendar,
  and execution state only; no trained output, banned signal method,
  external feed, grid, martingale, scale-in, or pyramid.

## Falsification And Safety Boundary

Retire or fail on any synchronization, endpoint, rank, parity, threshold,
side, attempt, fixed-risk, notional, atomicity, lifecycle, or determinism
defect; fewer than four completed packages in any full post-warm-up year;
zero trades; nonpositive governed economics; or downstream portfolio-
correlation rejection. No failed result may be rescued by changing the
sample, rank rule, threshold, direction, risk, hold, or by adding a filter.

Equal target notionals are market-neutral-style construction, not proof of
market, factor, dollar, beta, volatility, or portfolio neutrality. Q09 alone
owns realized overlap. This packet authorizes no manual backtest; live,
demo, shadow, stress, or optimization setfile; AutoTrading; `T_Live`; deploy
or live manifest; portfolio-gate change; portfolio admission; correlation
waiver; or terminal process control.
