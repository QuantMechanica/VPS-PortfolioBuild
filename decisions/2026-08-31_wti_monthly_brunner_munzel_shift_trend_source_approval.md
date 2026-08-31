# WTI Monthly Brunner-Munzel Shift Trend - Source Approval

Date: 2026-08-31

Decision: `APPROVED_SOURCE` for one bounded direct-WTI structural-trend
Strategy Card, deterministic EA-ID and one-slot magic allocation, one
branch-only non-live build, strict Q01 validation, and one paced Q02 enqueue
only while the governed whole-host CPU ceiling remains clear. This decision
does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. The mission requires one new structural,
low-frequency commodity/energy sleeve outside the certified
XAU/SP500/NDX/XNG carrier set, reputable-source criteria, a `RISK_FIXED`
backtest preset, committed non-duplicate work, and one Q02 handoff. It forbids
live, AutoTrading, portfolio-gate, and `T_Live` manifest mutations.

## Candidate identity

- proposed slug: `wti-mbrunner-shift-tr`
- proposed strategy ID: `AI-CODEX-WTI-MBRUNNER-20260831_S01`
- source ID: `AI-CODEX-WTI-MBRUNNER-20260831`
- host / slot 0: exact `XTIUSD.DWX`, D1
- clock: first executable D1 tick after a genuine broker-month transition
- signal: ten older versus ten recent completed monthly log returns, exact
  midranks, separate rank-placement variances, and the corrected
  Brunner-Munzel studentized stochastic-order score
- lifecycle: one consumed monthly attempt, one fixed-risk position, frozen
  ATR stop, next-month renewal, and forty-calendar-day stale repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Single governed source and supporting evidence

The single R1 lineage is the AI-originated governed packet
`strategy-seeds/sources/AI-CODEX-WTI-MBRUNNER-20260831/source.md`.
`processes/qb_reputable_source_criteria.md` expressly permits an AI-originated
strategy when its prompt/output trail, claim boundary, and source ID are
durable.

Supporting evidence is bounded to:

- complete governed read of Moskowitz, Ooi, and Pedersen (2012), *Time Series
  Momentum*, *Journal of Financial Economics* 104(2), 228-250, DOI
  `10.1016/j.jfineco.2011.11.003`, including NYMEX WTI and monthly own-return
  continuation;
- Brunner and Munzel (2000), *Biometrical Journal* 42(1), 17-25, DOI
  `10.1002/(SICI)1521-4036(200001)42:1<17::AID-BIMJ17>3.0.CO;2-U`, supporting
  a heteroskedastic rank procedure with separately estimated variance; and
- the official CRAN `lawstat` manual plus the complete pinned CRAN-mirror
  implementation, Git blob `de99dac14eaec03bada934e1ae2b2bf9714e9ebf`,
  supporting the corrected combined-rank, within-rank, relative-effect, and
  studentization formula.

The WTI carrier and continuation direction transfer from the trading paper;
the statistic arithmetic transfers from the statistical method. The fixed
ten/ten trading conjunction, score threshold, risk, stop, spread, and
lifecycle are disclosed pre-result QM choices. Retrieval evidence is
`strategy-seeds/sources/AI-CODEX-WTI-MBRUNNER-20260831/retrieval_route_20260831.json`.

## Locked mechanic

At the first executable D1 tick of each genuine broker month:

1. Persist the normalized month key before history, signal, news, spread,
   quote, stop, sizing, margin, or order checks. Never retry the same month.
2. Reconstruct twenty-one consecutive completed WTI month-end closes and
   form twenty adjacent log returns. Fix ten old and ten recent returns.
3. Compute exact average ranks for ties separately in each block and in the
   pooled old-then-recent vector.
4. Apply the corrected `lawstat` Brunner-Munzel placement-variance and
   studentization formula exactly. Do not calculate a p-value or use the
   score for sizing.
5. For a denominator at or below `1e-12`, use the finite directional limit
   `+/-1e6` only when pooled-rank means differ; otherwise consume flat.
6. Buy at `T_BM >= 0.625`, sell at `T_BM <= -0.625`, otherwise remain flat.
7. Open at most one exact-WTI slot-0 position with `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5*ATR(20,D1)` broker hard stop, no target, and a 1,500-point spread cap.
8. Close at the next genuine month or after forty calendar days. Both news
   axes and Friday close remain off so the month hold is not rewritten.

Exact pre-data enumeration over all `C(20,10)=184756` distinct-rank label
allocations qualifies 97,078 at `|T_BM|>=0.625`, a 52.5439% activity density
or 6.305 attempts per twelve month clocks. This is an activity prior, not a
market result or significance statement. Receipt:
`artifacts/qm5_wti_mbrunner_shift_tr_threshold_density_20260831.json`.

## Reputable-source criteria

- R1 `PASS_WITH_AI_SYNTHESIS_BOUNDARY`: exactly one durable AI source ID,
  complete-read peer-reviewed WTI evidence, peer-reviewed method metadata,
  and a pinned corrected implementation.
- R2 `PASS`: month clock, endpoints, returns, fixed samples, ranks, placement
  variances, degeneracy rule, threshold, side, attempt, fixed risk, hard stop,
  spread, and exits are deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 state provide all runtime inputs; roll,
  financing, basis, gap, and broker-month-label risks remain.
- R4 `PASS`: completed prices, logarithms, finite ranks, comparisons, ATR risk
  control, and native position/deal state only; no ML, trained output, banned
  signal indicator, external runtime feed, grid, martingale, scale-in, or
  pyramid.

## Non-duplicate decision

The corrected-root canonical receipt
`artifacts/qm5_wti_mbrunner_shift_tr_preallocation_dedup_20260831.json`
scanned 4,750 registry identities, 1,388 cards, and 45 Strategy Wiki nodes. It
found no exact identity and fuzzy neighbors `QM5_41249` and `QM5_41250`.

Manual mechanic review resolves them and the closest rank families:

- Welch `QM5_41249` studentizes raw means with raw variances; this candidate
  studentizes pooled-versus-within rank placements and is monotone-transform
  invariant.
- permutation-scale `QM5_41250` qualifies a MAD expansion across 924 runtime
  relabelings; this candidate tests a stochastic-order location effect with no
  MAD or runtime enumeration.
- Mann-Whitney `QM5_41176` thresholds one unstudentized cross-pair count; this
  candidate uses separate rank-placement variances and distinguishes equal-U
  heteroskedastic allocations.
- KS `QM5_41183` takes a maximum empirical-CDF gap; this candidate uses an
  average relative effect with placement-variance studentization.
- Pettitt `QM5_41172` searches split points; this candidate fixes the ten/ten
  time split.
- certified `QM5_12567` is a long-only two-day XNG oscillator pullback.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_TEN_BY_TEN_BRUNNER_MUNZEL_STUDENTIZED_RANK_PLACEMENT_STOCHASTIC_DOMINANCE_CONTINUATION`.

## Kill and safety boundary

Q02 retires the unchanged baseline on zero positions, fewer than five
completed positions in any full scored post-warm-up year, nonpositive
governed economics, future leakage, wrong return orientation, wrong rank or
placement variance, boundary error, missing stop, invalid risk mode,
malformed lifecycle, or nondeterminism. Failure may not be rescued by
changing the block, rank convention, variance formula, threshold, side, stop,
or hold.

WTI supplies physical crude-oil exposure absent from the certified book, but
this approval does not assert independence. Q09 alone may evaluate overlap.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal control; AutoTrading; `T_Live`; deploy or live
manifests; portfolio-gate changes; portfolio admission; decorrelation claims;
and correlation waivers.
