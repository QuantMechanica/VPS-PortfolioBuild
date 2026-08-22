---
source_id: SCHWEIKERT-CME-XAUXAG-MOUTSIDE-RES-RV-2026
title: XAU/XAG completed-month outside-range residence reversion basket
publisher: QuantMechanica governed extraction of peer-reviewed and exchange research
source_type: peer_reviewed_exchange_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-22_xauxag_monthly_outside_range_residence_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-XAUXAG-RATIO-2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
created: 2026-08-22
created_by: Research+Development
cards_extracted:
  - xauxag-moutside-res-rv
---

# XAU/XAG Completed-Month Outside-Range Residence Reversion

## Approved Sources Of Record

This bounded extraction uses two governed repository records read completely
after the durable OWNER source approval was committed:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, covering
   Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
   from quantile cointegrating regressions," *Journal of Banking & Finance*
   88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`, plus the supplemental
   robust fractional-cointegration lineage recorded in that packet.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, covering CME Group's
   official definition and discussion of the gold/silver ratio spread as an
   intermarket relative-value carrier.

Their byte hashes are fixed in the front matter. The OWNER source approval is
`decisions/2026-08-22_xauxag_monthly_outside_range_residence_reversion_source_approval.md`,
commit `58523766b`. No new online page, blocked content, inferred paper text,
or unrecorded source is used.

## Source Findings Used

Schweikert supplies reputable evidence for a potentially state-dependent
long-run gold/silver relationship and cautions against assuming one immutable
cointegrating vector. CME defines the gold/silver ratio and supports treating
gold and silver as one intermarket spread carrier. Together they justify
falsifying a discrete relative-value displacement and subsequent
re-convergence rather than taking one outright metal direction.

Neither source defines a completed-month parent range, persistent residence
beyond that range, a five-session floor, the no-opposite-breach condition, a
final-close persistence condition, a contrarian next-month package, Darwinex
continuous CFDs, equal-notional sizing, fixed-dollar ATR risk, or a one-month
hold. Every such choice below is a declared QM translation. No reported source
performance, significance, hedge ratio, density, risk statistic, neutrality,
or correlation is an expectation for this candidate.

## Bounded QM Mechanization

On the first tradable `XAUUSD.DWX` D1 bar of each broker-calendar month,
within 180 elapsed minutes of the raw host-bar open, reconstruct the exact
immediately completed month and its consecutive parent month from native
closed D1 bars. Use only timestamp-identical `XAUUSD.DWX` and `XAGUSD.DWX`
sessions. Each month must contain 17 through 23 unique, strictly ordered
synchronized sessions. No current-month bar may enter the signal.

For each synchronized session `d`, require finite positive closes and compute
only the fixed unit log ratio:

```text
r[d] = log(XAUUSD.DWX close[d]) - log(XAGUSD.DWX close[d])
```

Let the parent completed month's observed range be:

```text
parent_low  = min(r[d]) over the parent month
parent_high = max(r[d]) over the parent month
```

Within the newest completed month, count `above_count`, the sessions whose
ratio is strictly above `parent_high`, and `below_count`, the sessions whose
ratio is strictly below `parent_low`. Let `newest_final` be the ratio on the
chronologically final synchronized session of the newest month.

The signal is:

```text
above_count >= 5 and below_count == 0 and newest_final > parent_high
    => SELL XAUUSD.DWX / BUY XAGUSD.DWX

below_count >= 5 and above_count == 0 and newest_final < parent_low
    => BUY XAUUSD.DWX / SELL XAGUSD.DWX

otherwise
    => FLAT
