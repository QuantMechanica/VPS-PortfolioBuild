# WTI Monthly Median-Score 524 Trend - Source Approval

Date: 2026-08-31

Decision: `APPROVED_SOURCE` for one bounded direct-WTI structural-trend
Strategy Card, deterministic EA-ID and one-slot magic allocation, one
branch-only non-live build, strict Q01 validation, and one paced Q02 enqueue
only while the governed whole-host CPU ceiling remains clear. This decision
does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. The mission requests one new structural,
low-frequency commodity/energy sleeve outside the certified
XAU/SP500/NDX/XNG carrier set, lists direct WTI trend/seasonality as an
eligible route, requires reputable-source criteria and a `RISK_FIXED`
backtest preset, and forbids live, AutoTrading, portfolio-gate, and `T_Live`
manifest mutations.

## Candidate identity

- proposed slug: `wti-mmedscore524-tr`
- proposed strategy ID: `AI-CODEX-WTI-MMEDSCORE524-20260831_S01`
- source ID: `AI-CODEX-WTI-MMEDSCORE524-20260831`
- host / slot 0: exact `XTIUSD.DWX`, D1
- clock: first executable D1 tick after a genuine broker-month transition
- signal: fixed-six/fixed-six pooled grand-median score on twelve completed
  monthly WTI log returns, with the recent count outside neutral 3-of-6
- lifecycle: one consumed monthly attempt, one fixed-risk position, frozen
  ATR stop, next-month renewal, and forty-calendar-day stale repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Pre-result activity correction

The immutable predecessor `AI-CODEX-WTI-MMEDSCORE-20260831` was rejected at G0
before card approval, build, compile, tester, or queue work because its exact
5-of-6 boundary admitted only 74/924 rank states, or 0.961 monthly decisions
per year. Evidence:
`docs/ops/evidence/2026-08-31_qm5_41256_frequency_prior_g0_stop.md`.

This source is separately identified and deduplicated. Before any market test,
it locks the only non-neutral upper-half count: `H<=2` or `H>=4`. That admits
`2*(C(6,0)^2+C(6,1)^2+C(6,2)^2)=524` of 924 assignments, a market-free prior
of 6.805 decisions/year. This is cadence design against the already-binding
Q02 floor, not after-result parameter tuning.

## Single governed source and evidence boundary

The single R1 lineage is the AI-originated governed packet
`strategy-seeds/sources/AI-CODEX-WTI-MMEDSCORE524-20260831/source.md`.
`processes/qb_reputable_source_criteria.md` expressly permits AI-originated
strategies with a durable prompt/output trail and claim boundary.

The complete governed peer-reviewed WTI packet
`strategy-seeds/sources/MOP-TSMOM-2012/source.md` supports only WTI membership,
monthly cadence, and own-return continuation direction. The NIST Dataplot
median-test page is bibliographic naming context only. Its deterministic
generic route returned `DEFERRED:SOURCE_POLICY`, so no inaccessible formula,
critical value, significance, or empirical finding is imported.

## Locked mechanic

At the first executable D1 tick of each genuine broker month:

1. Persist the normalized month key before every fallible gate; never retry.
2. Reconstruct thirteen consecutive completed WTI month-end closes and form
   twelve adjacent log returns, fixed oldest six versus newest six.
3. Require strict pooled uniqueness. Sort all twelve returns and place the
   grand-median boundary strictly between pooled ranks 6 and 7.
4. Count `H`, the newest-block returns in pooled ranks 7 through 12. Enumerate
   all `C(12,6)=924` fixed-size rank assignments and count assignments at least
   as far from the neutral count 3 as observed.
5. Qualify only when `H<=2` or `H>=4`, equivalently when the inclusive exact
   two-sided tail contains at most 524 of 924 assignments. Buy for `H>=4` and
   sell for `H<=2`; consume flat at exactly `H=3`. Magnitude never scales risk.
6. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5*ATR(20,D1)` broker hard stop, no target, and a 1,500-point spread cap.
7. Close at the next genuine broker month or after forty calendar days. Both
   news axes and Friday close remain off.

The `524/924` boundary is a finite rank-combinatoric activity fact, not a
probability, significance, or performance claim.

## Reputable-source criteria

- R1 `PASS_WITH_AI_SYNTHESIS_AND_POLICY_BOUNDARY`: one durable source ID,
  prompt/output trail, complete governed peer-reviewed WTI evidence, and an
  explicit deferred-method boundary.
- R2 `PASS`: clock, history, return arithmetic, fixed blocks, tie rule, pooled
  order, score, enumeration, boundary, side, attempt, risk, stop, spread, and
  exits are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native WTI D1 and MT5
  state supply all runtime inputs; roll, basis, financing, and gaps remain.
- R4 `PASS`: deterministic native arithmetic only; no trained output,
  prohibited signal indicator, external runtime feed, grid, martingale,
  scale-in, or pyramid.

## Non-duplicate decision

The corrected-root receipt
`artifacts/qm5_wti_mmedscore524_tr_preallocation_dedup_20260831.json`, SHA-256
`6993D3B2F7F16145D3642665811F1634E4C16014B8B627501E9A79931DEACC93`,
scanned 4,756 registry identities, 1,393 cards, and 45 Strategy Wiki nodes. It
found no exact identity and two fuzzy neighbors.

- `QM5_41255` integrates the squared old-versus-recent ECDF membership path
  over every pooled rank. This candidate discards all within-half order and
  retains only the recent count above the pooled grand median.
- `QM5_41250` compares within-block median absolute deviations. A pure
  location shift can qualify here and remain flat there; a symmetric scale
  expansion can qualify there and remains directionless here.
- `QM5_41137` follows any nonzero two-block median difference. This candidate
  requires a discrete non-neutral pooled-half majority and exact enumeration.
- `QM5_41176` counts all 36 cross-block pairwise wins. This candidate ignores
  rank distance within each pooled half and can disagree on the same sample.
- Retired unbuilt `QM5_41256` owns the distinct extreme 5-of-6/tail-74 source
  contract and has no approved card, code, binary, tester result, or queue row.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_RETURN_POOLED_GRAND_MEDIAN_SCORE_EXACT_924_TAIL524_NONNEUTRAL_LOCATION_SHIFT_CONTINUATION`.

## Kill and safety boundary

Q02 retires the unchanged baseline on zero positions, fewer than five
completed positions in any full scored post-warm-up year, nonpositive governed
economics, current-month leakage, wrong return/order/count/tail/side, missing
stop, invalid risk mode, malformed lifecycle, or nondeterminism. No
after-result parameter rescue is authorized.

WTI adds physical crude-oil exposure absent from the certified carrier set,
but this approval makes no independence claim. Q09 alone evaluates overlap.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal control; AutoTrading; `T_Live`; deploy or live
manifests; portfolio-gate changes; portfolio admission; decorrelation claims;
and correlation waivers.
