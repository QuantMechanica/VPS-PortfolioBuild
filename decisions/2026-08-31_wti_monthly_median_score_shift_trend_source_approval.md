# WTI Monthly Median-Score Shift Trend - Source Approval

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

- proposed slug: `wti-mmedscore-shift-tr`
- proposed strategy ID: `AI-CODEX-WTI-MMEDSCORE-20260831_S01`
- source ID: `AI-CODEX-WTI-MMEDSCORE-20260831`
- host / slot 0: exact `XTIUSD.DWX`, D1
- clock: first executable D1 tick after a genuine broker-month transition
- signal: an exact fixed-six/fixed-six pooled grand-median score on twelve
  completed monthly WTI log returns
- lifecycle: one consumed monthly attempt, one fixed-risk position, frozen
  ATR stop, next-month renewal, and forty-calendar-day stale repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Single governed source and evidence boundary

The single R1 lineage is the AI-originated governed packet
`strategy-seeds/sources/AI-CODEX-WTI-MMEDSCORE-20260831/source.md`.
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

1. Persist the normalized month key before history, signal, news, spread,
   quote, stop, sizing, margin, or order checks. Never retry the same month.
2. Reconstruct thirteen consecutive completed WTI month-end closes and form
   twelve adjacent log returns, fixed oldest six versus newest six.
3. Require strict pooled uniqueness. Sort all twelve returns and place the
   grand-median boundary strictly between pooled ranks 6 and 7.
4. Count `H`, the newest-block returns in pooled ranks 7 through 12. Enumerate
   all `C(12,6)=924` fixed-size rank assignments and count assignments at least
   as far from the neutral count 3 as observed.
5. Qualify only when `H<=1` or `H>=5`, equivalently when the inclusive exact
   two-sided tail contains at most 74 of 924 assignments. Buy for `H>=5` and
   sell for `H<=1`; consume flat otherwise. Score magnitude never scales risk.
6. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5*ATR(20,D1)` broker hard stop, no target, and a 1,500-point spread cap.
7. Close at the next genuine broker month or after forty calendar days. Both
   news axes and Friday close remain off.

The `74/924` boundary is a finite rank-combinatoric activity fact, not a
probability, significance, or performance claim.

## Reputable-source criteria

- R1 `PASS_WITH_AI_SYNTHESIS_AND_POLICY_BOUNDARY`: one durable source ID,
  prompt/output trail, complete governed peer-reviewed WTI evidence, and an
  explicit deferred-method boundary.
- R2 `PASS`: clock, history, return arithmetic, fixed blocks, tie rule, pooled
  order, score, enumeration, threshold, side, attempt, risk, stop, spread, and
  exits are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native WTI D1 and MT5
  state supply all runtime inputs; roll, basis, financing, and gaps remain.
- R4 `PASS`: deterministic native arithmetic only; no ML, trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Non-duplicate decision

The corrected-root receipt
`artifacts/qm5_wti_mmedscore_shift_tr_preallocation_dedup_20260831.json`,
SHA-256
`C7C8EB5524CA5B2719F30A9863CEB5F4FA2FEBD5002033C0C31DCAE043ED10EC`,
scanned 4,755 registry identities, 1,393 cards, and 45 Strategy Wiki nodes. It
found no exact identity and two fuzzy neighbors.

Manual review resolves both:

- `QM5_41255_wti-mcvm-shift-tr` integrates the squared old-versus-recent
  empirical-CDF membership path over every pooled rank. This candidate throws
  away all within-half ordering and retains only the recent count above the
  pooled grand median. Rank paths with equal `H` always agree here but can
  differ under the integrated path.
- `QM5_41250_wti-mperm-scale-tr` compares within-block median absolute
  deviations and follows the recent arithmetic mean. A pure location shift
  with unchanged dispersion can qualify here and remain flat there; a
  symmetric scale expansion can qualify there and remains directionless here.
- `QM5_41137_wti-mmedian-shift-mom` follows any nonzero difference between two
  block medians. This candidate additionally requires at least five of six
  recent returns to occupy the pooled upper half (or at most one), so ordinary
  median separation is insufficient.
- `QM5_41176_wti-mwilcoxon-shift-tr` sums all cross-block pairwise wins. This
  candidate ignores rank distances within each pooled half and therefore can
  disagree with the Wilcoxon/Mann-Whitney score.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_RETURN_POOLED_GRAND_MEDIAN_SCORE_EXACT_924_TAIL74_LOCATION_SHIFT_CONTINUATION`.

## Kill and safety boundary

Q02 retires the unchanged baseline on zero positions, fewer than five
completed positions in any full scored post-warm-up year, nonpositive governed
economics, current-month leakage, wrong return or rank order, accepted tie,
wrong upper-half count, wrong assignment or tail count, wrong side, missing
stop, invalid risk mode, malformed lifecycle, or nondeterminism. No
after-result parameter rescue is authorized.

WTI adds physical crude-oil exposure absent from the certified carrier set,
but this approval makes no independence claim. Q09 alone evaluates overlap.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal control; AutoTrading; `T_Live`; deploy or live
manifests; portfolio-gate changes; portfolio admission; decorrelation claims;
and correlation waivers.
