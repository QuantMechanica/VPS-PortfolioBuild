---
source_id: AI-CODEX-WTI-MBRUNNER-20260831
source_type: ai_originated_governed_synthesis
title: WTI monthly Brunner-Munzel studentized stochastic-dominance continuation
author: OpenAI Codex
supporting_authors: Edgar Brunner; Ullrich Munzel; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
status: approved_source_complete
approval_basis: decisions/2026-08-31_wti_monthly_brunner_munzel_shift_trend_source_approval.md
created: 2026-08-31
created_by: Codex
last_reviewed: 2026-08-31
cards_extracted:
  - QM5_41251_wti-mbrunner-shift-tr
---

# WTI Monthly Brunner-Munzel Stochastic-Dominance Continuation

## Canonical origin

This is the single R1 lineage for one bounded AI-originated strategy. The
current explicit OWNER mission requests one new structural, low-frequency
commodity/energy sleeve and expressly permits direct `XTIUSD.DWX` trend or
seasonality. `processes/qb_reputable_source_criteria.md` permits AI-originated
sources when the prompt/output trail and claim boundary are durable.

Codex fixed the mechanic below before any market test. Moskowitz, Ooi, and
Pedersen (2012) support only the WTI carrier, monthly clock, and own-return
continuation direction. Brunner and Munzel (2000), the corrected method
lineage cited by the CRAN `lawstat` manual, and the pinned CRAN-mirror source
support only the rank, relative-effect, placement-variance, and studentization
arithmetic. Their conjunction is a transparent untested QM synthesis.

## Supporting evidence and read boundary

`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
records a complete read of Moskowitz, Ooi, and Pedersen (2012), *Time Series
Momentum*, *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. It explicitly includes NYMEX WTI and monthly
own-return continuation.

The public statistical-method route was classified `ROUTE_GITHUB_API` before
retrieval. The complete pinned CRAN-mirror file
`lawstat/R/brunner.munzel.test.R` has Git blob
`de99dac14eaec03bada934e1ae2b2bf9714e9ebf` and content SHA-256
`51C8E51C84C0460E08CEBB040F14DEAB5A3AC12BEC408ADC4951BF1F60940D0C`.
The official CRAN manual describes the relative effect
`P(X<Y)+0.5P(X=Y)` and says the implementation follows the corrected Neubert
and Brunner (2007) formulation because the 2000 article contains a typo.
Reproducible metadata and boundaries are in `retrieval_route_20260831.json`.

No paper or package tests this rule on a continuous WTI CFD, fixes these two
ten-return blocks, uses `0.625` as a trading threshold, or supplies a QM stop,
risk budget, spread ceiling, or lifecycle. No source return, significance,
Sharpe ratio, drawdown, trade count, CFD-equivalence, or correlation claim
transfers.

## Locked hypothesis

Physical supply, storage, transport, refining, hedging, geopolitical, and
demand shocks can move the distribution of WTI monthly returns. When the ten
newest completed monthly returns stochastically dominate or trail the prior
ten after studentizing the pooled-versus-within rank placements, continue the
direction for one month.

At the first executable D1 tick of a genuine new broker month:

1. Reconstruct twenty-one consecutive completed `XTIUSD.DWX` broker-month end
   closes, oldest to newest, excluding every current-month price.
2. Form twenty adjacent chronological log returns `r[0..19]`; fix
   `old=r[0..9]` and `recent=r[10..19]`.
3. Compute exact average ranks for ties in `old`, `recent`, and the pooled
   vector `old || recent`. Let `m_old` and `m_recent` be the pooled-rank means.
4. With `n=10`, compute the source-defined placement variances:

```text
v_old = sum((pooled_rank_old[i] - within_rank_old[i]
             - m_old + 5.5)^2) / 9
v_recent = sum((pooled_rank_recent[i] - within_rank_recent[i]
                - m_recent + 5.5)^2) / 9

