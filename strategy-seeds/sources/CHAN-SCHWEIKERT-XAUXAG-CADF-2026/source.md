---
source_id: CHAN-SCHWEIKERT-XAUXAG-CADF-2026
parent_source_ids:
  - SRC02
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
title: XAU/XAG Annual CADF-Qualified Residual Reversion
publisher: QuantMechanica governed composite of a Wiley source, peer-reviewed gold/silver evidence, and CME carrier context
source_type: governed_bounded_composite
status: approved_source_complete
approval_basis: decisions/2026-08-15_xau_xag_cadf_source_approval.md
parent_sha256:
  SRC02_cointegration_pair_family: 183A1624AE3EB4432DDE9BA8883E3F5B16E0107A191E468864CA9600D8D45D64
  SCHWEIKERT_XAUXAG_RATIO_2026: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  CME_GSR_SPREAD_2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
created: 2026-08-15
created_by: Research+Development
cards_extracted:
  - QM5_21526_xau-xag-cadf
---

# XAU/XAG Annual CADF Residual Reversion — Source Packet

## Approved Sources Of Record

The complete bounded Chan cointegration-family extraction, the governed
peer-reviewed gold/silver packet, and the governed CME gold/silver carrier
packet named in the approval decision were read completely before this packet
was approved. The durable OWNER source decision is
`decisions/2026-08-15_xau_xag_cadf_source_approval.md`.

Chan supplies the mechanical pair-trade lineage: fit an OLS hedge, require a
cointegration test rather than substituting correlation, freeze training
statistics out of sample, standardize the fitted spread, fade an extreme,
exit toward the mean, and constrain the hold with fitted mean-reversion speed.
The peer-reviewed packet supplies only the state-dependent long-run
gold/silver relation, and CME supplies only the intermarket carrier context.

Chan's worked carrier is GLD/GDX. None of the sources tests Darwinex
XAUUSD/XAGUSD continuous CFDs, this annual anchor convention, risk allocation,
hard stops, spreads, costs, or the QM book. The candidate is a falsification,
not a replication.

## Bounded Mechanization

For each broker calendar year, fit one model on the immediately preceding 252
synchronized completed D1 observations and freeze it for that year:

```text
y_i = log(XAU_i)
x_i = log(XAG_i)
y_i = alpha + beta*x_i + residual_i

delta_residual_i = c + rho*residual_(i-1)
                   + psi*delta_residual_(i-1) + error_i
ou_delta_i = theta*(residual_(i-1) - mean_residual) + noise_i

half_life = -log(2) / theta
z_t = (residual_t - mean_residual) / sample_std(residual)
```

Admit the model only for finite positive beta in `[0.10,3.00]`, CADF
`t_rho <= -3.343`, negative OU adjustment, and half-life from two through
thirty D1 observations. Fade only a fresh crossing outside `+/-1.0`; exit
inside `+/-0.5`, on invalid state, or after the ceiling of the frozen fitted
half-life. Both traded legs carry frozen ATR hard stops and share one aggregate
fixed-risk budget.

## Exact Runtime Contract

- Host/traded slot 0: `XAUUSD.DWX`, D1.
- Companion/traded slot 1: `XAGUSD.DWX`, D1.
- Formation: 252 exact timestamp-matched completed positive finite closes
  immediately before the first host D1 bar of each broker calendar year.
- Entry: fresh frozen-residual crossing only; positive residual sells gold
  and buys silver, negative residual buys gold and sells silver.
- Risk: aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, weight 1; normalized
  relative stop-risk shares `1.0` and `abs(beta)`.
- Stops: frozen `3.5 * ATR(20,D1)` per leg; no target or stop mutation.
- Spread ceilings: gold 1,500 points; silver 1,500 points.
- Lifecycle: convergence, invalid frozen model/data/package, or fitted
  half-life exit; immediate partial-open and orphan repair.
- News and Friday close are OFF. Runtime uses registered MT5 history, quotes,
  ATR, positions, deals, contract metadata, and framework state only.

## Non-Duplicate Boundary

The deterministic checker returned no exact identity and the expected CADF
family match. The same-pair daily rolling OLS build does not qualify or freeze
its model; fixed-ratio, quantile-envelope, robust-rank, seasonal, momentum,
and return-spread gold/silver builds use different state objects. The prior
Chan EA trades AUDUSD/NZDUSD. The WTI/copper CADF build uses a rolling model
on an energy/industrial-metal carrier. The annual anchor, 5% one-lag CADF,
fitted half-life, fresh-cross rule, and precious-metals package are jointly
load-bearing.

## Reputable-Source And Safety Gates

- R1 `PASS`: CEO-ratified complete Wiley extraction, OWNER-approved
  peer-reviewed gold/silver evidence, and governed CME carrier context.
- R2 `PASS`: estimator, statistical gates, thresholds, direction, risk,
  stops, spreads, anchor reconstruction, and repair are fixed.
- R3 `PASS`: registered gold and silver D1 routes exist; Q02 must prove
  synchronized history, stationarity, fills, density, and economics.
- R4 `PASS`: native deterministic arithmetic only; no trained output, banned
  signal indicator, external runtime feed, grid, martingale, scale-in, or
  pyramid.

Retire below five completed packages per full post-warm-up year or on
nonpositive economics. This packet authorizes no manual backtest, live/demo/
shadow/stress/optimization artifact, `T_Live`, AutoTrading, deploy manifest,
portfolio-gate change, portfolio admission, or correlation waiver.
