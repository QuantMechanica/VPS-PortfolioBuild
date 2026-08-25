---
source_id: SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026
title: XAU/XAG thirteen-month Theil-Sen ratio-slope reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed, exchange, and governed method research
source_type: peer_reviewed_exchange_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-25_xauxag_monthly_theilsen_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026
  - MOP-WTI-THEILSEN-2026
parent_sha256:
  SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026: D5E8C4CD0112724D66E64C13B20B7B41CCE1B4CDC2061BA21A979374F04531A8
  MOP-WTI-THEILSEN-2026: F83880B74B1DB645F6C20A58B76825DA96787E327C461D0E798CA01CAB72535E
created: 2026-08-25
created_by: Research+Development
cards_extracted:
  - xauxag-mtheilsen-rv
---

# XAU/XAG Thirteen-Month Theil-Sen Ratio-Slope Reversion Source Packet

## Approved Sources Of Record

The primary relationship source is Karsten Schweikert (2018), "Are gold and
silver cointegrated? New evidence from quantile cointegrating regressions,"
*Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`.

The governed composite packet
`strategy-seeds/sources/SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026/source.md`
preserves the named peer-reviewed gold/silver evidence and the official CME
Group "Gold & Silver Ratio Spread" carrier evidence. It records a complete
read of its three parent packets. The findings used here are deliberately
bounded: gold and silver can have a related but state-dependent long-run
relation; CME presents their ratio as an intermarket spread; and the two
metals share precious-metals and USD drivers while differing in monetary,
safe-haven, industrial, and business-cycle exposure.

The arithmetic precedent is
`strategy-seeds/sources/MOP-WTI-THEILSEN-2026/source.md`. It fixes the exact
thirteen-endpoint Theil-Sen-style calculation: enumerate all 78 forward pairs,
divide every change by its positive month-index distance, sort without
rounding, and average central indexes 38 and 39. Its WTI carrier, outright
trend-following direction, source performance context, and risk contract do
not transfer.

Both parent packets were read completely before the durable OWNER source
approval at
`decisions/2026-08-25_xauxag_monthly_theilsen_reversion_source_approval.md`,
commit `e6c9d2ae4`. No new online route, blocked content, or inferred source
table is used.

## Source Findings Used

Schweikert supports testing a gold/silver relative-price relation while
warning against assuming one universal constant equilibrium. CME supports the
two-leg intermarket carrier and an economic reason for relative displacement:
the metals share some drivers but have materially different use and demand
profiles. These findings support a falsifiable relative-value reversion
hypothesis, not a promise that a robust trailing slope will reverse.

The Theil-Sen packet supplies deterministic robust-slope arithmetic only. It
does not support the gold/silver carrier, contrarian direction, synchronized
CFD mapping, or next-month hold. Conversely, the gold/silver sources do not
specify thirteen month ends, all forward slopes, or their median.

The exact calendar, synchronization, log-ratio orientation, thirteen-month
formation, contrarian side mapping, equal-notional construction, fixed risk,
ATR stops, spread limits, atomic order sequence, and persistent no-retry state
are transparent QM translations. No source return, alpha, probability,
density, Sharpe ratio, drawdown, cost, hedge ratio, neutrality, CFD
equivalence, or book-correlation statistic transfers.

## Bounded QM Mechanization

On the first synchronized executable D1 tick of a new broker month, exclude
the current month and reconstruct exactly thirteen consecutive completed
broker calendar months ending with the immediately prior month. Retain the
latest exactly timestamp-matched `XAUUSD.DWX` and `XAGUSD.DWX` close pair in
each month. Missing or duplicate months, unmatched timestamps,
nonchronological pairs, nonpositive closes, or stale endpoints are invalid.

For chronological month-end pairs `i=0..12`:

```text
s[i] = ln(XAU_close[i]) - ln(XAG_close[i])

k = 0
for i = 0..11:
  for j = i+1..12:
    slope[k] = (s[j] - s[i]) / (j - i)
    k += 1

require k == 78
sorted = ascending(slope[0], ..., slope[77])
theilsen = (sorted[38] + sorted[39]) / 2

theilsen > 0 => SELL XAU, BUY XAG
theilsen < 0 => BUY XAU, SELL XAG
otherwise    => FLAT
```

Every denominator is an integer month-index distance from 1 through 12. The
ratio is gold minus silver in logs; reversing it and retaining the same side
mapping is not equivalent. All 13 ratios, all 78 slopes, both central values,
and their sum must be finite. The raw endpoint displacement is diagnostic
only. It may agree or disagree with the median slope and cannot gate the
signal. Exact zero or any invalid state consumes the month flat. Signal
magnitude never changes risk.

## Exact Event And Execution Contract

1. Require exact host `XAUUSD.DWX`, exact companion `XAGUSD.DWX`, D1, and an
   entry attempt no later than 180 elapsed minutes after the raw current host
   D1 bar open in a genuine new broker month.
2. Persist the current broker `yyyymm` as consumed before any history, signal,
   news, spread, quote, ATR, sizing, margin, or order check. A flat result,
   invalid state, broker reject, stop, partial fill, or restart never retries
   the month.
3. From a bounded native D1 buffer, select exactly the latest synchronized
   pair in each of the immediately prior thirteen consecutive broker months.
   The newest pair must be no more than ten calendar days stale.
4. Reverse the selected pairs into strict chronological order, compute the
   thirteen log ratios and all 78 forward slopes, sort ascending, and use the
   exact even-sample median. No endpoint, OLS, z-score, volatility, event,
   seasonal, or prior-result filter is allowed.
5. Fade the strict slope sign with opposite legs. A positive ratio slope is
   gold-rich/silver-cheap and maps to SELL XAU / BUY XAG; a negative slope
   maps to BUY XAU / SELL XAG.
6. Open at most one equal-target-absolute-USD-notional package under aggregate
   `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Split the
   aggregate stop-risk budget equally, size each leg against its frozen
   `3.5*ATR(20,D1)` broker hard stop, attach no target, cap entry spread at
   1,500 XAU points and 500 XAG points, and require realized absolute notional
   mismatch no greater than 20%.
