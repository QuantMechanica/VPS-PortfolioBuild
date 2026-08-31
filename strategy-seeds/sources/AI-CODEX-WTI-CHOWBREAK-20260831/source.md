---
source_id: AI-CODEX-WTI-CHOWBREAK-20260831
source_type: ai_originated_governed_synthesis
title: WTI monthly scanned two-regression structural-break continuation
author: OpenAI Codex
supporting_authors: Gregory C. Chow; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
status: approved_source_complete
approval_basis: decisions/2026-08-31_wti_chow_break_trend_source_approval.md
created: 2026-08-31
created_by: Codex
last_reviewed: 2026-08-31
cards_extracted:
  - QM5_41254_wti-chow-break-tr
---

# WTI Monthly Scanned Two-Regression Structural-Break Continuation

## Canonical origin and prompt trail

This is the single R1 lineage for one bounded AI-originated strategy. The
current explicit OWNER mission requests one new structural, low-frequency
commodity/energy sleeve outside the certified XAU/SP500/NDX/XNG carrier set,
names direct WTI trend/seasonality as an eligible route, requires reputable-
source criteria and a fixed-risk baseline, and authorizes a branch-only build
plus one paced Q02 enqueue. `processes/qb_reputable_source_criteria.md`
expressly accepts a durable AI-originated source and prompt/output trail.

Codex fixed the mechanic below before any market test. It is an untested QM
synthesis, not a reported WTI strategy.

## Supporting evidence and access boundary

The governed packet `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
records a complete read of Moskowitz, Ooi, and Pedersen (2012), *Time Series
Momentum*, *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. It supports only NYMEX WTI membership,
monthly decisions, and own-return continuation. It does not test this signal.

Gregory C. Chow (1960), *Tests of Equality Between Sets of Coefficients in Two
Linear Regressions*, *Econometrica* 28(3), 591-605, DOI
`10.2307/1910133`, is bibliographic context for the two-regression residual-
sum-of-squares comparison. The deterministic source router classified the
JSTOR URL `DEFERRED:SOURCE_POLICY`; receipt:
`retrieval_route_20260831.json`. No inaccessible article text, empirical
result, critical value, or significance statement is used as evidence.

The exact rolling scan, split range, threshold, post-break direction, WTI CFD
translation, stop, risk, spread, and lifecycle below are disclosed QM choices.

## Locked hypothesis

Physical supply, storage, transport, refining, hedging, geopolitical, and
demand shocks can alter the slope of WTI's log-price path. If a completed
trading-year path is materially better represented by two linear segments
than one and the newest segment has a nonzero slope, continue that newest
slope for one monthly package.

At the first executable D1 tick of a genuine new broker month:

1. Reconstruct exactly 252 strictly chronological completed `XTIUSD.DWX` D1
   closes, oldest to newest, excluding the current bar, and set
   `y[i]=log(close[i])`, `x[i]=i`, for `i=0..251`.
2. Fit one ordinary-least-squares intercept-and-slope line to all 252 points
   and retain its residual sum of squares `RSS0`.
3. For each split `k=63..189`, fit separate intercept-and-slope lines to
   indices `0..k-1` and `k..251`. Let the summed residual square be `RSSk` and
   compute:

```text
F_k = ((RSS0 - RSSk) / 2) / (RSSk / (252 - 4))
```

4. Reject nonfinite or degenerate arithmetic. A negative improvement beyond
   a `1e-12` numerical tolerance invalidates the signal; a smaller negative
   round-off difference is clamped to zero. Select the largest finite `F_k`;
   an exact tie selects the most recent split.
5. Consume flat when `max(F_k) < 3.0`. The inclusive `3.0` boundary is a
   pre-data activity threshold only. Scanning many unknown break locations,
   serial dependence, heteroskedasticity, and use of log price mean it has no
   nominal F-test significance interpretation.
6. Buy when the selected post-break OLS slope is greater than `1e-12`, sell
   when below `-1e-12`, and consume flat otherwise. The score never scales
   risk.
7. Open at most one exact-WTI slot-0 position with `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen `3.5*ATR(20,D1)` hard
   stop, no target, and a 1,500-point spread ceiling.
8. Close at the next genuine broker month or after forty calendar days. Both
   news axes and Friday close remain off so the intended monthly hold is not
   rewritten.

The 63-observation endpoint guard leaves approximately one quarter of the
window on both sides. It is a QM stability choice, not a transferred source
rule.

## Non-duplicate boundary

The corrected-root canonical checker scanned 4,753 registry identities,
1,391 card files, and 45 Strategy Wiki nodes and found no exact or fuzzy
match. Receipt:
`artifacts/qm5_wti_chow_break_tr_preallocation_dedup_20260831.json`.

- `QM5_20261_wti-lr-trend` fits one line and gates its whole-window slope by
  whole-window R-squared; it never estimates or scores an interior break.
- `QM5_41245_wti-mcusum-shift-tr` searches a cumulative sum of centered
  monthly returns for a mean shift; this rule compares pooled and split OLS
  log-price paths across 252 daily observations.
- `QM5_41249_wti-mwelch-shift-tr` compares two fixed monthly-return means;
  this rule scans an unknown daily path break and compares regression RSS.
- `QM5_41252_wti-css-volshift-tr` searches a cumulative squared-return path
  for a variance shift; this rule searches intercept/slope instability in
  log price and follows only the selected recent slope.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not a symmetric monthly WTI structural-break trend.

Verdict:
`DISTINCT_WTI_MONTHLY_252_D1_LOG_PRICE_SCANNED_POOLED_VS_TWO_SEGMENT_OLS_RSS_BREAK_POST_SEGMENT_SLOPE_CONTINUATION`.

## Reputable-source criteria

- R1 `PASS_WITH_AI_SYNTHESIS_AND_POLICY_BOUNDARY`: exactly one durable AI
  source ID and prompt/output trail; complete-read peer-reviewed WTI evidence
  supports only carrier/cadence/direction; the method citation is explicitly
  deferred and transfers no content claim.
- R2 `PASS`: clock, history, OLS arithmetic, split range, score, tie rule,
  threshold, direction, attempt, fixed risk, stop, spread, and exits are
  deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 state supply all runtime inputs; roll,
  financing, gaps, and broker-month-label risks remain.
- R4 `PASS`: completed prices, logarithms, finite arithmetic, OLS sums,
  comparisons, ATR risk control, and native position/deal state only; no ML,
  trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Claim, kill, and safety boundary

This packet establishes no profitability, statistical significance,
independence, decorrelation, or portfolio fitness. Q02 retires zero trades,
any full scored post-warm-up year below five completed positions, nonpositive
governed economics, future leakage, or a deterministic-fixture failure. Q09
alone owns realized portfolio overlap. Failure may not be rescued by changing
the 252-point window, split guard, score threshold, direction, stop, or hold.

This packet authorizes one card, one branch-only non-live build, strict Q01,
and one paced Q02 handoff if the whole-host CPU ceiling permits. It authorizes
no manual backtest, live/demo/shadow/stress/optimization preset, AutoTrading,
`T_Live`, deploy or live manifest, portfolio-gate mutation, correlation
waiver, or portfolio admission.
