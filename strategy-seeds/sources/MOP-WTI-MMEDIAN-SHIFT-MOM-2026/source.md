---
source_id: MOP-WTI-MMEDIAN-SHIFT-MOM-2026
title: WTI two-completed-month daily-log-price median-location shift momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-24_wti_monthly_median_location_shift_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-24
created_by: Research+Development
cards_extracted:
  - wti-mmedian-shift-mom
---

# WTI Two-Completed-Month Median-Location Shift Momentum Source Packet

## Approved source of record

This bounded extraction uses one canonical child `source_id` with the governed
parent `strategy-seeds/sources/MOP-TSMOM-2012/source.md`. The parent was read
completely before the durable source approval was committed. Its SHA-256 is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

The parent covers Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen
(2012), "Time Series Momentum," *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`. It records an end-to-end read of
the published 23-page paper, an author-faculty-site retrieval receipt, and the
published-PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
WTI crude is an explicit member of the paper's commodity-futures universe.

The OWNER source authorization is
`decisions/2026-08-24_wti_monthly_median_location_shift_momentum_source_approval.md`,
commit `6ebf566fb`. No new online page, blocked content, inferred table value,
secondary performance summary, or unrecorded source is used.

## Source findings used

Moskowitz, Ooi, and Pedersen test an instrument's own return at monthly lags,
report positive continuation at the first twelve monthly lags, define a
symmetric long/short mapping from own past-return sign, explicitly report a
pooled commodity `k=1,h=1` implementation, and identify NYMEX WTI crude in the
commodity universe. These findings support testing a direct-WTI structural
monthly trend carrier and one-month renewal cadence.

The paper does not define daily log-price location samples, ordinary sample
medians, a comparison of two consecutive non-overlapping calendar-month
distributions, or strict continuation after their location shifts. It does
not test a Darwinex continuous CFD, fixed-dollar ATR risk, a spread ceiling,
persistent restart state, or the QM portfolio. Every such choice below is an
explicit pre-result QM hypothesis; no paper result transfers.

## Bounded QM mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each normalized broker-calendar
month, collect every completed D1 close from the immediately completed month
and its consecutive parent month. Apply one uniform energy-label convention
to the current bar and the complete history package: raw broker date or a
uniform `+1` calendar-day correction only. Exclude all current-month data.

For each of the two monthly samples, transform every accepted close `C[d]`
into a daily log-price level and sort those levels independently:

```text
p[d] = log(C[d])

sorted_new = ascending(all p[d] in newest completed month)
sorted_old = ascending(all p[d] in consecutive parent month)
```

Define each ordinary sample median as the center ordered observation for an
odd count and the arithmetic mean of the two center ordered observations for
an even count:

```text
median(sorted, n) = sorted[n/2]                         when n is odd
median(sorted, n) = (sorted[n/2-1] + sorted[n/2]) / 2  when n is even

median_new > median_old  => BUY XTIUSD.DWX
median_new < median_old  => SELL XTIUSD.DWX
median_new = median_old  => FLAT
```

The signal follows strict migration of the robust completed-month WTI price
location. It does not use either month's open, high, low, endpoint return,
range, dispersion, displacement magnitude, current-month confirmation, or an
indicator. Equality and invalid arithmetic remain flat; magnitude never
changes sizing.

The position follows the completed median-location shift until the first tick
of a later normalized broker month. The daily log-price proxy, independent
monthly medians, strict comparison, continuous-CFD carrier, fixed-risk budget,
ATR stop, spread ceiling, consumed-attempt ledger, next-month exit, and stale
guard are QM choices. They are not attributed to the source.

## Exact event contract

1. Require exact host and traded symbol `XTIUSD.DWX`, exact D1 period, and
   entry no later than 180 elapsed minutes after the raw first host D1 bar open
   of a new normalized broker month.
2. Select one label offset for the current bar and all historical bars. Permit
   only raw date or exactly `+86400` seconds. Reject a mixed, colliding,
   ambiguous, or other offset state.
3. Within a fixed 70-bar D1 buffer, require the two immediately preceding
   consecutive calendar months, 17 through 23 accepted sessions in each,
   unique timestamps, strict chronology, and no current-month observations.
4. Require every close to be positive and finite. Compute every logarithm
   without rounding and reject nonfinite arithmetic.
5. Sort each monthly sample independently in ascending order. For odd `n`,
   choose exact index `n/2`; for even `n`, average only exact indexes `n/2-1`
   and `n/2`. Reject an invalid count, index, sort, or median.
6. Follow the strict newest-minus-parent median sign. Equality or any invalid
   state consumes the month flat. No endpoint, range, return, or magnitude
   confirms or scales the signal.
7. Persist current decision `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or order submission. No outcome retries the
   month.