7. Submit XAU first and XAG second. Retain the package only when exactly one
   correctly directed, correctly registered, stop-protected position exists
   in each slot. Flatten every owned leg immediately after any second-leg or
   final-package validation failure.
8. Close both legs on the first tick in a later broker month or after forty
   calendar days. Immediately repair an orphaned, duplicated, same-side,
   wrong-symbol, wrong-magic, stopless, stale, or notional-invalid package.

Both news axes, legacy news mode, and Friday close are OFF for the source-
aligned monthly hold. Runtime uses only registered MT5 histories, timestamps,
calendar, quotes, symbol metadata, ATR, positions, deals, and terminal-
persistent state.

## Non-Duplicate Boundary

The fail-closed canonical checker was run against the actual Company
Reference Vault and scanned 4,656 registry identities, 1,307 card files, and
45 Strategy Wiki nodes. It returned no exact or fuzzy match. The successful
receipt is
`artifacts/qm5_xauxag_mtheilsen_rv_preallocation_dedup_20260825.json`. A
separate preserved receipt proves the stale historical default Vault path
failed closed and did not authorize allocation.

Manual semantic review fixes a new mechanic:

- `QM5_20271_wti-theilsen-tr` uses thirteen outright WTI month ends, follows
  its robust slope, and owns one WTI position. This extraction computes a
  paired gold-minus-silver ratio path, fades the slope, and owns an atomic
  two-leg package.
- `QM5_20050_xauxag-xmom12` and `QM5_20202_xauxag-rev18` observe endpoint
  cross-sectional returns and do not enumerate 78 month-index-normalized
  forward slopes.
- `QM5_20161_xauxag-ols-rv` slides a 120-D1 OLS residual z-score, while
  `QM5_21526_xau-xag-cadf` freezes an annual OLS/CADF/half-life model. This
  extraction fits no alpha, beta, residual center, scale, unit-root statistic,
  or threshold crossing.
- `QM5_41138_xauxag-mdaily-hl-rv` uses 17-23 daily relative returns inside one
  completed month and enumerates inclusive self/cross-pair averages. This
  extraction uses thirteen month-end ratio levels, excludes self-pairs, and
  divides every forward displacement by elapsed month indexes.
- fixed ratio z-score, rolling quantile, MAD, sign-breadth, path-efficiency,
  sequence, and flow cards observe different state objects.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback and has no paired metal exposure.

The paired carrier, thirteen consecutive month-end observations, exact
timestamp matching, log-ratio orientation, 78 forward pairs, `j-i`
denominators, exact even median, contrarian sides, durable consumed month,
equal-notional aggregate fixed risk, atomic lifecycle, and next-month exit
are jointly load-bearing. Verdict:
`CLEAN_XAUXAG_THIRTEEN_MONTH_THEILSEN_RATIO_SLOPE_REVERSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_ROBUST_SLOPE_TRANSLATION_RISK`. The lineage preserves a
  named-author peer-reviewed gold/silver-relation paper with DOI, official
  exchange carrier research, durable complete-read records, and exact
  governed robust-slope arithmetic. The trading conjunction is untested and
  explicitly labeled as such.
- R2: `PASS`. Clock, exact synchronization, consecutive-month selection,
  ratio orientation, pair bounds, denominator, count, sort, median, direction,
  attempt, aggregate risk, stops, atomicity, spread gates, and lifecycle are
  fixed.
- R3: `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories and native MT5 state supply every
  runtime input.
- R4: `PASS`. Deterministic timestamps, logarithms, finite arithmetic,
  sorting, comparisons, ATR risk controls, and execution state only; no
  trained output, banned signal indicator, external feed, grid, martingale,
  scale-in, or pyramid.

## Claim And Kill Boundary

Every valid nonzero slope may qualify, giving a pre-result density prior near
twelve packages per year after a thirteen-month warm-up. This is not market
evidence. Q02 must retire below five completed packages in any full post-
warm-up year, at zero trades, with nonpositive governed economics, or on any
synchronization, month, ratio, slope, denominator, median, side, attempt,
risk, atomicity, lifecycle, or determinism defect.

Opposite equal-notional legs reduce some common outright-metal direction but
do not prove dollar, beta, volatility, factor, market, or portfolio
neutrality. Unchanged Q09 alone owns realized book correlation. No failed
result may be rescued by changing the carrier, observation count, estimator,
direction, risk, hold, or by adding endpoint agreement, regression, scale,
event, seasonal, volatility, external, or prior-result state.

## Safety Boundary

This packet supports one Strategy Card, deterministic allocation, one branch-
only V5 build, strict compile/Q01, and one paced non-live logical-basket Q02
handoff only. It does not authorize a manual backtest, live artifact,
`T_Live`, AutoTrading, deploy manifest, portfolio-gate change, portfolio
admission, correlation waiver, terminal control, or decorrelation claim.
