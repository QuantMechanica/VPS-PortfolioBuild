# QM5_41269 XAU/XAG Monthly Centered Klotz Scale-State Reversion - G0

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Verdict: `APPROVED`
- EA identity: `QM5_41269_xauxag-mklotz-scale-rv`
- Strategy ID: `AI-CODEX-XAUXAG-MKLOTZ-SCALE-RV-20260901_S01`
- Approved card:
  `strategy-seeds/cards/approved/QM5_41269_xauxag-mklotz-scale-rv_card.md`
- Source approval:
  `decisions/2026-09-01_xauxag_monthly_klotz_scale_reversion_source_approval.md`
- Source approval commit: `8d5199c31ba3`
- EA-ID allocation commit: `af64044f653f`

## Authority And Scope

The current explicit OWNER mission authorizes one new, committed,
non-duplicate, structural low-frequency commodity/energy sleeve; identifies a
market-neutral-style gold/silver basket as eligible; requires reputable-source
criteria and fixed-risk backtest setfiles; and asks for one Q02 enqueue. This
G0 approves the exact card for build, deterministic reference tests, strict
Q01, and one paced non-live logical-basket Q02 handoff if whole-host CPU
remains below the stated ceiling.

It does not pre-approve activity, economics, robustness, decorrelation,
portfolio admission, deployment, or live use.

## Locked Hypothesis

At the first synchronized executable XAU D1 tick of a new normalized broker
month:

1. reconstruct thirteen completed-month XAU/XAG close pairs and twelve
   adjacent changes in `ln(XAU)-ln(XAG)`;
2. split oldest/recent changes into fixed blocks of six and subtract each
   block's own arithmetic mean;
3. strictly rank the twelve pooled centered residuals and assign the frozen
   `N=12` Klotz score `Phi^-1(rank/13)^2`;
4. require the recent six-score sum to occupy the inclusive upper half of all
   924 fixed-size label assignments (`K_recent>=3.9642160041063397`, inclusive
   upper tail at most 494);
5. fade the sign of the recent-minus-old raw block-mean shift for one broker
   month; and
6. use one equal-target-notional, stop-protected XAU/XAG package under one
   aggregate fixed-risk budget, with no intramonth retry or flip.

The endpoint sample, fixed blocks, separate centering, strict-tie rule,
frozen score literals, inclusive activity boundary, raw-mean side, CFD
carrier, equal-notional package, risk, and lifecycle are pre-result QM
choices. No source reports this exact strategy.

## R1-R4 Verdict

| gate | verdict | reason |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE` | One approved governed AI source; complete peer-reviewed gold/silver carrier evidence with adverse findings; official exchange carrier record; named peer-reviewed Klotz metadata with explicit paper-body access boundary; complete official NIST arithmetic and retrieval hashes. |
| R2 | `PASS` | Exact clock, synchronization, endpoints, changes, block means, centered residuals, ties, score table, standardized diagnostic, enumeration, boundary, side, attempt, aggregate risk, atomicity, and lifecycle are locked. |
| R3 | `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK` | Exact registered XAU/XAG D1 histories plus native MT5 state supply every runtime input. |
| R4 | `PASS` | Deterministic closed-form native arithmetic and bounded loops; no trained output, prohibited signal indicator, external runtime feed, grid, martingale, scale-in, pyramid, or randomization. |

## Source And Claim Boundary

Schweikert supports only a state-dependent, asymmetric gold/silver relation
and preserves adverse evidence against a stable ex-ante vector. CME supports
only the ratio/spread carrier and distinct metal demand drivers. Klotz
metadata and complete NIST pages support only method identity, separate-mean
centering, squared-normal rank scores, and standardized arithmetic.

The original Klotz paper body was not accessible in this retrieval. No hidden
formula, critical value, result, or conclusion is inferred. The card imports
no p-value, efficacy, WTI or CFD equivalence, trade frequency, profit factor,
drawdown, cost, neutrality, correlation, or portfolio statistic.

## Duplicate Verdict

The corrected-root receipt
`artifacts/qm5_xauxag_mklotz_scale_rv_preallocation_dedup_20260901.json`,
SHA-256
`2C5ECB7A982F2C7994F0F1B4EE362A34FB9CC789B53272CF41BB9C3ACC5D565D`,
found no exact identity across 4,768 registry rows, 1,405 card files, and 45
Wiki nodes. Brown-Forsythe and Kuiper were expected fuzzy matches.

Manual review separates this separate-mean-centered, nonlinear squared-normal
score sum from Brown-Forsythe's median-centered numeric deviations and
Kuiper's uncentered ECDF extrema. Fixed source fixtures prove Klotz-only,
Brown-Forsythe-only, and opposite-side outcomes.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_FIXED_SIX_BY_SIX_SEPARATE_MEAN_CENTERED_RESIDUAL_STRICT_RANK_FROZEN_KLOTZ_SQUARED_NORMAL_SCORE_EXACT_924_INCLUSIVE_UPPER_HALF_RAW_MEAN_SHIFT_CONTRARIAN_BASKET`.

## Frequency Prior And Falsification

The frozen no-tie label support has 430 strict-upper, 64 central, and 430
strict-lower assignments. The inclusive gate admits 494/924, a rough 6.416
states per twelve unconstrained monthly attempts before realized centered-
rank constraints, neutral direction, data, and execution gates. This is not a
market measurement. Q02 must retire below five completed packages in any
full post-warm-up year or on nonpositive governed economics. No sample,
centering, score, threshold, side, risk, or hold rescue is authorized.

## Build Authorization

Development may build exactly the approved card after governed magic slots 0
and 1 exist. Required deliverables are:

1. `framework/EAs/QM5_41269_xauxag-mklotz-scale-rv/` with a byte-identical
   card-of-record copy;
2. exact magics `412690000` for `XAUUSD.DWX` and `412690001` for
   `XAGUSD.DWX`, plus the regenerated resolver;
3. one structural `.mq5`, reference parity tests, `SPEC.md`, the validated
   logical `basket_manifest.json`, one logical D1 `RISK_FIXED=1000` setfile,
   and two component validation setfiles;
4. card/schema/build guards and strict governed Q01 compile PASS; and
5. exactly one paced logical-basket Q02 work item only if a fresh five-sample
   whole-host CPU maximum remains below 97 percent.

Excluded: manual tester launch, optimization, live/demo/shadow/stress
presets, component-leg Q02 rows, portfolio-gate edits, correlation waiver,
portfolio admission, deploy/live manifest, `T_Live`, and AutoTrading.

## Safety Boundary

G0 authorizes build and non-live pipeline handoff only. Q02 owns activity and
economics, later unchanged gates own robustness, and Q09 alone may establish
realized decorrelation. Equal target notionals and opposed legs do not prove
market or portfolio neutrality. No live or portfolio authority is created.
