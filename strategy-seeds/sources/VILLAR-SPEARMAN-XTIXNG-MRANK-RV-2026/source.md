---
source_id: VILLAR-SPEARMAN-XTIXNG-MRANK-RV-2026
title: XTI/XNG thirteen-month Spearman ratio-rank reversion extraction
publisher: QuantMechanica governed extraction of government, peer-reviewed, and pinned statistical research
source_type: government_peer_reviewed_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-27_xtixng_monthly_spearman_rank_reversion_source_approval.md
parent_source_ids:
  - VILLAR-RAMBERG-OILGAS-2026
  - MOP-SPEARMAN-WTI-MRANK-TREND-2026
parent_sha256:
  VILLAR-RAMBERG-OILGAS-2026: 4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604
  MOP-SPEARMAN-WTI-MRANK-TREND-2026: 38B53FD42A8E9CBA533957D5A376D8F8D4E5CA0F8EBB249D8464F761C8D2AB98
created: 2026-08-27
created_by: Research+Development
cards_extracted:
  - xtixng-mspearman-rv
---

# XTI/XNG Thirteen-Month Spearman Ratio-Rank Reversion Source Packet

## Approved Sources Of Record

The relationship parent is
`strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`. It preserves a
complete 43-page U.S. EIA report by Jose A. Villar and Frederick L. Joutz,
"The Relationship Between Crude Oil and Natural Gas Prices," and a complete
peer-reviewed article by David J. Ramberg and John E. Parsons, "The Weak Tie
Between Natural Gas and Oil Prices," *The Energy Journal* 33(2), DOI
`10.5547/01956574.33.2.2`. It also preserves adverse modern EIA evidence. The
records support a time-varying oil/gas linkage while rejecting a tight or
permanent fixed price ratio.

The method parent is
`strategy-seeds/sources/MOP-SPEARMAN-WTI-MRANK-TREND-2026/source.md`. It
preserves C. Spearman's named 1904 journal record and the complete R Core Team
`stats::cor` implementation and manual from public `wch/r-source` commit
`7344a2d9d96b3c2b997535d3abc8c3a44af16e82`. The pinned method
rank-transforms both inputs and computes ordinary correlation of those ranks.
The original Spearman body is not represented as completely read; no blocked
text, inferred table, or result is used.

Both bounded parents were read completely before the durable OWNER source
approval at
`decisions/2026-08-27_xtixng_monthly_spearman_rank_reversion_source_approval.md`.

## Source Findings Used

Villar-Joutz and Ramberg-Parsons support testing a state-dependent oil/gas
relationship without assuming a universal coefficient or fixed equilibrium.
Spearman and the pinned R Core files supply a deterministic rank-association
statistic.

The records support a falsifiable oil/gas ratio-reversion experiment, not a
claim that Spearman-ranked ratio drift predicts reversal. The thirteen-month
sample, strict no-tie rule, integer boundary, synchronized continuous-CFD
mapping, contrarian sides, equal-notional target, fixed-dollar risk, stops,
spread caps, atomic order sequence, consumed attempt, and lifecycle are
transparent QM choices.

No source return, alpha, probability, statistical significance, density,
Sharpe ratio, drawdown, cost, hedge ratio, neutrality, CFD equivalence,
decorrelation, or portfolio-correlation statistic transfers.

## Exact Statistical Contract

For thirteen positive, finite, exactly timestamp-matched completed month-end
close pairs, oldest to newest:

```text
s[i] = ln(XTI_close[i]) - ln(XNG_close[i]), i = 0..12
require every s[i] pairwise distinct

R[i] = strict rank of s[i] from 1 (smallest) to 13 (largest)
D = sum((R[i] - (i + 1))^2), i = 0..12
T = 364 - D

require sorted(R) = [1,2,...,13]
require 0 <= D <= 728
require -364 <= T <= 364
require D and T even

SELL XTI / BUY XNG iff T >= 104
BUY XTI / SELL XNG iff T <= -104
FLAT otherwise
```

This is algebraically identical to `rho=1-D/364` and
`abs(rho)>=2/7`. Exact ties are rejected rather than average-ranked and no
p-value is calculated. Signal magnitude above the boundary never changes
direction or risk. There is no fallback to endpoint displacement,
Cox-Stuart, Mann-Kendall, split-sample rank sums, change-point search, slope,
regression, rolling center or scale, oscillator, seasonal direction,
external series, or prior pipeline result.

The boundary was fixed before market testing. Exact enumeration of all
`13! = 6,227,020,800` no-tie rank permutations gives 2,139,842,508 qualifying
paths, split symmetrically. The rate `0.3436382463986631` implies about
4.1237 qualifying months per twelve decisions under random ordering only.
This is a density design fact, not evidence about oil/gas behavior.

## Exact Event And Execution Contract

1. Require exact host `XTIUSD.DWX`, companion `XNGUSD.DWX`, D1, and an entry
   attempt no later than 180 elapsed minutes after the raw current host D1 bar
   open in a genuine new broker month.
