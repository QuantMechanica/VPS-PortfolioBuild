---
source_id: VILLAR-PETTITT-XTIXNG-MSHIFT-RV-2026
title: XTI/XNG thirteen-month Pettitt ratio change-point reversion extraction
publisher: QuantMechanica governed extraction of government and peer-reviewed research
source_type: government_peer_reviewed_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-27_xtixng_monthly_pettitt_ratio_reversion_source_approval.md
parent_source_ids:
  - VILLAR-RAMBERG-OILGAS-2026
  - MOP-PETTITT-WTI-MSHIFT-TREND-2026
parent_sha256:
  VILLAR-RAMBERG-OILGAS-2026: 4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604
  MOP-PETTITT-WTI-MSHIFT-TREND-2026: A80A6F6C87C7FB1D5D9E4911A36C5CAFE7005319F4C844F0550B697577BA3C98
created: 2026-08-27
created_by: Research+Development
cards_extracted:
  - xtixng-mpettitt-rv
---

# XTI/XNG Thirteen-Month Pettitt Ratio Change-Point Reversion Source Packet

## Approved Sources Of Record

The relationship parent is
`strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`. It preserves a
complete 43-page U.S. EIA report by Jose A. Villar and Frederick L. Joutz,
"The Relationship Between Crude Oil and Natural Gas Prices," and a complete
peer-reviewed article by David J. Ramberg and John E. Parsons, "The Weak Tie
Between Natural Gas and Oil Prices," *The Energy Journal* 33(2), DOI
`10.5547/01956574.33.2.2`. It also preserves adverse modern EIA evidence. The
records support a time-varying oil/gas linkage and error-correction experiment
while rejecting any permanent fixed price ratio.

The method parent is
`strategy-seeds/sources/MOP-PETTITT-WTI-MSHIFT-TREND-2026/source.md`. It
preserves A. N. Pettitt (1979), "A Non-Parametric Approach to the Change-Point
Problem," *Applied Statistics* 28(2), DOI `10.2307/2346729`, and the complete
pinned public CRAN `trend` 1.1.7 method files at mirror commit
`d0ec3cf8b99b4f3226f5211f592955b85565721d`. The method ranks the complete
observations, computes every cumulative rank sum, and locates all splits
attaining the maximum absolute value. The original Pettitt body is not
represented as completely read; no blocked text or result is used.

Both parents were read completely before the durable OWNER source approval at
`decisions/2026-08-27_xtixng_monthly_pettitt_ratio_reversion_source_approval.md`.

## Source Findings Used

Villar-Joutz and Ramberg-Parsons support testing a state-dependent oil/gas
relationship without assuming a universal coefficient or tight permanent
link. Pettitt and the pinned CRAN files supply a deterministic non-parametric
central-change statistic.

The records support a falsifiable oil/gas ratio change-point experiment, not a
claim that a Pettitt split predicts reversion. The thirteen-month sample,
strict no-tie rule, unique central split, synchronized CFD mapping,
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
s[i] = ln(XTI_close[i]) - ln(XNG_close[i]), i = 0..12
require every s[i] pairwise distinct

R[i] = strict rank of s[i] from 1 (smallest) to 13 (largest)
require sorted(R) = [1,2,...,13]

for k = 1..12:
  U[k] = 2*sum(R[0..k-1]) - 14*k

Ustar = max(abs(U[k]), k=1..12)
Kset  = { k : abs(U[k]) == Ustar }

require 0 < Ustar <= 42 and Ustar even
qualify iff size(Kset) == 1 and 4 <= K <= 9

SELL XTI / BUY XNG iff qualify and U[K] < 0
BUY XTI / SELL XNG iff qualify and U[K] > 0
FLAT otherwise
```

`U[K]<0` means the later oil-minus-gas ratio regime ranks higher; the card
fades that shift by shorting oil and buying gas. `U[K]>0` means the later
ratio regime ranks lower; the card buys oil and shorts gas. A tied maximum,
endpoint tie, average rank, p-value gate, fitted coefficient, rolling center
or scale, endpoint-direction fallback, or alternate split is forbidden.
`Ustar` magnitude never changes risk.

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
   ranks, prove all integer invariants, and fade only one unique maximum in
   the locked central split band.
5. Open at most one equal-target-absolute-USD-notional package under aggregate
   `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Split the
   stop-risk budget equally and size each leg against its frozen
   `3.5*ATR(20,D1)` hard stop. Attach no target, cap spreads at 1,500 XTI
   points and 3,000 XNG points, and require realized notional mismatch no
   greater than 20%.