8. Open at most one position with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1`, a frozen `3.5 * ATR(20,D1)` hard stop, no target, and
   a 1,500-point entry-spread ceiling.
9. Close on the first tick in a later normalized broker month, with a forty-
   calendar-day stale repair. Flatten malformed, duplicated, wrong-symbol,
   wrong-magic, or stopless owned exposure immediately.

Both news axes and Friday close are OFF. Runtime uses registered MT5 D1
history, calendar, quotes, symbol metadata, ATR, position/deal state, and
persistent terminal state only.

There is no current-month input, endpoint-return gate, range gate, standard
deviation, MAD, z-score, regression, fitted beta, moving average, oscillator,
season, weekday, inventory, event, external series, prior-result filter,
retry, target, trail, break-even move, partial close, scale-in, grid,
martingale, or pyramid.

## Non-duplicate boundary

The fail-closed pre-allocation checker evidence is
`artifacts/qm5_wti_mmedian_shift_mom_preallocation_dedup_20260824.json`. It
bound 4,636 registry identities, 1,304 repository cards, and 45 Strategy Wiki
nodes from the current Company Reference root. It found no exact or fuzzy
candidate identity and returned `CLEAN`.

Manual semantic review fixes the closest strategy boundaries:

- `QM5_20187_wti-tsmom1m` uses only two month-end closes and follows their
  endpoint return. This extraction uses every accepted daily close across two
  full months and never uses an endpoint return as a signal object.
- `QM5_41102_wti-mrange-migrate-mom` follows only when both aggregate monthly
  highs and lows migrate strictly in the same direction. This extraction
  ignores highs and lows, estimates one robust close location per month, and
  can signal through overlapping or mixed-migration ranges.
- `QM5_41133_wti-mdaily-median-mom` sorts 17-23 daily returns inside one month
  and follows that within-month return median. This extraction computes no
  daily return; it compares daily log-price-level medians in two separate
  calendar-month samples.
- `QM5_20269_wti-medret-mom` takes a median across twelve monthly returns.
  This extraction uses two within-month daily price-level distributions.
- `QM5_41055_wti-med-calendar` estimates a same-calendar-month seasonal state
  over historical years. This extraction has no seasonal or year-of-history
  object and compares only the two newest completed consecutive months.
- `QM5_41104_xauxag-mmedian-shift-rv` forms a two-metal unit-log ratio and
  fades its monthly location shift with an equal-notional package. This
  extraction owns one outright WTI position and follows the shift.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback above a slow trend filter. This extraction is
  symmetric, oscillator-free, monthly, and direct WTI.

The exact WTI carrier, two consecutive completed calendar-month close
samples, 17-to-23-session contract per sample, independent log-price ordinary
medians, strict location comparison, equality-flat rule, continuation side,
month-boundary attempt, fixed risk, and one-month lifecycle are jointly load
bearing. Manual verdict:
`CLEAN_WTI_TWO_COMPLETED_MONTH_DAILY_LOG_PRICE_MEDIAN_LOCATION_SHIFT_MOMENTUM`.

## Reputable-source criteria

- R1: `PASS_WITH_MONTHLY_MEDIAN_LOCATION_TRANSLATION_RISK`. One bounded
  source ID supplies lineage to named authors, a peer-reviewed DOI record,
  complete-paper evidence, a durable retrieval hash, and explicit WTI
  membership; no performance claim transfers.
- R2: `PASS`. Exact clock, label normalization, adjacent months, session
  counts, log-price construction, independent sorting, ordinary median,
  strict comparison, side, durable attempt, fixed risk, stop, spread, exit,
  and stale repair are mechanical.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history and native MT5 state supply every runtime input.
  Q02 owns label, history, density, fill, cost, and CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, completed closes, logarithms, sorting,
  arithmetic, comparisons, ATR, spread, quotes, positions, deal history, and
  terminal state only; no trained model, external feed, banned signal, grid,
  martingale, scale-in, or pyramid.

## Claim and kill boundary

The source supports testing a structural monthly own-price WTI trend carrier,
not the efficacy of this two-sample median-location proxy. Expected cadence is
approximately ten to twelve completed positions per full post-warm-up year,
but Q02 must measure it and retire below five. Q02 also owns baseline
economics; unchanged downstream gates alone own robustness and realized
portfolio correlation.

No failure may be rescued by accepting equality, changing month membership,
using raw closes instead of the fixed log-price definition, reading current-
month data, reversing the side, shortening the hold, or adding an endpoint,
range, displacement threshold, volatility, volume, season, weekday, moving-
average, inventory, event, or external-data filter.

## Safety boundary

This packet supports Q00 consideration, one V5 build, strict compile/Q01, and
one paced non-live XTIUSD Q02 handoff only. It does not authorize a manual
backtest, live/demo/shadow/stress/optimization preset, `T_Live`, AutoTrading,
deploy or T_Live manifest, portfolio-gate change, portfolio admission,
correlation waiver, terminal start/stop, or decorrelation claim.