2. Persist current broker `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or order gates. Never retry the month after a
   flat signal, invalid state, reject, stop, partial fill, or restart.
3. From bounded native D1 buffers, select the latest exactly timestamp-matched
   close pair in each of the immediately prior thirteen consecutive broker
   months. Require positive finite closes, strict chronology, the immediately
   prior newest month, no current-month close, and no more than ten calendar
   days of endpoint staleness.
4. Compute thirteen oil-minus-gas log ratios, reject ties, assign strict
   ranks, prove every integer invariant, and fade only `abs(T)>=104`.
5. Open at most one equal-target-absolute-USD-notional package under aggregate
   `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Split stop
   risk equally and size each leg against its frozen `3.5*ATR(20,D1)` hard
   stop. Attach no target, cap spreads at 1,500 XTI points and 3,000 XNG
   points, and require realized notional mismatch no greater than 20%.
6. Submit XTI first and XNG second. Retain only one correctly directed,
   registered, stop-protected position in each slot. Flatten all owned legs
   after any partial or final package-validation failure.
7. Close both legs on the first tick in a later broker month or after forty
   calendar days. Immediately repair an orphaned, duplicated, same-side,
   wrong-symbol, wrong-magic, stopless, stale, or notional-invalid package.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered MT5 D1 histories, timestamps, calendar, quotes, symbol metadata,
ATR, positions, deals, terminal global variables, and V5 framework services.

## Canonical Non-Duplicate Adjudication

The fail-closed checker scanned 4,679 registry identities, 1,330 cards, and 45
Strategy Wiki nodes. It returned `CLEAN` with no exact or fuzzy match. The
receipt is
`artifacts/qm5_xtixng_mspearman_rv_preallocation_dedup_20260827.json`.

- `QM5_41173_wti-mspearman-tr` applies the same rank statistic to one outright
  WTI series, follows its sign, and owns one position. This packet constructs
  a synchronized paired-energy ratio, fades the sign, and owns an atomic
  equal-notional package.
- `QM5_41174_xauxag-mspearman-rv` uses the same statistic and contrarian
  lifecycle on a precious-metal carrier. This packet has no metal or index
  leg and targets energy-relative-value exposure.
- `QM5_41175_xtixng-mpettitt-rv` searches thirteen ranks for a unique central
  change point. `QM5_41178_xtixng-mwilcoxon-rv` compares every member of two
  fixed six-observation blocks. `QM5_41179_xtixng-mcoxstuart-rv` uses seven
  disjoint lag-seven signs. This packet uses every ratio's exact displacement
  from its absolute calendar rank and neither searches nor splits the path.
- `QM5_20237_xtixng-ecm-rv` fits a 252-D1 trend-augmented OLS residual and
  trades a z-score crossing. This packet estimates no coefficient, center,
  scale, or residual.
- Fixed-ratio z-score, return-spread, momentum, carry, calendar, tail,
  volatility, and factor-rank baskets consume different state objects.
- Certified `QM5_12567_cum-rsi2-commodity` is a two-day long-only XNG
  oscillator pullback, not a monthly paired-energy rank basket.

The paired carrier, thirteen consecutive synchronized ratios, strict ranks,
integer displacement score, fixed 104 boundary, contrarian sides, consumed
month, aggregate fixed risk, equal-notional target, atomic lifecycle, and
next-month exit are jointly load-bearing. Verdict:
`CLEAN_XTIXNG_MONTHLY_SPEARMAN_TIME_RATIO_RANK_T104_CONTRARIAN_BASKET`.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: complete government and
  peer-reviewed oil/gas evidence including adverse findings, named original
  Spearman record, and complete pinned R Core method files; exact trading
  conjunction disclosed untested.
- R2 `PASS`: clock, synchronization, ratio orientation, ranks, integer
  arithmetic, threshold, contrarian sides, attempt, aggregate risk,
  atomicity, and lifecycle are fixed.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  native XTI/XNG D1 histories and MT5 state supply every runtime input.
- R4 `PASS`: deterministic logarithms, ranks, integer arithmetic, calendar,
  ATR risk controls, and execution state only; no trained output, banned
  signal method, external runtime feed, grid, martingale, scale-in, or
  pyramid.

## Falsification And Safety Boundary

Retire or fail on any synchronization, endpoint, rank, parity, threshold,
side, attempt, fixed-risk, notional, atomicity, lifecycle, or determinism
defect; fewer than five completed packages in any full post-warm-up year;
zero trades; nonpositive governed economics; or downstream portfolio-
correlation rejection. No failed result may be rescued by changing the
sample, rank rule, threshold, direction, risk, hold, or by adding a filter.

Equal target notionals are market-neutral-style construction, not proof of
market, factor, dollar, beta, volatility, or portfolio neutrality. Q09 alone
owns realized overlap. This packet authorizes one G0 card, deterministic
allocation, one branch-only non-live build, strict Q01, and one paced logical-
basket Q02 enqueue only. It authorizes no manual backtest; live, demo, shadow,
stress, or optimization setfile; AutoTrading; `T_Live`; deploy or live
manifest; portfolio-gate change; portfolio admission; correlation waiver;
terminal process control; or second queue row.
