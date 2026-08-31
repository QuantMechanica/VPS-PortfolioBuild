# WTI Monthly Energy-Distance Shift Trend - Source Approval

Date: 2026-09-01

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

- proposed slug: `wti-menergy-shift-tr`
- proposed strategy ID: `AI-CODEX-WTI-MENERGY-20260901_S01`
- source ID: `AI-CODEX-WTI-MENERGY-20260901`
- host / slot 0: exact `XTIUSD.DWX`, D1
- clock: first executable D1 tick after a genuine broker-month transition
- signal: fixed-six/fixed-six two-sample energy distance on twelve completed
  monthly WTI log returns, complete 924-label inclusive tail capped at 3/5,
  with recent-minus-old block-median direction
- lifecycle: one consumed monthly attempt, one fixed-risk position, frozen
  ATR stop, next-month renewal, and forty-calendar-day stale repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Single governed source and evidence boundary

The single R1 lineage is the AI-originated governed packet
`strategy-seeds/sources/AI-CODEX-WTI-MENERGY-20260901/source.md`.
`processes/qb_reputable_source_criteria.md` expressly permits AI-originated
strategies with a durable prompt/output trail and claim boundary.

The complete governed peer-reviewed WTI packet
`strategy-seeds/sources/MOP-TSMOM-2012/source.md` supports only WTI membership,
monthly cadence, and own-return continuation direction. Complete pinned CRAN
`energy` 1.7-12 manual and R source at commit
`5c2b2d553b4245ebe2a7fd933d93b8917cea799b` support only the two-sample
distance formula and resampling context. The Wiley route returned
`DEFERRED:SOURCE_POLICY`; no inaccessible method, threshold, significance, or
empirical finding is imported.

## Locked mechanic

At the first executable D1 tick of each genuine broker month:

1. Persist the normalized month key before every fallible gate; never retry.
2. Reconstruct thirteen consecutive completed WTI month-end closes and form
   twelve adjacent log returns, fixed oldest six versus newest six.
3. Compute the two-sample energy statistic
   `E=3*(2*M_cross-M_old-M_recent)` from ordered-pair mean absolute distances,
   including self-distances in both within-block means.
4. Enumerate all 924 fixed six-of-twelve pseudo-recent labels and count
   `E_perm + 1e-12*max(1,abs(E_obs)) >= E_obs` inclusively.
5. Qualify only when `5*tail_count <= 3*924` (`tail_count<=554`). Buy for a
   recent-minus-old six-point median above `1e-12`, sell below `-1e-12`, and
   consume flat otherwise. Magnitude never scales risk.
6. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5*ATR(20,D1)` broker hard stop, no target, and a 1,500-point spread cap.
7. Close at the next genuine broker month or after forty calendar days. Both
   news axes and Friday close remain off.

The three-fifths tail is an activity setting, not a significance claim. An
equally spaced market-free twelve-value fixture admits 540/924 label states,
or 7.013 decisions per twelve evaluations, before downstream gates.

## Reputable-source criteria

- R1 `PASS_WITH_AI_SYNTHESIS_AND_PINNED_PRIMARY_SOFTWARE`: one durable source
  ID, prompt/output trail, complete governed peer-reviewed WTI evidence,
  complete pinned CRAN method evidence, and an explicit Wiley policy boundary.
- R2 `PASS`: clock, history, return arithmetic, fixed blocks, distance formula,
  tolerance, exhaustive labels, boundary, side, attempt, risk, stop, spread,
  and exits are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native WTI D1 and MT5
  state supply all runtime inputs; roll, basis, financing, and gaps remain.
- R4 `PASS`: deterministic native arithmetic only; no trained output,
  prohibited signal indicator, random runtime resampling, external runtime
  feed, grid, martingale, scale-in, or pyramid.

## Non-duplicate decision

The corrected-root receipt
`artifacts/qm5_wti_menergy_shift_tr_preallocation_dedup_20260901.json`, SHA-256
`23556367C32FB5934B0EAD67BD10C5D97FF35A107FEB85D52083FC20AB499697`,
scanned 4,757 registry identities, 1,394 cards, and 45 Strategy Wiki nodes. It
found no exact identity and three fuzzy neighbors requiring manual resolution.

- `QM5_41255` is a rank-only integrated squared ECDF path. Energy uses actual
  pairwise absolute return distances and changes under nonlinear monotone
  transformations that leave the ECDF rank path unchanged.
- `QM5_41250` compares only within-block MAD scale. Energy combines every
  cross-block distance with both within-block distance fields.
- `QM5_41257` retains only a pooled upper-half label count. Energy retains all
  return magnitudes and every pairwise distance.
- Fixed fixtures produce both disagreement directions against `QM5_41255`, so
  the candidate is not an alias hidden behind a different name.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_RETURN_ENERGY_DISTANCE_EXACT_924_LABEL_PERMUTATION_THREE_FIFTHS_TAIL_MEDIAN_DIRECTION_CONTINUATION`.

## Kill and safety boundary

Q02 retires the unchanged baseline on zero positions, fewer than five
completed positions in any full scored post-warm-up year, nonpositive governed
economics, current-month leakage, wrong distance/order/tail/side, missing stop,
invalid risk mode, malformed lifecycle, or nondeterminism. No after-result
parameter rescue is authorized.

WTI adds physical crude-oil exposure absent from the certified carrier set,
but this approval makes no independence claim. Q09 alone evaluates overlap.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal control; AutoTrading; `T_Live`; deploy or live
manifests; portfolio-gate changes; portfolio admission; decorrelation claims;
and correlation waivers.
