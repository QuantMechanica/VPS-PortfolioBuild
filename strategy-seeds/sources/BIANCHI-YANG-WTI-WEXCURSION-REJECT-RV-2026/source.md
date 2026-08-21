---
source_id: BIANCHI-YANG-WTI-WEXCURSION-REJECT-RV-2026
title: WTI completed-week excursion-rejection reversal extraction
publisher: QuantMechanica governed extraction of academic commodity research
source_type: peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-21_wti_weekly_excursion_rejection_reversal_source_approval.md
parent_source_ids:
  - BIANCHI-MOMREV-2015
  - YANG-COMM-REVERSAL-2017
parent_sha256:
  BIANCHI-MOMREV-2015: F2EA59689B0FA0AE21A0BE5689A8F965062C65055516737C5210C65F6B072752
  YANG-COMM-REVERSAL-2017: 52DBFDAC58E6444D14AACFC97D26E4F8FA0010B6A10F0768DBE56067055ED7F7
created: 2026-08-21
created_by: Research+Development
cards_extracted:
  - wti-wexcursion-reject-rv
---

# WTI Completed-Week Excursion-Rejection Reversal Source Packet

## Approved sources of record

This bounded extraction uses the following governed repository records, read
completely after the durable OWNER source approval was committed:

1. `strategy-seeds/sources/BIANCHI-MOMREV-2015/source.md`, covering Robert J.
   Bianchi, Michael E. Drew, and John Hua Fan (2015), "Combining Momentum with
   Reversal in Commodity Futures," *Journal of Banking & Finance* 59,
   423-444, DOI `10.1016/j.jbankfin.2015.07.006`. The parent records an
   end-to-end read of the 59-page accepted manuscript and explicit crude-oil
   membership in the source universe.
2. `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`, covering Liu
   Yang, Bige Kahraman Goncu, and Athanasios A. Pantelous, "Momentum and
   Reversal in Commodity Futures," SSRN 3069253. It supplies supplemental
   fixed-horizon commodity-reversal lineage and records prior governed WTI
   translations.

Their byte hashes are fixed in the front matter. The OWNER authorization is
`decisions/2026-08-21_wti_weekly_excursion_rejection_reversal_source_approval.md`,
commit `adedf01308857a0f2a41318cf91437e337f52c1e`. No new online page, blocked
content, inferred result, or unrecorded source is used.

## Source findings used

Bianchi, Drew, and Fan document that commodity returns can contain distinct
momentum and longer-horizon reversal components. Yang, Goncu, and Pantelous
provide a supplemental commodity momentum/reversal lineage across fixed
horizons. Together they support falsifying a deterministic reversal state on
an explicit WTI carrier.

Neither source defines weekly candle geometry, an open-centred high/low
excursion, a two-to-one imbalance, or settlement rejection. Neither tests a
Darwinex continuous CFD, broker-label normalization, fixed-dollar ATR risk,
or a one-week hold. Every such item below is an explicit QM translation. No
reported source performance, significance, trade count, or risk statistic is
an expectation for this build.

## Bounded QM mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each normalized Monday-anchored
broker week, aggregate the exact immediately completed week from completed D1
OHLC. Apply one configured label convention uniformly to the current bar and
every historical bar: native same-day labels or a uniform `+1` calendar-day
offset for the energy history.

The completed package must be exactly seven calendar days behind the current
week anchor and contain three to five unique, strictly ordered sessions. Use
the chronological first session open as `O`, maximum high as `H`, minimum low
as `L`, and chronological final close as `C`. Require positive finite OHLC,
valid per-bar and aggregate geometry, `H>L`, and `L<=O<=H`.

Define:

```text
U = H - O
D = O - L
```

Trade only when a strict dominant excursion is rejected by the final weekly
settlement:

```text
U > 2*D and C < O  => SELL XTIUSD.DWX
D > 2*U and C > O  => BUY XTIUSD.DWX
otherwise          => FLAT
```

Equality at either two-to-one boundary is flat. `C=O`, settlement agreement
with the dominant excursion, invalid arithmetic, current-week contamination,
nonadjacent history, or any other state is flat. Excess magnitude does not
alter size.

## Exact event, risk, and lifecycle contract

