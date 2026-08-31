---
source_id: SCHWEIKERT-PETTITT-CME-XAUXAG-MSHIFT-RV-2026
title: XAU/XAG thirteen-month Pettitt ratio change-point reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed, exchange, and pinned statistical research
source_type: peer_reviewed_exchange_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-31_xauxag_monthly_pettitt_ratio_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026
  - MOP-PETTITT-WTI-MSHIFT-TREND-2026
  - VILLAR-PETTITT-XTIXNG-MSHIFT-RV-2026
parent_sha256:
  SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026: D5E8C4CD0112724D66E64C13B20B7B41CCE1B4CDC2061BA21A979374F04531A8
  MOP-PETTITT-WTI-MSHIFT-TREND-2026: A80A6F6C87C7FB1D5D9E4911A36C5CAFE7005319F4C844F0550B697577BA3C98
  VILLAR-PETTITT-XTIXNG-MSHIFT-RV-2026: 4919B9F71CEAA0D38FF22117A7E1AEBB419022B096FDFCD022D5311187A002B1
created: 2026-08-31
created_by: Research+Development
cards_extracted:
  - xauxag-mpettitt-rv
---

# XAU/XAG Thirteen-Month Pettitt Ratio Change-Point Reversion Source Packet

## Approved Sources Of Record

The relationship parent is
`strategy-seeds/sources/SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026/source.md`.
It preserves Karsten Schweikert (2018), "Are gold and silver cointegrated?
New evidence from quantile cointegrating regressions," *Journal of Banking &
Finance* 88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`, plus official CME
Group "Gold & Silver Ratio Spread" carrier research. The evidence supports a
related but state-dependent gold/silver relation and distinguishes gold's
monetary and safe-haven exposure from silver's larger industrial and
business-cycle exposure. It does not establish a constant hedge ratio or
universal reversion.

The method parent is
`strategy-seeds/sources/MOP-PETTITT-WTI-MSHIFT-TREND-2026/source.md`. It
preserves A. N. Pettitt (1979), "A Non-Parametric Approach to the Change-Point
Problem," *Applied Statistics* 28(2), 126-135, DOI `10.2307/2346729`, and the
complete pinned public CRAN `trend` 1.1.7 method files at mirror commit
`d0ec3cf8b99b4f3226f5211f592955b85565721d`. The method ranks the complete
observations, computes every cumulative rank sum, and locates all splits
attaining the maximum absolute value. The original Pettitt body is not
represented as completely read; no blocked text or result is used.

The completely read governed arithmetic precedent
`strategy-seeds/sources/VILLAR-PETTITT-XTIXNG-MSHIFT-RV-2026/source.md`
specifies synchronized two-carrier ratio construction, strict rank
invariants, central unique-change qualification, and atomic lifecycle. Its
oil/gas carrier, evidence, and any future result do not transfer.

All three parents were read completely before the durable OWNER source
approval at
`decisions/2026-08-31_xauxag_monthly_pettitt_ratio_reversion_source_approval.md`.

## Source Findings Used

Schweikert supports testing a related but state-dependent gold/silver
relationship without assuming one immutable equilibrium. CME supports the
intermarket ratio carrier and distinct monetary-versus-industrial demand
drivers. Pettitt and the pinned CRAN files supply a deterministic
non-parametric central-change statistic.

These records support a falsifiable gold/silver ratio change-point experiment,
not a claim that a Pettitt split predicts reversion. The thirteen-month
sample, strict no-tie rule, unique central split, synchronized CFD mapping,
contrarian sides, equal-target-notional construction, fixed-dollar risk,
stops, spread caps, atomic order sequence, consumed attempt, and lifecycle
are transparent QM choices.

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
require sorted(R) = [1,2,...,13]

for k = 1..12:
  U[k] = 2*sum(R[0..k-1]) - 14*k

Ustar = max(abs(U[k]), k=1..12)
Kset  = { k : abs(U[k]) == Ustar }

require 0 < Ustar <= 42 and Ustar even
qualify iff size(Kset) == 1 and 4 <= K <= 9

SELL XAU / BUY XAG iff qualify and U[K] < 0
BUY XAU / SELL XAG iff qualify and U[K] > 0
FLAT otherwise
```

