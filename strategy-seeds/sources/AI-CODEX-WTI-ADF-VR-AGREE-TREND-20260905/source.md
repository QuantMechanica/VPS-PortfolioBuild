---
source_id: AI-CODEX-WTI-ADF-VR-AGREE-TREND-20260905
title: WTI monthly ADF and robust variance-ratio agreement trend
publisher: QuantMechanica governed synthesis from complete reputable parent records
source_type: ai_originated_book_peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-05_wti_monthly_adf_variance_ratio_agreement_trend_source_approval.md
parent_source_ids:
  - AI-CODEX-WTI-MADF-PERSIST-TREND-20260903
  - MEHLITZ-AUER-WTI-R3Q4-2026
  - MOP-TSMOM-2012
created: 2026-09-05
created_by: Research+Development
cards_extracted:
  - wti-adf-vr-agree-tr
---

# WTI Monthly ADF and Robust Variance-Ratio Agreement Trend

## Complete bounded read and source boundary

The three hash-bound parents in `retrieval_route_20260905.json` were read
completely within their governed scopes before this composition. Chan's Wiley
record fixes the lag-one, intercept-only ADF regression and its negative-tail
orientation. Mehlitz and Auer's peer-reviewed commodity study fixes the
32-return, q=4 heteroskedasticity-robust Lo-MacKinlay statistic, explicitly
includes WTI, and labels significantly positive variance-ratio states as
persistent. Moskowitz, Ooi, and Pedersen provide the peer-reviewed monthly
own-return continuation family and explicit NYMEX WTI membership.

ADF non-rejection and a positive variance-ratio statistic are diagnostics,
not proofs of a unit root, persistence, predictability, or profit. No parent
tests this conjunction, the thresholds on a continuous CFD, fixed risk, costs,
activity, economics, or book correlation. The rule below is disclosed
pre-result QuantMechanica synthesis.

## Locked mechanic

At the first executable `XTIUSD.DWX` D1 tick after a genuine broker-month
transition, reconstruct exactly sixty consecutive completed broker-month-end
closes `C[0..59]`, oldest to newest, excluding all current-month prices, and
set `x[t]=ln(C[t])`.

Fit the lag-one ADF regression over `t=2..59`:

```text
y[t]=x[t]-x[t-1]
z[t]=x[t-1]
w[t]=x[t-1]-x[t-2]
y=alpha+gamma*z+phi*w+error
adf_t=gamma/se(gamma), 58 rows, residual dof 55
```

Use centered cross-products, determinant floor
`det>1e-12*Szz*Sww`, energy floors `1e-18`, and require inclusively
`adf_t>=-2.594`.

From all 59 adjacent log returns, take the newest 32 as `r[0..31]`. Let
`d[t]=r[t]-mean(r)` and `S=sum(d[t]^2)`. For lags `k=1..3` compute:

```text
rho(k)   = sum(t=k..31,d[t]*d[t-k])/S
delta(k) = sum(t=k..31,d[t]^2*d[t-k]^2)/S^2
VR4      = 1 + 1.5*rho(1) + rho(2) + 0.5*rho(3)
theta4   = 2.25*delta(1) + delta(2) + 0.25*delta(3)
vr_z     = (VR4-1)/sqrt(theta4)
```

Require finite arithmetic, `S>1e-18`, `theta4>1e-18`, and strictly
`vr_z>1.64485362695147`. A negative significant statistic is anti-persistent
and deliberately disagrees with the ADF persistence hypothesis, so it stays
flat rather than reversing. Direction is solely
`mom12=x[59]-x[47]`: buy above `+1e-12`, sell below `-1e-12`, otherwise flat.
Both diagnostics must qualify and neither magnitude changes size.

## Execution, risk, and lifecycle

Consume the normalized broker month before every fallible gate and never retry
it. Permit zero or one owned WTI position. Use exactly `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen `3.5*ATR(20,D1)` hard stop,
no target, and a 1,500-point spread ceiling. Both news axes, legacy news,
Friday close, and stress rejection are off. Exit at the next broker month or
after forty calendar days and repair malformed exposure defensively.

Runtime uses only native completed D1 prices/times, ATR, quotes, metadata,
positions, deals, and terminal-global state. It uses no external feed, futures
curve, inventory, optimizer output, portfolio state, trained artifact, grid,
martingale, scale-in, or pyramid.

## Reputable-source findings

- R1 `PASS_WITH_GOVERNED_COMPLETE_PARENT_EVIDENCE`: complete Wiley evidence,
  a complete peer-reviewed commodity variance-ratio record explicitly naming
  WTI, and a complete peer-reviewed WTI continuation record are hash-bound
  with non-transfer limits.
- R2 `PASS`: clock, sixty endpoints, both formulas, inclusive ADF and strict
  positive VR boundaries, conjunction, side, attempt, risk, stop, spread, and
  lifecycle are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native WTI D1 supplies
  every runtime input; roll, basis, financing, gaps, and labels remain risks.
- R4 `PASS`: bounded deterministic arithmetic and native V5 execution only;
  no ML, banned signal indicator, or external runtime feed.

## Non-duplicate and kill boundary

Existing `QM5_41319` has ADF but no variance-ratio gate. `QM5_20253` uses the
same R3-q4 statistic as a four-state continuation/reversal selector but has no
ADF gate, uses a three-month side, and trades significant negative VR states
contrarian; this rule requires positive VR plus ADF agreement and uses a
twelve-month side. Other ADF agreement siblings use KPSS, spectral entropy,
raw von Neumann, LZ76, sample entropy, Ljung-Box, or BDS state functions. No
existing identity requires this exact conjunction. Shared WTI direction can
still correlate and receives no Q09 waiver.

Retire on zero trades, fewer than five completed trades in any full scored
post-warm-up year, nonpositive governed economics, formula/fixture mismatch,
current-month leakage, invalid fixed risk, missing stop, nondeterminism, or a
lifecycle defect. No result-driven threshold or mechanic repair is authorized.

This packet authorizes one branch-only non-live card/build, strict Q01, and one
paced Q02 enqueue while CPU admission is clear. It excludes manual backtests,
optimization, live/demo/shadow/stress sets, portfolio-gate edits, correlation
waivers, portfolio admission, deploy/live manifests, `T_Live`, AutoTrading,
terminal control, and live use.