- host and traded symbol: exact `XTIUSD.DWX` only;
- period: exact D1 only;
- decision: first executable tick of a new normalized broker week, within 180
  elapsed minutes of the raw current D1 bar open;
- signal data: the exact immediately completed three-to-five-session weekly
  package only, with no current-week price input;
- attempt: persist the normalized Monday anchor before history, signal, news,
  spread, quote, ATR, sizing, or order gates; never retry that week;
- exposure: at most one owned position and at most one entry deal per week;
- backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`;
- hard stop: frozen `3.5*ATR(20,D1)` from the completed D1 bar;
- take-profit: none;
- maximum entry spread: 1,500 WTI points;
- news axes and Friday close: OFF/NONE and OFF;
- normal exit: first tick carrying a later normalized Monday anchor;
- stale repair: ten elapsed calendar days after entry; and
- no retry, reversal-in-place, target, trail, break-even move, partial close,
  scale-in, grid, martingale, pyramid, or external runtime data.

## Non-duplicate boundary

The pre-allocation checker scanned 4,585 registry rows and 1,265 cards. The
optional Strategy-Wiki root was unavailable, so its honest result was
`FUZZY_MATCH`. It surfaced only `QM5_41095`, the intended close family member.

`QM5_41095_wti-wexcursion-imbalance-mom` follows `U>2D` only when `C>O` and
follows `D>2U` only when `C<O`. This extraction trades the exact mutually
exclusive settlement-rejection states and keeps both agreement states flat:
sell after `U>2D` only when `C<O`; buy after `D>2U` only when `C>O`. It is a
failed-auction reversal hypothesis, not a renamed continuation build or a
threshold change.

The mechanic also differs from weekly body dominance (`QM5_41092`), two-week
range migration (`QM5_41089`), parent-return plus close location (`QM5_41080`),
prior-channel close breakout (`QM5_41093`), and outside-parent settlement
(`QM5_41073`). It reads one completed week, compares its two open-centred
excursions, and requires the final close to oppose the dominant excursion.
Certified `QM5_12567` is instead a long-only two-day XNG oscillator pullback.

The exact carrier, one-week aggregation, strict two-to-one open-centred
imbalance, opposing settlement sign, agreement-flat behavior, boundary entry,
durable attempt, fixed risk, and next-week exit are jointly load-bearing.

## Reputable-source criteria

- R1: `PASS_WITH_WEEKLY_FAILED_AUCTION_TRANSLATION_RISK`. The primary lineage
  is peer reviewed, DOI-bound, completely read, and includes crude oil. The
  working-paper lineage is supplemental and separately disclosed.
- R2: `PASS`. The clock, label convention, week anchor, session count, OHLC
  construction, strict inequalities, side, attempt, fixed risk, stop, spread,
  exit, and stale repair are deterministic.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`. Registered native
  `XTIUSD.DWX` D1 data plus MT5 state supplies every runtime input. Q02 owns
  label, density, fill, cost, and continuous-CFD falsification.
- R4: `PASS`. Runtime inputs are timestamps, completed OHLC, arithmetic,
  comparisons, ATR, spread, quote, position, deal history, and terminal state
  only; there is no banned signal, trained output, external feed, adaptive
  fitting, grid, martingale, scale-in, or pyramid.

## Claim, kill, and safety boundary

Expected cadence is approximately five to fifteen completed positions per
full post-warm-up year. This is a design prior only. Q02 must measure cadence
and baseline economics and retire any full scored year below five trades,
zero-trade result, nonpositive economics, or implementation defect. Q09 alone
may measure realized portfolio correlation.

No failure may be rescued by accepting inequality equality, moving the
two-to-one boundary, trading settlement agreement, reversing the side,
changing the hold, or adding a parent comparison, body, wick, close-location,
range rank, moving average, oscillator, trend, calendar, volatility, volume,
inventory, event, external series, or prior-result filter.

This packet supports Q00 consideration, one V5 build, strict compile/Q01, and
one paced non-live Q02 enqueue only. It does not authorize a manual backtest,
live/demo/shadow/stress/optimization preset, terminal control, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio-gate change, portfolio
admission, correlation waiver, or decorrelation claim.