numerator   = 100 * (m_recent - m_old) / 20
denominator = sqrt(10*v_old + 10*v_recent)
T_BM        = numerator / denominator
```

5. If `denominator <= 1e-12` and the pooled-rank means differ, use the finite
   directional limit `sign(m_recent-m_old) * 1e6`; if both are degenerate,
   consume the month flat.
6. Buy only when `T_BM >= 0.625`; sell only when `T_BM <= -0.625`; otherwise
   consume the month flat. Do not compute a p-value, degrees of freedom, or
   confidence interval, and never scale risk by the score.
7. Risk one fixed budget, attach a frozen `3.5*ATR(20,D1)` hard stop, and exit
   at the next genuine month or after forty calendar days.

The ten/ten block meets the method paper's stated small-sample guidance of at
least ten observations per sample, but this strategy does not make a
statistical-significance claim. The fixed `0.625` threshold is a pre-data
activity boundary: exact enumeration of all `C(20,10)=184756` distinct-rank
label allocations qualifies 97,078 (52.5439%), an exchangeability prior of
about 6.31 monthly attempts per year. Receipt:
`artifacts/qm5_wti_mbrunner_shift_tr_threshold_density_20260831.json`.

## Non-duplicate boundary

The corrected-root checker scanned 4,750 registry identities, 1,388 card
files, and 45 Strategy Wiki nodes. It found no exact identity and two fuzzy
neighbors. Receipt:
`artifacts/qm5_wti_mbrunner_shift_tr_preallocation_dedup_20260831.json`.

- `QM5_41249_wti-mwelch-shift-tr` uses raw arithmetic means and raw sample
  variances. This rule is invariant to monotone transforms of the returns and
  uses pooled-versus-within rank-placement variances.
- `QM5_41250_wti-mperm-scale-tr` qualifies a median-absolute-deviation scale
  expansion against 924 relabelings, then uses the recent raw mean only for
  direction. This rule tests a studentized stochastic-order location effect,
  has no MAD, and enumerates no labels at runtime.
- `QM5_41176_wti-mwilcoxon-shift-tr` thresholds the unstudentized
  Mann-Whitney pair-count total. This rule additionally estimates separate
  rank-placement variances and can distinguish allocations having the same U
  but different heteroskedastic placement patterns.
- `QM5_41183_wti-mks-shift-tr` uses the maximum directional empirical-CDF
  gap. This rule averages stochastic ordering through pooled ranks and
  studentizes it rather than taking a CDF supremum.
- `QM5_41172_wti-mpettitt-shift-tr` searches candidate split locations. This
  rule fixes one old/recent ten-month split and never searches a change point.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not a symmetric monthly direct-WTI rank trend.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_TEN_BY_TEN_BRUNNER_MUNZEL_STUDENTIZED_RANK_PLACEMENT_STOCHASTIC_DOMINANCE_CONTINUATION`.

## Reputable-source criteria

- R1 `PASS_WITH_AI_SYNTHESIS_BOUNDARY`: one durable AI source ID, a complete
  peer-reviewed WTI packet, a peer-reviewed statistical-method record, and a
  pinned corrected implementation; the exact trading conjunction is bounded.
- R2 `PASS`: clock, endpoints, blocks, exact midranks, placement variances,
  degeneracy rule, threshold, side, attempt, risk, stop, spread, and exits are
  fixed.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native WTI D1 and MT5
  state supply every runtime input; roll, basis, financing, gaps, and broker-
  month labels remain risks.
- R4 `PASS`: deterministic finite rank arithmetic and native execution state
  only; no ML, trained output, banned signal indicator, external runtime feed,
  grid, martingale, scale-in, or pyramid.

## Claim, kill, and safety boundary

This packet establishes no profitability, significance, independence,
decorrelation, or portfolio fitness. Q02 kills zero trades, any full scored
post-warm-up year below five completed positions, nonpositive governed
economics, future leakage, or a deterministic-fixture failure. Q09 alone owns
realized portfolio overlap. Failure may not be rescued by changing the block,
rank convention, variance formula, `0.625` threshold, carrier, stop, or hold.

This packet authorizes one card, one branch-only non-live build, strict Q01,
and one paced Q02 handoff if the whole-host CPU ceiling permits. It authorizes
no manual backtest, live/demo/shadow/stress/optimization preset, AutoTrading
action, `T_Live` change, deploy/live manifest, portfolio-gate edit,
correlation waiver, or portfolio admission.