```

Equality with either parent boundary is inside for counting purposes and
cannot satisfy the final-close condition. Fewer than five one-sided outside
closes, any opposite-side breach, a final close back inside, a zero parent
range, malformed arithmetic, asynchronous history, incomplete months, or
non-adjacent months is flat. Outside distance and number above five never
change side or size.

## Exact Event, Risk, And Lifecycle Contract

- host: exact `XAUUSD.DWX`, D1, slot zero;
- companion: exact `XAGUSD.DWX`, D1, slot one;
- logical carrier: one two-leg XAU/XAG relative-value package;
- decision: first executable host tick of a new broker month, within 180
  elapsed raw-session minutes;
- formation: the immediately completed and parent completed calendar months,
  each with 17-23 synchronized sessions;
- attempt: persist the current `yyyymm` before history, signal, news, spread,
  quote, ATR, sizing, or order gates; never retry that month;
- backtest risk: aggregate-package `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`;
- notional target: one-to-one absolute entry notional, rounded down, with at
  most 20 percent lot-step mismatch;
- hard stops: one frozen `3.5*ATR(20,D1)` stop per leg, with combined
  broker-normalized stop risk no greater than one fixed-risk budget;
- take-profit: none;
- maximum entry spreads: 1,500 XAU points and 500 XAG points;
- news axes and Friday close: OFF/NONE and OFF;
- normal exit: first tick carrying a later broker `yyyymm`;
- stale repair: forty elapsed calendar days after package entry; and
- no retry, one-leg fallback, target, trail, break-even move, partial close,
  scale-in, grid, martingale, pyramid, or external runtime data.

## Non-Duplicate Boundary

The canonical pre-allocation checker scanned 4,599 registry identities and
1,278 cards and found no exact or fuzzy match. Its configured optional
Strategy-Wiki root was unavailable, so the receipt honestly remains
`INPUT_ERROR_FAIL_CLOSED`:
`artifacts/qm5_xauxag_moutside_res_rv_preallocation_dedup_20260822.json`.

Manual repository-wide family review establishes a distinct information
object:

- `QM5_20157_xau-xag-ratio` estimates a rolling 60-day center and dispersion;
  this extraction estimates neither and uses two exact calendar months.
- `QM5_20161_xauxag-ols-rv` fits a rolling hedge residual; this extraction
  fits no coefficient and uses one fixed unit log ratio.
- `QM5_20254_xauxag-vr-fade` combines a rolling z-score with a monthly
  variance-ratio gate; this extraction computes neither statistic.
- `QM5_41079_xauxag-wclose-extreme-rv` locates one final weekly ratio close
  inside the same week's range; this extraction counts persistent observations
  beyond a separate parent month's range.
- `QM5_41085_xauxag-wdaybreadth-rv` counts adjacent relative-return signs in
  one week; this extraction counts levels beyond fixed parent boundaries.
- `QM5_41103_xauxag-mrange-migrate-rv` compares newest and parent range
  endpoints; this extraction never requires either newest range endpoint to
  migrate and instead requires at least five actual outside observations plus
  a still-outside final close.
- `QM5_41104_xauxag-mmedian-shift-rv` compares monthly medians; this extraction
  computes no median and requires a fixed parent-range boundary.
- `QM5_41109_xauxag-mmean-median-rv` compares mean with median inside one
  month; this extraction uses two months and computes neither statistic.
- `QM5_41093_wti-wclose-breakout-mom` follows one direct-WTI weekly close
  outside a parent range; this extraction fades persistent monthly residence
  of a two-leg metals ratio.

The exact XAU/XAG carrier, two synchronized complete calendar months, parent
ratio range, at least five newest-month observations beyond exactly one
boundary, zero opposite-side breaches, final ratio still outside, contrarian
package, durable monthly attempt, equal-notional aggregate risk, and
next-month exit are jointly load-bearing.

## Reputable-Source Criteria

- R1: `PASS_WITH_MONTHLY_OUTSIDE_RANGE_TRANSLATION_RISK`. The primary records
  cover a named-author peer-reviewed DOI and official exchange research. The
  outside-range residence conjunction is explicitly untested.
- R2: `PASS`. Calendar adjacency, session bounds, timestamp synchronization,
  ratio, parent range, outside counts, strict comparisons, final-close state,
  side, attempt, risk, stops, spreads, and lifecycle are deterministic.
- R3: `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered native XAU
  and XAG D1 histories and MT5 state supply every runtime input. Q02 owns
  density, synchronization, fills, costs, and continuous-CFD falsification.
- R4: `PASS`. Runtime inputs are timestamps, completed closes, comparisons,
  ATR, quotes, position/deal history, and terminal state only; no banned
  signal, trained output, external feed, adaptive fit, grid, martingale,
  scale-in, or pyramid exists.

## Claim, Kill, And Safety Boundary

Expected cadence is approximately five to nine completed packages per full
post-warm-up year. This is a design prior only. Q02 must measure cadence and
baseline economics and retire any full scored year below five packages, any
zero-trade or nonpositive governed result, or any history, synchronization,
range, count, one-sidedness, final-close, direction, attempt, basket, risk,
lifecycle, or determinism defect. Q09 alone may measure realized portfolio
correlation.

No failure may be rescued by lowering the five-session threshold, accepting
an opposite-side breach or an inside final close, reversing the side, changing
the hold, fitting a center or hedge ratio, or adding a trend, season, calendar,
volatility, volume, event, inventory, external series, or prior-result filter.

This packet supports Q00 consideration, one V5 build, strict compile/Q01, and
one paced non-live logical-basket Q02 enqueue only. It does not authorize a
manual backtest, live/demo/shadow/stress/optimization preset, terminal control,
AutoTrading, `T_Live`, deploy or T_Live manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.
