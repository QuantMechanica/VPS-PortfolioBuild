---
source_id: MOP-WTI-MLATEHALF-DOM-MOM-2026
title: WTI completed-month late-half dominance momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed research
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-22_wti_monthly_late_half_dominance_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-22
created_by: Research+Development
cards_extracted:
  - wti-mlatehalf-dom-mom
---

# WTI Completed-Month Late-Half Dominance Momentum Source Packet

## Approved Source Of Record

This bounded extraction uses one canonical child `source_id` with the already
governed parent `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, read
completely before the durable source approval was written.

The parent covers Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen
(2012), "Time Series Momentum," *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`. Its durable record contains the
complete 23-page paper review, retrieval receipt, and published-PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
WTI crude oil is an explicit member of the source commodity universe.

The durable OWNER approval is
`decisions/2026-08-22_wti_monthly_late_half_dominance_momentum_source_approval.md`,
committed before this extraction at `30a262765`. No new online page, blocked
content, inferred table value, or unrecorded source is used.

## Source Findings Used

Moskowitz, Ooi, and Pedersen document positive own-return continuation and
mechanically map the sign of an instrument's past return to the future
position direction. Section 3.2 and Table 2 explicitly include a one-month
formation and one-month holding rule inside the pooled commodity portfolio.
Appendix A includes NYMEX WTI crude in the futures universe.

The paper does not establish a WTI-specific one-month result, a split inside
one completed month, strict late-half magnitude dominance, continuous-CFD
calendar labels, fixed-dollar ATR risk, a spread cap, or a relation to the QM
portfolio. Those are transparent QM hypotheses. No source alpha, Sharpe
ratio, drawdown, trade count, cost, CFD equivalence, or decorrelation result
is imported.

## Bounded QM Mechanization

On the first tradable normalized `XTIUSD.DWX` D1 bar of a new broker-calendar
month, reconstruct the immediately preceding completed month and its
consecutive parent. Let `P` be the parent's chronological final close and let
`C[0]...C[n-1]` be every chronological close in the newest completed month:

```text
h     = floor(n / 2)
early = log(C[h-1] / P)
late  = log(C[n-1] / C[h-1])

abs(late) > abs(early) and late > 0 => BUY XTIUSD.DWX
abs(late) > abs(early) and late < 0 => SELL XTIUSD.DWX
otherwise                            => FLAT
```

The parent-final close anchors the first adjacent return. The split close is
shared only as an endpoint, so the two cumulative blocks exhaust every
adjacent return exactly once. With 17 through 23 newest-month sessions, the
early block contains eight through eleven returns and the late block nine
through twelve. Equality, a zero late return, invalid arithmetic, an invalid
split, or malformed history is flat.

This is a recency-dominance state. Same-sign halves qualify only when the late
half is strictly larger; opposed-sign halves can qualify when the late half
has overtaken the early displacement. Direction and size do not use the
early return once eligibility is established.

## Exact Event Contract

1. Derive normalized dates under exactly one label convention: raw labels
   when the current D1 bar date equals broker date, or a uniform `+1` day when
   it is exactly one calendar day behind. Reject every other or mixed state.
2. Require the current bar to be the first tradable bar of a new month and
   require entry within 180 elapsed minutes of its raw open.
3. Reconstruct the immediately completed month and its consecutive parent in
   a fixed 70-bar buffer. Require 17 through 23 unique, strictly ordered,
   positive finite closes in each month and no current-month observation.
4. Use the parent month's chronological final close as `P`, reverse the
   newest month to chronological order, set `h=floor(n/2)`, and compute the
   two exhaustive cumulative log-return blocks exactly as specified.
5. Persist the normalized decision `yyyymm` before history, signal, spread,
   quote, ATR, sizing, news, or order gates. Rejection, failure, or restart
   cannot retry that month.
6. Enter only when the late block's absolute return is strictly larger than
   the early block's and the late return has a strict sign. Follow that sign.
