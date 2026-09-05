---
source_id: AI-CODEX-WTI-ADF-BDS-AGREE-TREND-20260905
title: WTI monthly ADF and BDS agreement trend
publisher: QuantMechanica governed synthesis from complete reputable parent records
source_type: ai_originated_book_peer_reviewed_scientific_computing_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-05_wti_monthly_adf_bds_agreement_trend_source_approval.md
parent_source_ids:
  - AI-CODEX-WTI-MADF-PERSIST-TREND-20260903
  - BROOCK-STATSMODELS-MOP-WTI-BDS2-20260902
  - MOP-TSMOM-2012
created: 2026-09-05
created_by: Research+Development
cards_extracted:
  - wti-adf-bds-agree-tr
---

# WTI Monthly ADF and BDS Agreement Trend

## Complete bounded read and source boundary

The three hash-bound parents in `retrieval_route_20260905.json` were read
completely before this composition. Chan's governed Wiley extraction fixes a
lag-one, intercept-only ADF regression and its negative-tail orientation.
Broock, Scheinkman, Dechert, and LeBaron provide peer-reviewed attribution for
the BDS independence test; the complete pinned statsmodels implementation and
fixtures fix the embedding-two arithmetic. Moskowitz, Ooi, and Pedersen
provide peer-reviewed monthly own-return continuation and explicit NYMEX WTI
membership.

ADF and BDS are diagnostics, not trading indicators or proofs of persistence.
No parent tests this exact conjunction, thresholds, continuous WTI CFD, costs,
fixed risk, activity, profitability, or correlation. The conjunction below is
disclosed pre-result QuantMechanica synthesis.

## Locked mechanic

At the first executable `XTIUSD.DWX` D1 tick after a genuine broker-month
transition, reconstruct exactly sixty-one consecutive completed broker-month-
end closes `C[0..60]`, oldest to newest, excluding the current month. Set
`x[t]=ln(C[t])`.

Fit the lag-one ADF regression on the newest sixty levels `x[1..60]` over
`t=2..59` in that local window:

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

Form all sixty adjacent returns `all_r[i]=x[i+1]-x[i]`; apply BDS only to the
newest forty-eight `r[i]=all_r[12+i]`. Let sample standard deviation use
`ddof=1`, `epsilon=1.5*sd`, and `I[a,b]=1` only for the strict comparison
`abs(r[a]-r[b])<epsilon`.

```text
C1 = upper-pair mean of I over indices 0..47
row[a] = sum(I[a,b], b=0..47); S=sum(row)
k = (sum(row[a]^2)-3*S+96)/(48*47*46)
C1T = upper-pair mean of I over indices 1..47
C2 = upper-pair mean of I[a,b]*I[a+1,b+1], a,b=0..46
variance2 = 4*(k-C1^2)^2
BDS2 = sqrt(47)*(C2-C1T^2)/sqrt(variance2)
```

Require finite arithmetic, sample variance `>1e-18`, epsilon `>1e-12`, BDS
variance `>1e-18`, and inclusively `abs(BDS2)>=0.6744897501960817`. Direction
is solely `mom12=x[60]-x[48]`: buy above `+1e-12`, sell below `-1e-12`,
otherwise flat. Both diagnostics must qualify. Either gate alone abstains;
magnitudes never alter size.

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

- R1 `PASS_WITH_GOVERNED_COMPLETE_PARENT_EVIDENCE`: complete Wiley evidence,
  peer-reviewed BDS attribution, a complete pinned scientific implementation
  with fixtures, and a complete peer-reviewed WTI trading-paper record are
  hash-bound with non-transfer limits.
- R2 `PASS`: clock, samples, both formulas, inclusive gates, conjunction,
  side, attempt, risk, stop, spread, and lifecycle are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native WTI D1 supplies
  every runtime input; roll, basis, financing, gaps, and broker labels remain.
- R4 `PASS`: bounded deterministic arithmetic and native V5 execution only;
  no ML, banned signal indicator, or external runtime feed.

## Non-duplicate and kill boundary

The corrected-root receipt
`artifacts/qm5_wti_adf_bds_agree_tr_preallocation_dedup_20260905.json` found
no exact identity across 4,831 registry rows, 1,444 cards, and 45 Wiki nodes.
It returned expected fuzzy agreement siblings for manual inspection. BDS is
load-bearing: it counts strict close pairs of delay vectors with a source-
specific variance normalization, unlike KPSS partial sums, spectral power,
von Neumann successive differences, LZ76 phrases, sample templates, or the
Ljung-Box sum of linear autocorrelations. Parent `QM5_41319` has no BDS gate;
parent `QM5_41316` has no ADF gate. Shared WTI momentum can still correlate and
receives no Q09 waiver.

Retire on zero trades, fewer than five completed trades in any full scored
post-warm-up year, nonpositive governed economics, formula/fixture mismatch,
leakage, invalid risk, missing stop, nondeterminism, or lifecycle defect. No
post-result parameter repair is authorized.

This packet authorizes one branch-only non-live card/build, strict Q01, and one
paced Q02 enqueue while the CPU ceiling is clear. It excludes manual
backtests, optimization, live/demo/shadow/stress sets, portfolio-gate edits,
portfolio admission, live manifests, `T_Live`, AutoTrading, and live use.
