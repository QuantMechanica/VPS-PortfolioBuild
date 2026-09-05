---
source_id: AI-CODEX-WTI-ADF-LJUNGBOX-AGREE-TREND-20260905
title: WTI monthly ADF and Ljung-Box agreement trend
publisher: QuantMechanica governed synthesis from complete reputable parent records
source_type: ai_originated_book_peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-05_wti_monthly_adf_ljungbox_agreement_trend_source_approval.md
parent_source_ids:
  - AI-CODEX-WTI-MADF-PERSIST-TREND-20260903
  - LJUNGBOX-MAHDI-MOP-WTI-PORTMANTEAU-20260902
  - MOP-TSMOM-2012
created: 2026-09-05
created_by: Research+Development
cards_extracted:
  - wti-adf-ljungbox-agree-tr
---

# WTI Monthly ADF and Ljung-Box Agreement Trend

## Complete bounded read and source boundary

The three hash-bound parents in `retrieval_route_20260905.json` were read
completely before this composition. Chan's governed Wiley extraction fixes a
lag-one, intercept-only ADF regression and negative-tail orientation. Mahdi's
complete peer-reviewed open-access paper fixes the finite-sample Ljung-Box
portmanteau formula; Ljung and Box provide original attribution. Moskowitz,
Ooi, and Pedersen provide peer-reviewed monthly own-return continuation and
explicit NYMEX WTI membership.

The ADF and portmanteau statistics are diagnostics, not trading indicators or
proofs of persistence. No parent tests this exact conjunction, thresholds,
continuous WTI CFD, costs, fixed risk, activity, profitability, or correlation.
The conjunction below is disclosed pre-result QuantMechanica synthesis.

## Locked mechanic

At the first executable `XTIUSD.DWX` D1 tick after a genuine broker-month
transition, reconstruct exactly sixty consecutive completed broker-month-end
closes `C[0..59]`, oldest to newest, excluding the current month. Set
`x[t]=ln(C[t])`.

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

On the newest forty-eight adjacent returns
`r[i]=x[12+i]-x[11+i]`, subtract their mean and compute:

```text
den=sum((r[i]-mean)^2), i=0..47
rho[k]=sum((r[i]-mean)*(r[i-k]-mean), i=k..47)/den, k=1..6
Q6=48*50*sum(rho[k]^2/(48-k), k=1..6)
```

Require finite arithmetic, `den>1e-18`, and inclusively `Q6>=5.35`.
Direction is solely `mom12=x[59]-x[47]`: buy above `+1e-12`, sell below
`-1e-12`, otherwise flat. Both diagnostics must qualify. ADF alone and
Ljung-Box alone both abstain; magnitudes never alter size.

## Execution, risk, and lifecycle

Consume the broker month before every fallible gate and never retry it. Permit
at most one owned WTI position. Use exactly `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen `3.5*ATR(20,D1)` hard stop,
no target, and a 1,500-point spread ceiling. Both news axes, legacy news,
Friday close, and stress rejection are off. Exit at the next broker month or
after forty calendar days; repair malformed exposure defensively.

Runtime uses only native D1 prices/times, ATR, quotes, symbol metadata,
positions, deals, and terminal-global state. It uses no external feed, curve,
inventory, optimizer output, portfolio state, trained artifact, grid,
martingale, scale-in, or pyramid.

## Reputable-source findings

- R1 `PASS_WITH_GOVERNED_COMPLETE_PARENT_EVIDENCE`: complete Wiley extraction,
  complete peer-reviewed open-access method paper, and complete peer-reviewed
  WTI trading-paper record, all hash-bound with non-transfer limits.
- R2 `PASS`: clock, samples, both formulas, inclusive gates, conjunction,
  side, attempt, risk, stop, spread, and lifecycle are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native WTI D1 supplies
  every runtime input; roll, basis, financing, gaps, and broker labels remain.
- R4 `PASS`: bounded deterministic arithmetic and native V5 execution only;
  no ML or banned signal indicator.

## Non-duplicate and kill boundary

The corrected-root receipt
`artifacts/qm5_wti_adf_ljungbox_agree_tr_preallocation_dedup_20260905.json`
found no exact identity across 4,830 registry rows, 1,443 cards, and 45 Wiki
nodes. Expected fuzzy agreement siblings are different: KPSS uses partial
level sums/HAC variance, spectral entropy uses DFT power concentration, von
Neumann uses one successive-difference ratio, LZ76 parses sign phrases, and
sample entropy counts raw-magnitude templates. Parent `QM5_41319` has no
portmanteau gate; parent `QM5_41313` has no ADF gate. The conjunction is
load-bearing, though shared WTI momentum can still correlate and receives no
Q09 waiver.

Retire on zero trades, fewer than five completed trades in any full scored
post-warm-up year, nonpositive governed economics, formula/fixture mismatch,
leakage, invalid risk, missing stop, nondeterminism, or lifecycle defect. No
post-result parameter repair is authorized.

This packet authorizes one branch-only non-live card/build, strict Q01, and
one paced Q02 enqueue while the CPU ceiling is clear. It excludes manual
backtests, optimization, live/demo/shadow/stress sets, portfolio-gate edits,
portfolio admission, live manifests, `T_Live`, AutoTrading, and live use.