7. Size one position so its normalized hard-stop loss is capped at
   `RISK_FIXED=1000`. Freeze a `3.5 * ATR(20,D1)` stop and use no target.
8. Close on the first tick of a later normalized broker month, with forty
   elapsed days as stale repair. Malformed, duplicated, stopless, wrong-
   symbol, wrong-magic, or invalid-volume ownership flattens immediately.

## Non-Duplicate Boundary

The fail-closed canonical checker found no exact or fuzzy collision across
4,613 registry identities, 1,285 repository cards, and 45 Strategy-Wiki
nodes. Evidence is
`artifacts/qm5_wti_mlatehalf_dom_mom_preallocation_dedup_20260822.json`.

Manual semantic review finds a new mechanic:

- `QM5_41114_wti-mhalfagree-mom` requires sign unanimity across two halves
  and ignores magnitude. This extraction requires strict late-half magnitude
  dominance, permits opposed signs, and rejects non-dominant same-sign paths.
- `QM5_41115_wti-mthirdvote-mom` uses three magnitude-blind block votes and a
  strict majority. This extraction uses two halves, no vote, and a strict
  magnitude ordering.
- `QM5_20187_wti-tsmom1m` follows every strict full-month endpoint return.
  This extraction consumes a non-dominant late half flat.
- `QM5_41016_wti-mclose-mom` forms only on the prior month's final five
  sessions and exits after five sessions. This extraction uses all returns
  in two exhaustive blocks and holds through the next month.
- `QM5_41068_wti-waccel-mom` requires two same-sign completed weekly returns,
  newest magnitude acceleration, and a one-week hold. This extraction permits
  opposed within-month halves and runs on a monthly clock.
- `QM5_20274_wti-path-eff` thresholds a twelve-month net-to-absolute path
  ratio. This extraction uses no twelve-month statistic or fitted threshold.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only, two-day XNG
  oscillator pullback.

The exact WTI carrier, consecutive completed calendar months,
17-to-23-session packages, parent-final anchor, deterministic floor-half
split, two exhaustive return blocks, strict late-over-early absolute-return
ordering, late-sign direction, consumed monthly attempt, fixed risk, and
next-month exit are jointly load-bearing. Manual verdict:
`CLEAN_WTI_COMPLETED_MONTH_STRICT_LATE_HALF_ABSOLUTE_DOMINANCE_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_LATE_HALF_DOMINANCE_TRANSLATION_RISK`. The bounded child
  preserves a named peer-reviewed DOI, complete-read evidence, durable hashes,
  and explicit WTI lineage while disclosing the untested path gate.
- R2: `PASS`. Label normalization, month membership, session bounds, anchor,
  split, return orientation, strict comparison, zero handling, direction,
  attempt, risk, spread, stop, and lifecycle are fixed.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`. Registered native
  `XTIUSD.DWX` D1 history and MT5 state provide every runtime input. Q02 owns
  label, history, density, cost, financing, and CFD-basis sufficiency.
- R4: `PASS`. Runtime uses timestamps, completed closes, logarithms, indexing,
  arithmetic, comparisons, ATR, quotes, positions, deals, and persistent
  terminal state; no trained logic, banned signal, external feed, grid,
  martingale, scale-in, or pyramid exists.

## Claim And Kill Boundary

The source supports testing own-return continuation on a WTI carrier, not the
profitability of this late-half gate. Expected cadence is approximately five
to eight completed positions per full post-warm-up year. Q02 must retire below
five completed positions per full year, at zero trades, or with nonpositive
governed economics.

No failure may be rescued by moving the split, accepting equality, reversing
the side, adding a half-sign agreement condition, changing the hold, loosening
session bounds, or adding volatility, volume, season, weekday, inventory,
event, moving-average, external-data, or prior-result filters.

## Safety Boundary

This packet supports one Strategy Card, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.
