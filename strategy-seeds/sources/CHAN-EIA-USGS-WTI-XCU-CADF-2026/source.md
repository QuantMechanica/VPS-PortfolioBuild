---
source_id: CHAN-EIA-USGS-WTI-XCU-CADF-2026
parent_source_ids:
  - SRC02
  - EIA-CME-USGS-XTI-XCU-BRK-2026
title: WTI/Copper CADF-Qualified OLS Residual Reversion
publisher: QuantMechanica governed composite of a Wiley source and official carrier references
source_type: governed_bounded_composite
status: approved_source_complete
approval_basis: decisions/2026-08-15_wti_xcu_cadf_source_approval.md
parent_sha256:
  SRC02_cointegration_pair_family: 183A1624AE3EB4432DDE9BA8883E3F5B16E0107A191E468864CA9600D8D45D64
  EIA_CME_USGS_XTI_XCU_BRK_2026: 6FEB0CE3B231D03255C95B5C2872AFDA28B388DF5284974062B2995A0A243958
  EIA_CME_USGS_XTI_XCU_RSPREAD_2026: 26B943B0F10682B71AD657610716A51C7DFF262852FFB83B3E0221EADDCDE140
created: 2026-08-15
created_by: Research+Development
cards_extracted:
  - QM5_21525_wti-xcu-cadf
---

# WTI/Copper CADF Residual Reversion — Source Packet

## Approved Sources Of Record

The bounded Chan cointegration-family extraction and both governed official
WTI/copper packets named and hash-bound in the frontmatter were read
completely before approval. The durable OWNER source decision is
`decisions/2026-08-15_wti_xcu_cadf_source_approval.md`.

Chan supplies the mechanical pair-trade lineage: fit an OLS hedge, require a
cointegration test rather than substituting correlation, standardize the
fitted spread, fade an extreme, exit toward the mean band, and constrain the
holding period with mean-reversion speed. The official packet supplies only
the distinct crude-oil and copper carrier contexts.

Chan's worked carrier is GLD/GDX. None of the sources tests WTI/copper,
Darwinex continuous CFDs, this rolling window, this simple CADF proxy, the
selected critical boundary, risk allocation, hard stops, costs, or the QM
book. The candidate is therefore a falsification, not a replication.

## Bounded Mechanization

On each new host D1 bar, use exactly 252 synchronized completed observations:

```text
y_i = log(WTI_i)
x_i = log(copper_i)
y_i = alpha + beta*x_i + residual_i

delta_residual_i = c + rho*residual_(i-1) + error_i
phi = 1 + rho
half_life = -log(2) / log(phi)
z_i = residual_i / sample_std(residual)
```

Admit the model only for positive bounded beta, `rho < 0`, CADF-proxy
`t_rho <= -3.043`, `0 < phi < 1`, and half-life from two through sixty D1
observations. Fade only a fresh crossing outside `+/-1.0`; exit inside
`+/-0.5`, on invalid state, or at sixty calendar days. Both traded legs carry
frozen ATR hard stops and share one aggregate fixed-risk budget.

## Exact Runtime Contract

- Host/traded slot 0: `XTIUSD.DWX`, D1.
- Companion/traded slot 1: `XCUUSD.DWX`, D1.
- Formation: 252 exact timestamp-matched completed positive finite closes.
- Entry: fresh residual crossing only; positive residual sells WTI/buys
  copper, negative residual buys WTI/sells copper.
- Risk: aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, weight 1; normalized
  relative stop-risk shares `1.0` and `abs(beta)`.
- Stops: frozen `3.5 * ATR(20,D1)` per leg; no target or stop mutation.
- Spread ceilings: WTI 1,500 points; copper 1,200 points.
- Lifecycle: convergence, invalid-model/data/package, or sixty-day exit;
  immediate partial-open and orphan repair.
- News and Friday close are OFF. Runtime uses registered MT5 history, quotes,
  ATR, calendar, positions, deals, contract metadata, and framework state only.

## Non-Duplicate Boundary

The deterministic checker returned `CLEAN` across 4,397 registry rows and 493
root cards. WTI/copper return-spread reversion, channel continuation, and
twelve-month relative momentum do not use this price-level OLS/CADF residual.
The nearest oil/gas ECM uses a trend-augmented XNG-on-XTI model and a different
source-defined carrier. The precious-metals OLS carrier is not an
energy/industrial-metal package.

## Reputable-Source And Safety Gates

- R1 `PASS`: CEO-ratified complete Wiley extraction and official agency,
  exchange, and government carrier packets.
- R2 `PASS`: the estimator, test, thresholds, direction, risk, stops, spreads,
  and repair are fixed.
- R3 `PASS`: registered WTI/copper routes exist; Q02 must prove synchronized
  history, stationarity, fills, density, and economics.
- R4 `PASS`: native deterministic arithmetic only; no trained output, banned
  indicator, external feed, grid, martingale, scale-in, or pyramid.

Retire below five completed packages per full post-warm-up year or on
nonpositive economics. This packet authorizes no manual backtest, live/demo/
shadow/stress/optimization artifact, `T_Live`, AutoTrading, deploy manifest,
portfolio-gate change, portfolio admission, or correlation waiver.