6. Submit XTI first and XNG second. Retain only one correctly directed,
   registered, stop-protected position in each slot. Flatten all owned legs
   after any partial or final package validation failure.
7. Close both legs on the first tick in a later broker month or after forty
   calendar days. Immediately repair an orphaned, duplicated, same-side,
   wrong-symbol, wrong-magic, stopless, stale, or notional-invalid package.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered MT5 D1 histories, timestamps, calendar, quotes, symbol metadata,
ATR, positions, deals, terminal global variables, and V5 framework services.

## Non-Duplicate Boundary

The fail-closed canonical checker scanned 4,674 registry identities, 1,325
cards, and 45 Strategy Wiki nodes. It found no exact or fuzzy match. The
receipt is
`artifacts/qm5_xtixng_mpettitt_rv_preallocation_dedup_20260827.json`.

- `QM5_41172_wti-mpettitt-shift-tr` applies the same rank statistic to one
  outright WTI series, follows its sign, and owns one position. This packet
  constructs a synchronized oil/gas ratio, fades the sign, and owns an atomic
  equal-notional package.
- `QM5_20237_xtixng-ecm-rv` fits a 252-D1 trend-augmented OLS residual and
  trades a z-score crossing. This packet performs no regression, estimates no
  beta, and consumes thirteen completed monthly endpoints.
- Existing fixed oil/gas ratio, return-spread, channel, momentum, carry,
  calendar, tail, volatility, and factor-rank baskets calculate different
  state objects and thresholds.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not monthly paired-energy rank-change reversion.

The paired carrier, thirteen consecutive synchronized ratios, strict ranks,
all cumulative rank sums, unique central maximum, contrarian sides, consumed
month, aggregate fixed risk, equal-notional target, atomic lifecycle, and
next-month exit are jointly load-bearing. Verdict:
`CLEAN_XTIXNG_MONTHLY_PETTITT_UNIQUE_CENTRAL_RATIO_SHIFT_CONTRARIAN_BASKET`.

## Reputable-Source Criteria

- R1 `PASS_WITH_RELATION_AND_METHOD_TRANSLATION_RISK`: complete government
  oil/gas research, complete peer-reviewed oil/gas evidence including adverse
  findings, named original Pettitt record, and complete pinned CRAN method
  files; exact trading rule untested.
- R2 `PASS`: clock, synchronization, ratio orientation, ranks, cumulative
  sums, unique central split, contrarian sides, attempt, aggregate risk,
  atomicity, and lifecycle are fixed.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  `XTIUSD.DWX` and `XNGUSD.DWX` D1 histories plus native MT5 state supply every
  runtime input.
- R4 `PASS`: deterministic ranks, integer arithmetic, calendar, ATR risk
  controls, and execution state only; no trained output, banned signal
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Falsification And Safety Boundary

The pre-result density prior is four to eight completed packages per full
post-warm-up year. Q02 must retire below four in any full year, at zero
trades, with nonpositive governed economics, or on any endpoint, rank, split,
side, attempt, risk, atomicity, or lifecycle defect. Q09 alone owns realized
overlap and portfolio correlation.

No failed result may be rescued by changing the sample, rank rule, central
band, direction, hedge construction, stop, hold, or by adding a filter. This
packet authorizes one G0 card, one branch-only non-live build, strict Q01, and
one paced Q02 handoff only. It authorizes no manual backtest, live/demo/shadow
preset, AutoTrading, `T_Live`, deploy or live manifest, portfolio-gate change,
portfolio admission, correlation waiver, terminal control, or claim that the
sleeve is already profitable, certified, neutral, or uncorrelated.
