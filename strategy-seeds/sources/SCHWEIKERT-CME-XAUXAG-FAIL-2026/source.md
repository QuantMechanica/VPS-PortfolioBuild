---
source_id: SCHWEIKERT-CME-XAUXAG-FAIL-2026
title: Gold-silver failed-channel-break relative-value extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange sources
source_type: peer_reviewed_plus_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-07_qm5_20265_xauxag_fail_rv_g0.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
created: 2026-08-07
created_by: Research+Development
cards_extracted:
  - xauxag-fail-rv
---

# XAU/XAG Failed-Channel-Break Source Packet

## Approved Source Of Record

This bounded extraction uses only two already approved, completely reviewed
repository packets:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, covering:
   - Karsten Schweikert (2018), "Are gold and silver cointegrated? New
     evidence from quantile cointegrating regressions," *Journal of Banking &
     Finance* 88, 44-51, DOI
     `10.1016/j.jbankfin.2017.11.010`; and
   - OlaOluwa S. Yaya, Xuan Vinh Vo, and Hammed A. Olayinka (2021), "Gold and
     silver prices, their stocks and market fear gauges: Testing fractional
     cointegration using a robust approach," *Resources Policy* 72, 102045,
     DOI `10.1016/j.resourpol.2021.102045`.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, covering CME Group,
   "Gold & Silver Ratio Spread," and the related precious-metals spread
   material preserved in that packet.

The durable OWNER approval is
`decisions/2026-08-07_qm5_20265_xauxag_fail_rv_g0.md`. The official paper URL
encountered during this task was classified `DEFERRED:SOURCE_POLICY` by the
governed public-source router. No newly retrieved online content, blocked
content, or inferred table value is used here.

## Source Findings Used

The peer-reviewed lineage supports testing a state-dependent, potentially
nonlinear long-run relationship between gold and silver rather than assuming
that a constant linear relation is universally stable. The CME lineage
supports treating the gold/silver ratio as an intermarket relative-value
spread rather than decomposing a package into two standalone directional
signals.

These facts justify a falsifiable XAU/XAG relative-price carrier. They do not
establish that a channel failure predicts convergence, that a Darwinex spot
CFD basket reproduces futures behavior, or that opposite legs are neutral to
the current QM portfolio.

## Bounded QM Mechanization

On a new `XAUUSD.DWX` D1 host bar, align sixty-two completed XAU/XAG closes by
timestamp and form `r=ln(XAU)-ln(XAG)`. The oldest sixty observations, shifts
3 through 62, define a frozen pre-event range. The two newer completed ratios
are reserved exclusively for the ordered event:

```text
upper = max(r[3..62])
lower = min(r[3..62])

upside failure:   r[2] > upper and lower < r[1] < upper
downside failure: r[2] < lower and lower < r[1] < upper
```

An upside failure sells XAU and buys XAG. A downside failure buys XAU and
sells XAG. The package exits when its signed ratio converges through the
arithmetic mean of the newest twenty synchronized completed ratios, after
thirty calendar days, or on invalid package/state. Each leg receives half of
one aggregate fixed-cash stop-risk budget after independent
`3.5*ATR(20,D1)` normalization.

The channel length, event order, strict inside re-entry, directions, exit
mean, CFD carrier, fixed risk, stops, spread caps, attempt ledger, and package
lifecycle are transparent QM hypotheses. They are not attributed to the
papers or CME.

## Non-Duplicate Boundary

The deterministic checker scanned 4,322 EA-registry rows and 439 intake cards
and returned `CLEAN` for slug `xauxag-fail-rv`, strategy ID
`SCHWEIKERT-CME-XAUXAG-FAILRV-2026_S02`, and the declared mechanic. Repository
content search found no XAU/XAG channel-failure/re-entry card.

The closest build, `QM5_12724_cme-xauxag-brk`, enters in the direction of a
current 120-day ratio-channel breakout and exits on an opposite 40-day break.
This extraction instead freezes a 60-observation range before both event bars,
requires a completed outside bar followed by a separate completed strict
inside bar, and trades opposite the failed break. Removing the ordered
outside-to-inside event would collapse the candidate into existing channel or
ratio-fade families.

Rolling ratio z-score EAs (`QM5_12577`, `QM5_20157`), return-spread z-score
(`QM5_12862`), rolling OLS (`QM5_20161`), conditional quantiles (`QM5_13205`),
published monthly C-MTAR state (`QM5_20012`), and median/MAD extremes
(`QM5_20263`) use different state variables and entry clocks. Generic failed-
break systems on unrelated single-symbol FX or energy carriers are not a
synchronized two-leg gold/silver relative-price event.

## Reputable-Source Criteria

- R1: PASS. The bounded carrier is grounded in two named-author,
  peer-reviewed DOI records and a governed CME exchange packet. No trading
  performance is imported.
- R2: PASS. Sixty pre-event ratios, two ordered event ratios, strict re-entry,
  fixed sides, twenty-ratio exit mean, aggregate risk, stops, and lifecycle
  are deterministic and precommitted.
- R3: PASS with disclosed basis risk. Registered `XAUUSD.DWX` and
  `XAGUSD.DWX` D1 histories support synchronized native inputs. Q02 is bounded
  to `2018.07.02` through `2024.12.31` and must evaluate the logical package.
- R4: PASS. Runtime uses timestamps, prices, logarithms, extrema, arithmetic
  mean, ATR, spread, quotes, and native trade state only. No trained model,
  banned signal indicator, external feed, grid, martingale, or pyramiding is
  used.

## Claim And Kill Boundary

The source supports testing a structural relative-value relationship, not this
failed-break rule's efficacy. Q02 must retire the card below five completed
packages per full post-warm-up year or on nonpositive governed economics.
Downstream gates alone own robustness and correlation. No failure may be
rescued by changing the channel, event ordering, side, exit mean, stop, hold,
retry contract, or carrier.
