---
source_id: AI-CODEX-WTI-CSSVOLSHIFT-20260831
source_type: ai_originated_governed_synthesis
title: WTI monthly centered-sum-of-squares variance-shift continuation
author: OpenAI Codex
supporting_authors: Carla Inclan; George C. Tiao; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
status: approved_source_complete
approval_basis: decisions/2026-08-31_wti_css_variance_shift_trend_source_approval.md
created: 2026-08-31
created_by: Codex
last_reviewed: 2026-08-31
cards_extracted:
  - QM5_41252_wti-css-volshift-tr
---

# WTI Monthly Centered-Sum-of-Squares Variance-Shift Continuation

## Canonical origin

This is the single R1 lineage for one bounded AI-originated strategy. The
current explicit OWNER mission requests one new structural, low-frequency
commodity/energy sleeve and expressly permits direct `XTIUSD.DWX` trend or
seasonality. `processes/qb_reputable_source_criteria.md` permits AI-originated
sources when the prompt/output trail and claim boundary are durable.

Codex fixed the mechanic below before any market test. Inclan and Tiao (1994)
support only the centered cumulative-sum-of-squares statistic and retrospective
variance-change location. Moskowitz, Ooi, and Pedersen (2012) support only the
WTI carrier, monthly cadence, and own-return continuation direction. Their
conjunction is a transparent untested QM synthesis.

## Supporting evidence and read boundary

Inclan and Tiao (1994), *Use of Cumulative Sums of Squares for Retrospective
Detection of Changes of Variance*, *Journal of the American Statistical
Association* 89(427), 913-923, DOI
`10.1080/01621459.1994.10476824`, was read completely across its twelve-page
article image. The paper defines `C_k` as the cumulative sum of squared
zero-mean observations, `D_k=C_k/C_T-k/T`, and the retrospective change
location as the maximum absolute centered path. It derives the
`sqrt(T/2)` Brownian-bridge normalization, reports finite-sample quantiles for
`T=100..500`, warns that outliers can mimic a change, and finds the asymptotic
approximation practically useful from 200 observations. It does not prescribe
a WTI trading rule.

`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
records a complete read of Moskowitz, Ooi, and Pedersen (2012), *Time Series
Momentum*, *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. It explicitly includes NYMEX WTI and positive
own-return continuation over one through twelve monthly lags.

No paper tests this exact conjunction on a continuous WTI CFD, mean-centers a
rolling 252-D1 window for this trading purpose, restricts the split to
`21..231`, uses `0.63` as an entry boundary, or supplies a QM stop, risk budget,
spread ceiling, or lifecycle. No source return, significance, Sharpe ratio,
drawdown, trade count, CFD-equivalence, or correlation claim transfers.

## Locked hypothesis

Physical supply, storage, transport, refining, hedging, geopolitical, and
demand shocks can create discrete changes in the variance of WTI returns. A
dominant variance shift can mark a new information regime. If the cumulative
raw return after that estimated shift has a nonzero sign, continue that sign
for one monthly package.

At the first executable D1 tick of a genuine new broker month:

1. Reconstruct 253 strictly chronological completed `XTIUSD.DWX` D1 closes,
   oldest to newest, excluding the current bar.
2. Form 252 adjacent chronological log returns `r[0..251]`, calculate their
   arithmetic mean, and set `a[i]=r[i]-mean(r)`.
3. Let `C_k=sum(a[i]^2, i=0..k-1)` and `C_T=C_252`. For each integer
   `k=21..231`, compute:

```text
D_k = C_k / C_T - k / 252
M_k = sqrt(252 / 2) * abs(D_k)
```

4. Select the largest finite `M_k`; an exact tie selects the most recent
   split. Consume flat when `C_T<=1e-16`, arithmetic is nonfinite, or
   `max(M_k)<0.63`.
5. The inclusive `0.63` boundary is the paper's reported 25th-percentile
   finite-sample value for both `T=200` and `T=300`. It is deliberately an
   activity boundary near the strategy's 252-return window, not a 95% test or
   significance claim.
6. Compute `post_return=sum(r[i], i=k..251)`. Buy only when it is positive,
   sell only when negative, and consume flat on exact zero. The score never
   scales risk.
7. Risk one fixed budget, attach a frozen `3.5*ATR(20,D1)` hard stop, and exit
   at the next genuine month or after forty calendar days.

The interior guard leaves at least 21 observations on both sides. It is a QM
stability adaptation motivated by the paper's endpoint and outlier cautions,
not part of the source statistic.

## Non-duplicate boundary

The corrected-root checker scanned 4,751 registry identities, 1,389 card
files, and 45 Strategy Wiki nodes and found no exact or fuzzy match. Receipt:
`artifacts/qm5_wti_css_volshift_tr_preallocation_dedup_20260831.json`.

- `QM5_41245_wti-mcusum-shift-tr` accumulates centered monthly return levels
  to estimate a mean shift. This rule accumulates squared centered daily
  returns to estimate a variance shift, then uses a separate post-shift raw
  return for direction.
- `QM5_41250_wti-mperm-scale-tr` compares two fixed monthly blocks through
  exact label permutations of MAD. This rule retains temporal order, scans an
  interior daily break location, and performs no permutation.
- `QM5_20298_wti-vov-regime` ranks a monthly volatility-of-volatility measure.
  This rule uses the source-defined CSS path and no volatility rank.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG oscillator
  pullback, not a symmetric monthly direct-WTI structural-break trend.

Verdict:
`DISTINCT_WTI_MONTHLY_252_D1_CENTERED_CUMULATIVE_SQUARES_DOMINANT_INTERIOR_VARIANCE_SHIFT_POST_BREAK_RETURN_CONTINUATION`.

## Reputable-source criteria

- R1 `PASS_WITH_AI_SYNTHESIS_BOUNDARY`: one durable AI source ID, a complete
  peer-reviewed statistical paper, and a complete governed peer-reviewed WTI
  trading packet; the exact conjunction is bounded.
- R2 `PASS`: clock, window, centering, squares, cumulative path, split range,
  normalization, tie rule, threshold, side, attempt, risk, stop, spread, and
  exits are fixed.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native WTI D1 and MT5
  state supply every runtime input; roll, basis, financing, gaps, and broker-
  month labels remain risks.
- R4 `PASS`: deterministic finite arithmetic and native execution state only;
  no ML, trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Claim, kill, and safety boundary

This packet establishes no profitability, significance, independence,
decorrelation, or portfolio fitness. Q02 kills zero trades, any full scored
post-warm-up year below five completed positions, nonpositive governed
economics, future leakage, or a deterministic-fixture failure. Q09 alone owns
realized portfolio overlap. Failure may not be rescued by changing the 252-D1
window, centering, split guard, `0.63` threshold, carrier, stop, or hold.

This packet authorizes one card, one branch-only non-live build, strict Q01,
and one paced Q02 handoff if the whole-host CPU ceiling permits. It authorizes
no manual backtest, live/demo/shadow/stress/optimization preset, AutoTrading
action, `T_Live` change, deploy/live manifest, portfolio-gate edit,
correlation waiver, or portfolio admission.
