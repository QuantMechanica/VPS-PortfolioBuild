---
source_id: YANG-WTI-WSTREAK2-FADE-20260910
title: WTI fresh two-week sign-streak reversion
publisher: QuantMechanica governed extraction from academic commodity research
source_type: academic_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-10_wti_fresh_two_week_sign_streak_reversion_source_approval.md
parent_source_ids: [YANG-COMM-REVERSAL-2017, MOP-TSMOM-2012, MOP-WTI-WSTREAK2-CONT-20260910]
parent_sha256:
  YANG-COMM-REVERSAL-2017: 52DBFDAC58E6444D14AACFC97D26E4F8FA0010B6A10F0768DBE56067055ED7F7
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
  MOP-WTI-WSTREAK2-CONT-20260910: BF9D587A046E40C6FCA88A71CD29298751014A2AD10B7D4AB482F7522B58009E
created: 2026-09-10
created_by: Research+Development
cards_extracted: [wti-wstreak2-fade]
---

# WTI Fresh Two-Week Sign-Streak Reversion

## Complete-Read Record

The three bounded parent records named above were read end to end before this
extraction. Yang, Goncu, and Pantelous supply academic commodity-futures
reversal lineage. Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*,
*Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`, supply a complete published-paper record,
own-return-sign methodology, and explicit NYMEX WTI membership. The WTI
two-week continuation packet fixes the completed-week clock and exact fresh
two-week path used by the directionally opposite sibling.

No parent tests fading a fresh two-week WTI sign streak, a Darwinex continuous
CFD, fixed-dollar ATR risk, persistent restart state, or the QM portfolio.
Those are transparent QM translations. No source return, significance,
causality, density, or diversification result transfers.

## Bounded Mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each Monday-anchored broker week,
reconstruct four consecutive completed broker-week ending closes from native
D1 history. Require exact seven-calendar-day anchor adjacency, three to five
strictly ordered sessions in every contributing week, and one uniform raw or
governed `+1`-day energy-label convention.

Let `C0` be the newest completed week-ending close and `C3` the oldest. Define:

```text
r0 = ln(C0 / C1)
r1 = ln(C1 / C2)
r2 = ln(C2 / C3)

r0 > 0 and r1 > 0 and r2 < 0  => SELL XTIUSD.DWX
r0 < 0 and r1 < 0 and r2 > 0  => BUY XTIUSD.DWX
otherwise                       => FLAT
```

The strict opposite sign of `r2` makes `r0..r1` the first completed two-week
streak after a contrary week. After a third same-sign week the shifted
predecessor is no longer opposite, so the strategy remains flat. The trade
reverses the newest streak sign; it never follows it.

## Exact Event Contract

All current decision-week OHLC is excluded. Every endpoint must be positive
and finite. Exact zero, missing or nonconsecutive anchors, invalid session
counts, a mixed label convention, or any sign path other than strict `-++` or
`+--` is flat.

One exact Monday-anchor attempt is persisted before history, signal, news,
spread, quote, ATR, sizing, or order gates. The position uses one frozen
`3.5*ATR(20,D1)` hard stop, `RISK_FIXED=1000`, `RISK_PERCENT=0`, no target,
and a 1,500-point spread ceiling. The first tick of a later broker week closes
the position; ten calendar days is stale repair only.

There is no return-magnitude threshold, volatility state, moving average,
regression, rank, channel, weekly high/low geometry, current-week breakout,
weekday direction, external series, or prior-result gate.

## Non-Duplicate Boundary

The deterministic pre-allocation checker found no exact identity and one
expected fuzzy sibling, `QM5_41415_wti-wstreak3-fade`. That EA requires a
fresh three-week streak and five endpoints. This strategy requires a fresh
two-week streak and four endpoints. Their strict event sets are disjoint
because the opposite predecessor for one is a same-sign newest return for the
other.

`QM5_41419_wti-wstreak2-cont` admits the identical fresh two-week state but
follows its sign; this strategy takes the economically opposite side.
Seasonal WTI two-week cards restrict eligibility by month and omit the
opposite-predecessor condition. The carrier, four endpoints, three adjacent
returns, fresh two-week state, opposite side, and one-week hold jointly define
this identity.

Verdict: `DISTINCT_WTI_FRESH_TWO_WEEK_SIGN_STREAK_REVERSAL`.

## Reputable-Source Criteria

- R1 `PASS_WITH_SHORT_HORIZON_REVERSAL_TRANSLATION_RISK`: academic commodity
  reversal lineage plus a complete peer-reviewed DOI record with explicit WTI
  membership; exact weekly streak-fade efficacy is untested.
- R2 `PASS`: anchors, sessions, endpoints, formulas, strict state, opposite
  side, attempt, fixed risk, stop, spread, and lifecycle are deterministic.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK`: registered native
  WTI D1 history supplies every runtime market input.
- R4 `PASS`: timestamp/OHLC/logarithm/ATR arithmetic only; no ML, banned
  signal, external feed, grid, martingale, pyramid, or adaptive PnL fit.

## Runtime And Falsification Boundary

Runtime uses only configured-symbol D1 OHLC, broker time, quotes, spread, ATR,
symbol metadata, positions, deals, and terminal-global attempt state. Retire
rather than tune on zero trades, fewer than five completed trades in any full
post-warm-up year, malformed weekly packages, wrong sign or side, same-week
retry, missing stop, wrong next-week exit, nonpositive governed economics, or
nondeterminism. Q09 alone may establish realized portfolio decorrelation.

## Safety Boundary

This packet supports research, one V5 branch build, strict Q01, and one paced
non-live Q02 handoff only. It does not authorize manual backtests, live
artifacts, `T_Live`, AutoTrading, deploy manifests, portfolio-gate changes,
portfolio admission, correlation waivers, or decorrelation claims.