`U[K]<0` means the later gold-minus-silver ratio regime ranks higher, so the
card fades it by shorting gold and buying silver. `U[K]>0` means the later
ratio regime ranks lower, so the card buys gold and shorts silver. A tied
maximum, endpoint tie, average rank, p-value gate, fitted coefficient,
rolling center or scale, endpoint-direction fallback, or alternate split is
forbidden. `Ustar` magnitude never changes risk.

## Exact Event And Execution Contract

1. Require exact host `XAUUSD.DWX`, companion `XAGUSD.DWX`, D1, and an entry
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
4. Compute thirteen gold-minus-silver log ratios, reject ties, assign strict
   ranks, prove every integer invariant, and fade only one unique maximum in
   the locked central split band.
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
   wrong-symbol, wrong-magic, wrong-direction, stopless, stale, or notional-
   invalid package.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered MT5 D1 histories, timestamps, calendar, quotes, symbol metadata,
ATR, positions, deals, terminal global variables, and V5 framework services.

## Non-Duplicate Boundary

The fail-closed canonical checker scanned 4,747 registry identities, 1,385
cards, and 45 Strategy Wiki nodes. It found no exact identity and retained two
expected fuzzy neighbors. The receipt is
`artifacts/qm5_xauxag_mpettitt_rv_preallocation_dedup_20260831.json`.

- `QM5_41175_xtixng-mpettitt-rv` applies the same method to a different
  government/peer-reviewed oil-gas relationship and owns XTI/XNG exposure.
  This packet owns a gold/silver monetary-versus-industrial spread under
  Schweikert and CME evidence.
- `QM5_41177_xauxag-mwilcoxon-shift-rv` fixes one six/six split and counts its
  36 cross-block comparisons against two thresholds. This packet evaluates
  all twelve Pettitt splits and requires one unique central absolute maximum.
- `QM5_41247_xauxag-mcusum-rv` mean-centers twelve adjacent relative returns
  and scans real-valued cumulative sums. This packet ranks thirteen ratio
  levels, uses no returns or mean, and depends only on ordinal order.
- XAU/XAG z-score, OLS, CADF, quantile, MAD, variance-ratio, endpoint,
  calendar, path, flow, and other robust-rank cards calculate different
  state objects and gates.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not a monthly paired-metal rank-change basket.

The paired-metal carrier, thirteen consecutive synchronized ratios, strict
ranks, all cumulative rank sums, unique central maximum, contrarian sides,
consumed month, aggregate fixed risk, equal-target-notional construction,
atomic lifecycle, and next-month exit are jointly load-bearing. Verdict:
`CLEAN_XAUXAG_MONTHLY_PETTITT_UNIQUE_CENTRAL_RATIO_SHIFT_CONTRARIAN_BASKET`.

## Reputable-Source Criteria

- R1 `PASS_WITH_RELATION_AND_METHOD_TRANSLATION_RISK`: named peer-reviewed
  gold/silver relation evidence, official exchange carrier research, a named
  original Pettitt record, complete pinned CRAN method files, and a governed
  two-carrier arithmetic precedent; exact trading rule untested.
- R2 `PASS`: clock, synchronization, ratio orientation, ranks, cumulative
  sums, unique central split, contrarian sides, attempt, aggregate risk,
  atomicity, and lifecycle are fixed.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state supply every
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

Equal target notionals are market-neutral-style construction, not proof of
market, factor, dollar, beta, volatility, or portfolio neutrality. No failed
result may be rescued by changing the sample, rank rule, central band,
direction, hedge construction, stop, hold, or by adding a filter.

This packet authorizes one G0 card, one branch-only non-live build, strict
Q01, and one paced Q02 handoff only. It authorizes no manual backtest;
live/demo/shadow/stress/optimization preset; AutoTrading; `T_Live`; deploy or
live manifest; portfolio-gate change; portfolio admission; correlation
waiver; terminal control; or claim that the sleeve is already profitable,
certified, neutral, or uncorrelated.
