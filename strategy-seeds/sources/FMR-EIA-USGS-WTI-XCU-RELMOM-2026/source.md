---
source_id: FMR-EIA-USGS-WTI-XCU-RELMOM-2026
parent_source_ids:
  - FMR-MOMTS-2010
  - EIA-CME-USGS-XTI-XCU-BRK-2026
title: WTI/Copper Twelve-Month Cross-Sectional Momentum
publisher: QuantMechanica governed composite of peer-reviewed and official sources
source_type: governed_bounded_composite
status: approved_source_complete
approval_basis: decisions/2026-08-14_wti_xcu_relmom_source_approval.md
g0_decision: decisions/2026-08-14_qm5_21524_wti_xcu_relmom_g0.md
parent_sha256:
  FMR-MOMTS-2010: 1F4F4977B0D9646A8BF56543D1881CCBC1513D4644DE72C350614580F3FF7417
  EIA-CME-USGS-XTI-XCU-BRK-2026: 6FEB0CE3B231D03255C95B5C2872AFDA28B388DF5284974062B2995A0A243958
created: 2026-08-14
created_by: Research+Development
cards_extracted:
  - QM5_21524_wti-xcu-relmom
---

# WTI/Copper Twelve-Month Relative Momentum — Source Packet

## Approved Sources Of Record

The governed parent packets were read completely before this extraction:

- Fuertes, Ana-Maria; Miffre, Joelle; and Rallis, Georgios (2010),
  "Tactical Allocation in Commodity Futures Markets: Combining Momentum and
  Term Structure Signals," *Journal of Banking & Finance* 34(10), 2530-2548,
  DOI `10.1016/j.jbankfin.2010.04.009`. The complete 47-page accepted-
  manuscript review is preserved at
  `strategy-seeds/sources/FMR-MOMTS-2010/source.md`.
- The official EIA/CME/USGS WTI/copper carrier notes are preserved at
  `strategy-seeds/sources/EIA-CME-USGS-XTI-XCU-BRK-2026/source.md`.
- The existing same-pair mean-reversion boundary was read at
  `strategy-seeds/sources/EIA-CME-USGS-XTI-XCU-RSPREAD-2026/source.md`.

The durable OWNER source approval is
`decisions/2026-08-14_wti_xcu_relmom_source_approval.md`, commit
`65db4e46a`. Parent hashes in the frontmatter bind this extraction to the
repository evidence actually reviewed. No fresh public-page text, proxy,
cache, authentication, quotation, or unavailable content is used.

## Findings Used

Fuertes, Miffre, and Rallis form commodity momentum rankings from average past
returns, explicitly test twelve-month formation with a one-month hold, and
include crude oil in a broad commodity-futures universe. Their implementation
buys high-ranked commodities and shorts low-ranked commodities. The paper
does not report a two-name WTI/copper result and does not use continuous broker
CFDs.

The official carrier packet records EIA's physical crude-oil supply, demand,
spare-capacity, and geopolitical-shock context, CME's benchmark copper-futures
reference, and USGS's copper supply, demand, and materials-flow context. These
sources establish distinct energy and industrial-base-metal carriers only.
They do not test the strategy.

## Bounded Mechanization

At the first processed WTI D1 bar after a genuine broker-month transition:

1. Reconstruct exactly thirteen consecutive common completed broker-month
   endpoints for `XTIUSD.DWX` and `XCUUSD.DWX`.
2. Require exact endpoint timestamp agreement, positive finite closes,
   chronological order, consecutive months, and a newest endpoint no more than
   ten calendar days stale.
3. Calculate twelve simple monthly returns for each leg and their arithmetic
   means:

```text
avg12_wti = mean(WTI_close[m] / WTI_close[m-1] - 1, m=1..12)
avg12_xcu = mean(XCU_close[m] / XCU_close[m-1] - 1, m=1..12)
relative_momentum = avg12_wti - avg12_xcu
```

4. Buy WTI and sell copper for `relative_momentum > 1e-10`; sell WTI and buy
   copper for `relative_momentum < -1e-10`; consume ties and invalid states
   flat.
5. Split one aggregate fixed-dollar stop-risk budget equally across the two
   opposite legs, renew monthly, and enforce atomic package repair.

This is a narrow two-CFD carrier falsification. The source paper's broad
universe, futures construction, performance, costs, volatility scaling, and
diversification results do not transfer. The equal-risk split does not prove
dollar, beta, volatility, factor, or portfolio neutrality.

## Exact Runtime Contract

- Logical basket: `QM5_21524_WTI_XCU_RELMOM_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1, magic `215240000`.
- Companion/traded slot 1: `XCUUSD.DWX`, D1, magic `215240001`.
- Formation: exactly twelve simple returns from thirteen consecutive common
  completed broker-month ends.
- Direction: long higher average-return leg, short lower; strict
  `1e-10` deadband.
- Risk: aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, weight 1; one $500
  stop-risk half per leg.
- Stops: frozen `3.5 * ATR(20,D1)` per leg; no take-profit.
- Spread ceilings: WTI 1,500 points; copper 1,200 points.
- Lifecycle: close before next-month replacement or after forty calendar
  days; consume one attempt per month before every fallible gate.
- Package safety: flatten orphaned, duplicate, same-direction, wrong-symbol,
  wrong-magic, missing-stop, partial-open, or final-validation failure states.
- Both news axes, legacy news mode, and Friday close are OFF.
- Runtime data: registered MT5 D1 OHLC, quotes, spread, ATR, calendar,
  positions, deals, contract metadata, and framework state only.

## Non-Duplicate Boundary

The deterministic checker returned `CLEAN` across 4,396 registry rows and 492
root cards. Manual review separates:

- `QM5_13094_xti-xcu-brk`: daily price-level log-spread channel continuation,
  not twelve completed monthly return ranks.
- `QM5_13090_xti-xcu-rspread`: short-window standardized return-spread
  reversion, not long-horizon cross-sectional continuation.
- `QM5_12733_xti-xng-xmom`: WTI/natural-gas carrier, cumulative D1 return,
  percentage threshold, and Friday-close lifecycle.
- `QM5_20050_xauxag-xmom12`: precious-metal carrier without energy or copper.
- `QM5_12567_cum-rsi2-commodity`: single-symbol XNG oscillator pullback.

The WTI/copper carrier, exact common month ends, arithmetic mean of twelve
simple monthly returns, strict rank, opposite-leg package, equal risk, and
monthly consumed attempt are jointly load-bearing. Verdict:
`CLEAN_WTI_COPPER_TWELVE_MONTH_CROSS_SECTIONAL_MOMENTUM_PACKAGE`.

## Reputable-Source And Safety Gates

- R1 `PASS`: fully reviewed peer-reviewed paper with DOI and institutional
  manuscript, plus governed official EIA, CME, and USGS carrier references.
- R2 `PASS`: endpoints, returns, estimator, direction, risk, stops, spreads,
  attempt state, renewal, and repair are deterministic and locked.
- R3 `PASS`: both DWX symbols and basket execution routes already exist; Q02
  owns synchronized-history and fill proof.
- R4 `PASS`: native arithmetic only; no ML, banned signal indicator, external
  runtime feed, grid, martingale, scale-in, or pyramid.

Retire below five completed packages per full post-warm-up year or on
nonpositive governed economics. This packet authorizes no manual backtest,
live/demo/shadow/stress/optimization setfile, `T_Live`, AutoTrading, deploy
manifest, portfolio-gate change, portfolio admission, or correlation waiver.
