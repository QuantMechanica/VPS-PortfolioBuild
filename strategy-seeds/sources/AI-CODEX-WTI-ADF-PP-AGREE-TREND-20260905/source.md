---
source_id: AI-CODEX-WTI-ADF-PP-AGREE-TREND-20260905
title: WTI monthly ADF and Phillips-Perron agreement-gated trend
publisher: QuantMechanica governed synthesis from complete reputable parent records
source_type: ai_originated_reputable_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-05_wti_monthly_adf_phillips_perron_agreement_trend_source_approval.md
parent_source_ids:
  - AI-CODEX-WTI-MADF-PERSIST-TREND-20260903
  - AI-CODEX-WTI-MPP-PERSIST-TREND-20260903
  - MOP-TSMOM-2012
created: 2026-09-05
created_by: Research+Development
cards_extracted:
  - wti-adf-pp-agree-tr
---

# WTI Monthly ADF and Phillips-Perron Agreement Trend

## Approval and bounded complete evidence

The current OWNER mission authorizes one new structural low-frequency
commodity/energy hypothesis, card, build, and paced Q02 enqueue. The durable
approval is
`decisions/2026-09-05_wti_monthly_adf_phillips_perron_agreement_trend_source_approval.md`.
The composition receipt is `retrieval_route_20260905.json`; no new public URL
or unread source is represented.

The complete governed parents preserve: Chan's lag-one, intercept-only ADF
regression; Phillips and Perron's peer-reviewed Z-tau correction using an
eleven-lag Bartlett/Newey-West long-run variance; and Moskowitz, Ooi, and
Pedersen's peer-reviewed monthly own-return continuation with explicit NYMEX
WTI membership. The Phillips-Perron record also preserves the paper's adverse
finite-sample warning under strongly negative moving-average errors.

No parent tests this conjunction. Neither unit-root non-rejection proves a
unit root, persistence, predictability, profit, independence, or portfolio
decorrelation, especially on a 60-month continuous CFD sample.

## Locked hypothesis and formula

WTI supplies physical-energy exposure outside the XAU/SP500/NDX/XNG book. On
the first tradable D1 bar of a genuine broker month, reconstruct exactly 60
consecutive completed broker-month-end closes `C[0..59]`, oldest to newest,
and set `x[t]=ln(C[t])`. Exclude the current month.

ADF gate: over `t=2..59`, regress
`dx[t]=alpha+gamma*x[t-1]+phi*dx[t-1]+u[t]`, with 58 observations and 55
residual degrees of freedom. Require the lagged-level coefficient t statistic
`adf_t>=-2.594`.

PP gate: over `i=0..58`, regress `x[i+1]=a+rho*x[i]+u[i]`, with 59
observations and 57 residual degrees of freedom. Let `gamma0=sum(u^2)/59`,
use Bartlett weights `1-j/12` for residual autocovariances `j=1..11`, and set:

```text
lambda2 = gamma0 + 2*sum((1-j/12)*gamma[j], j=1..11)
raw_tau = (rho-1)/se_rho
pp_z_tau = sqrt(gamma0/lambda2)*raw_tau
           - 0.5*((lambda2-gamma0)/sqrt(lambda2))*(59*se_rho/s)
```

Require `pp_z_tau>=-2.594`. Only when both inclusive gates qualify, compute
`mom12=x[59]-x[47]`: positive buys WTI, negative sells WTI, and an absolute
value at or below `1e-12` stays flat. Statistic magnitude never changes risk.

## Lifecycle and risk

Persist the normalized broker month as attempted before any fallible history,
signal, spread, quote, ATR, sizing, margin, or order gate. Never retry the
month. Permit no foreign WTI position and at most one owned position. Use
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen completed
D1 `3.5*ATR(20)` hard stop, no target, and a 1,500-point inclusive spread cap.
News, Friday close, and stress are off. Close on the first tick of the next
broker month or after 40 calendar days. No intramonth signal exit, flip,
trailing, break-even, partial close, scaling, grid, martingale, or pyramid.

## Reputable-source criteria

- R1 `PASS_WITH_GOVERNED_COMPLETE_REPUTABLE_EVIDENCE`: the complete Wiley,
  peer-reviewed econometrics, and peer-reviewed WTI records are hash-bound;
  adverse and non-transfer boundaries are explicit.
- R2 `PASS`: endpoints, two regressions, degrees of freedom, covariance lags,
  inclusive gates, direction, attempt state, risk, stop, spread, and exit are
  deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 supplies every runtime input; roll, basis, financing, and
  broker-month effects remain risks.
- R4 `PASS`: only bounded price/calendar/OLS/HAC arithmetic and native V5
  execution; no ML, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, pyramid, or random path.

## Non-duplicate and kill boundary

The corrected-root receipt
`artifacts/qm5_wti_adf_pp_agree_tr_preallocation_dedup_20260905.json` found no
exact identity across 4,833 registry rows, 1,446 cards, and 45 Wiki nodes.
Manual review separates this identity from standalone ADF and PP parents and
from every ADF-agreement sibling: the PP parent omits ADF; the ADF parent omits
PP; the siblings use KPSS, entropy, von Neumann, LZ, sample entropy,
Ljung-Box, BDS, or variance ratio instead of the PP HAC correction. A path can
pass one unit-root diagnostic and fail the other, so the conjunction changes
admission decisions. Shared WTI momentum still creates Q09 correlation risk.

Q02 retires on zero positions, fewer than five completed positions in any full
post-warm-up year, nonpositive governed economics, formula/oracle mismatch,
leakage, invalid risk, missing stop, malformed lifecycle, or nondeterminism.
No parameter may change after results. This packet authorizes one branch-only
non-live build and one paced Q02 enqueue; it authorizes no manual backtest,
optimization, portfolio-gate edit, correlation waiver, deployment, live
manifest, `T_Live`, AutoTrading, terminal control, or live use.
