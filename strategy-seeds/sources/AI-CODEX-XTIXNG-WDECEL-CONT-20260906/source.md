---
source_id: AI-CODEX-XTIXNG-WDECEL-CONT-20260906
title: XTI/XNG completed-week deceleration continuation
publisher: QuantMechanica governed extraction of government and peer-reviewed sources
source_type: government_plus_peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-06_xtixng_weekly_deceleration_continuation_source_approval.md
parent_source_ids:
  - VILLAR-RAMBERG-OILGAS-2026
  - MOP-TSMOM-2012
created: 2026-09-06
created_by: Research+Development
cards_extracted:
  - xtixng-wdecel-cont
---

# XTI/XNG Completed-Week Deceleration Continuation Source Packet

## Approved Source Of Record

This bounded extraction joins two complete governed repository packets read
before durable source approval:

1. `strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`, covering
   Villar and Joutz (2006), *The Relationship Between Crude Oil and Natural
   Gas Prices*, U.S. Energy Information Administration, and Ramberg and
   Parsons (2012), "The Weak Tie Between Natural Gas and Oil Prices," *The
   Energy Journal* 33(2), 13-35, DOI `10.5547/01956574.33.2.2`.
2. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, covering Moskowitz, Ooi,
   and Pedersen (2012), "Time Series Momentum," *Journal of Financial
   Economics* 104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`.

The durable OWNER approval is
`decisions/2026-09-06_xtixng_weekly_deceleration_continuation_source_approval.md`.

## Source Findings Used

Villar/Joutz and Ramberg/Parsons document physical and economic oil/gas links
through substitution, co-production, drilling, finance, transport, and LNG.
They also make instability, gas-specific variation, and a weak rather than
fixed tie binding adverse evidence. Moskowitz/Ooi/Pedersen document own-price
continuation across liquid futures, including commodity futures, but do not
test an oil/gas relative spread or this weekly state.

## Bounded QM Mechanization

On the first tradable `XTIUSD.DWX` D1 bar of each Monday-anchored broker week,
align the three immediately preceding completed week-end closes for XTI and
XNG. For week-end index 1 newest through 3 oldest, define:

```text
s_i   = ln(XTI_close_i) - ln(XNG_close_i)
r_new = s_1 - s_2
r_old = s_2 - s_3
```

Require both returns finite and non-zero, `sign(r_new)=sign(r_old)`, and
`abs(r_new)<abs(r_old)`. Two positive moves with a smaller newest move open
BUY XTI / SELL XNG; two negative moves with a smaller newest move open SELL
XTI / BUY XNG. The package follows a still-persistent but decelerating relative
trend for one broker week.

The weekly horizon, endpoint reconstruction, strict conditions, continuation
sides, CFD carrier, equal-notional target, aggregate fixed-risk cap, ATR stops,
spread caps, consumed-attempt ledger, next-week exit, and stale guard are
transparent QM choices. No source performance, coefficient, threshold, CFD
equivalence, neutrality, or correlation claim is imported.

## Adverse Evidence And Kill Boundary

- The peer-reviewed oil/gas source says the relationship can shift dramatically
  and leaves most short-horizon gas volatility unexplained.
- The momentum source does not establish continuation in a relative oil/gas
  ratio, on a weekly horizon, or after deceleration.
- Daily continuous CFDs are not the sources' spot or rolling futures series.
- Missing or asynchronous history, nonpositive prices, zero/equal returns,
  same-magnitude or accelerating moves, invalid risk, or malformed baskets
  fail closed.
- Q02 retires the candidate below five completed packages per full post-warm-up
  year or on nonpositive governed economics. No post-result rescue is allowed.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,842 registry rows and
1,455 repository cards. It found no exact identity and eight fuzzy family
signals. Manual review resolves the closest mechanics:

- `QM5_41359_xtixng-waccel-rv` requires same-sign acceleration and fades it;
  this rule requires same-sign deceleration and follows it.
- `QM5_41360_xtixng-wretr-rv` requires opposite signs and follows a partial
  retracement.
- `QM5_41358_xtixng-wovershoot-rv` requires opposite signs and a strictly
  larger newest move, then fades it.
- `QM5_41066_xauxag-wdecay-rv` uses the same deceleration state on a precious-
  metal carrier and fades it instead of following it.
- Monthly, weekday, regression, rank, and change-point energy baskets consume
  different state objects and clocks.
- `QM5_12567_cum-rsi2-commodity` is a single-symbol, long-only, two-day XNG
  pullback with no paired relative logic.

Verdict: `CLEAN_AFTER_FUZZY_FAMILY_REVIEW`.

## R1-R4

- R1 source: PASS with disclosed translation risk. One complete U.S.
  government report and two complete peer-reviewed papers with DOI lineage.
- R2 mechanical: PASS. Exact synchronized endpoints, return state, direction,
  attempt, risk, stops, and lifecycle are fixed.
- R3 data: PASS for the disclosed proxy. Registered XTI/XNG D1 histories and
  native broker metadata suffice; Q02 owns actual history/fill sufficiency.
- R4 deterministic/no ML: PASS. Native arithmetic and MT5 data only; no
  external runtime feed, trained model, banned indicator, grid, martingale,
  pyramiding, or adaptive PnL fit.

## Safety Boundary

The OWNER mission authorizes this source packet, one G0 card, deterministic
allocation, branch-only non-live build, strict compile, one logical
`RISK_FIXED` backtest setfile, and one paced Q02 enqueue below the CPU ceiling.
It excludes manual backtests; live, demo, shadow, stress, or optimization
setfiles; AutoTrading; `T_Live`; deploy or live manifests; portfolio admission;
portfolio-gate changes; and correlation waivers.
