# WTI Exact-Permutation Integrated-ECDF Distribution-Shift Trend - Source Approval

Date: 2026-08-31

Decision: `APPROVED_SOURCE` for one bounded direct-WTI structural-trend
Strategy Card, deterministic EA-ID and one-slot magic allocation, one
branch-only non-live build, strict Q01 validation, and one paced Q02 enqueue
only while the governed whole-host CPU ceiling remains clear. This decision
does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. The mission requests one new structural,
low-frequency commodity/energy sleeve outside the certified
XAU/SP500/NDX/XNG carrier set, lists direct WTI as an eligible route, requires
reputable-source criteria and a `RISK_FIXED` backtest preset, and forbids live,
AutoTrading, portfolio-gate, and `T_Live` manifest mutations.

## Candidate identity

- proposed slug: `wti-mcvm-shift-tr`
- proposed strategy ID: `AI-CODEX-WTI-MCVM-20260831_S01`
- source ID: `AI-CODEX-WTI-MCVM-20260831`
- host / slot 0: exact `XTIUSD.DWX`, D1
- clock: first executable D1 tick after a genuine broker-month transition
- signal: integrated squared old-versus-recent empirical-CDF rank path over
  fixed six/six monthly-return blocks, qualified by all 924 label assignments
- lifecycle: one consumed monthly attempt, one fixed-risk position, frozen
  ATR stop, next-month renewal, and forty-calendar-day stale repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Single governed source and evidence boundary

The single R1 lineage is the AI-originated governed packet
`strategy-seeds/sources/AI-CODEX-WTI-MCVM-20260831/source.md`.
`processes/qb_reputable_source_criteria.md` expressly permits AI-originated
strategies with a durable prompt/output trail and claim boundary.

The complete governed peer-reviewed WTI packet
`strategy-seeds/sources/MOP-TSMOM-2012/source.md` supports only the carrier,
monthly cadence, and own-return continuation direction. The Anderson (1962)
bibliographic record is method context only. Its DOI route returned
`DEFERRED:SOURCE_POLICY`, so no inaccessible text, critical value,
significance, or empirical finding is imported.

## Locked mechanic

At the first executable D1 tick of each genuine broker month:

1. Persist the normalized month key before history, signal, news, spread,
   quote, stop, sizing, margin, or order checks. Never retry the same month.
2. Reconstruct thirteen consecutive completed WTI month-end closes and form
   twelve adjacent log returns, fixed oldest six versus newest six.
3. Require strict pooled uniqueness. Sort the returns while retaining block
   labels and calculate `S=sum((old_seen-recent_seen)^2)` over the complete
   pooled rank path.
4. Enumerate all 924 assignments of six ranks to a pseudo-recent sample and
   count scores at least as large as observed. Require exactly 924 assignments
   and an inclusive tail count at most 460 (equivalently `S>=22`).
5. Continue the actual recent-minus-old median direction outside a `1e-12`
   zero band. The score and median magnitude never scale risk.
6. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5*ATR(20,D1)` broker hard stop, no target, and a 1,500-point spread cap.
7. Close at the next genuine month or after forty calendar days. Both news
   axes and Friday close remain off.

The exact 460/924 qualification count is a pre-market density fact only, not
a probability, significance, or performance claim.

## Reputable-source criteria

- R1 `PASS_WITH_AI_SYNTHESIS_AND_POLICY_BOUNDARY`: one durable source ID,
  prompt/output trail, complete governed peer-reviewed WTI evidence, and an
  explicit deferred-method boundary.
- R2 `PASS`: clock, history, return arithmetic, fixed blocks, tie rule, rank
  path, score, enumeration, boundary, side, attempt, risk, stop, spread, and
  exits are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native WTI D1 and MT5
  state supply all runtime inputs; roll/basis/financing/gap risks remain.
- R4 `PASS`: deterministic native arithmetic only; no ML, trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Non-duplicate decision

The corrected-root receipt
`artifacts/qm5_wti_mcvm_shift_tr_preallocation_dedup_20260831.json`, SHA-256
`7413C89065F632E484174D98377097879C2541E1F2B2F97C989C01C73660741D`,
scanned 4,754 registry identities, 1,392 cards, and 45 Strategy Wiki nodes. It
found no exact identity and one fuzzy neighbor, `QM5_41250`.

Manual review resolves that neighbor: `QM5_41250` qualifies on a difference
between within-block median absolute deviations, while this candidate
qualifies on the integrated pooled-label path. A pure location displacement
with unchanged dispersion can qualify only here; a symmetric scale expansion
with unchanged medians is directionless here and can qualify there.

The rule also differs from maximum signed price-level ECDF `QM5_41183`,
price-level Wilcoxon rank sum `QM5_41176`, Welch mean/variance
`QM5_41249`, and Brunner-Munzel placement standardization `QM5_41251`.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_RETURN_INTEGRATED_SQUARED_ECDF_PATH_EXACT_924_LABEL_TAIL460_RECENT_MEDIAN_CONTINUATION`.

## Kill and safety boundary

Q02 retires the unchanged baseline on zero positions, fewer than five
completed positions in any full scored post-warm-up year, nonpositive governed
economics, current-month leakage, wrong return or rank order, accepted tie,
wrong path score, wrong assignment count or tail boundary, wrong median side,
missing stop, invalid risk mode, malformed lifecycle, or nondeterminism. No
after-result parameter rescue is authorized.

WTI adds physical crude-oil exposure absent from the certified carrier set,
but this approval makes no independence claim. Q09 alone evaluates overlap.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal control; AutoTrading; `T_Live`; deploy or live
manifests; portfolio-gate changes; portfolio admission; decorrelation claims;
and correlation waivers.
