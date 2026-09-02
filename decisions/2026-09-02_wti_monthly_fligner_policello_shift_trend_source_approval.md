# WTI Monthly Fligner-Policello Shift Trend - Source Approval

Date: 2026-09-02

Decision: `APPROVED_SOURCE` for one bounded direct-WTI structural-trend
Strategy Card, deterministic identity and slot-0 magic allocation, one
branch-only non-live build, strict Q01 validation, and one paced Q02 enqueue
only if the governed whole-host CPU ceiling remains clear. This decision does
not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It requests one new structural, low-frequency,
non-duplicate commodity/energy edge outside the certified
XAU/SP500/NDX/XNG book, with reputable-source criteria and a `RISK_FIXED`
backtest preset. It forbids portfolio-gate, `T_Live`, live-manifest,
AutoTrading, and live-use changes.

## Candidate identity

- proposed slug: `wti-mfp-shift-tr`
- proposed strategy ID: `AI-CODEX-WTI-MFP-SHIFT-20260902_S01`
- source ID: `AI-CODEX-WTI-MFP-SHIFT-20260902`
- host / slot 0: exact `XTIUSD.DWX`, D1
- clock: first executable D1 tick after a genuine broker-month transition
- signal: ten old versus ten recent completed monthly log returns, exact
  cross-block pair placements, Fligner-Policello unequal-shape rank-location
  score, and inclusive absolute `0.600` continuation boundary
- lifecycle: one consumed monthly attempt, one fixed-risk position, frozen
  ATR stop, next-month renewal, and forty-calendar-day stale repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts one.

## Single governed source and evidence boundary

The single R1 lineage is the AI-originated packet
`strategy-seeds/sources/AI-CODEX-WTI-MFP-SHIFT-20260902/source.md`.
`processes/qb_reputable_source_criteria.md` permits AI-originated strategies
when their prompt/output trail, claim boundary, and source ID are durable.

Supporting evidence is bounded to:

- the complete governed read of Moskowitz, Ooi, and Pedersen (2012), *Time
  Series Momentum*, *Journal of Financial Economics* 104(2), 228-250, DOI
  `10.1016/j.jfineco.2011.11.003`, including explicit NYMEX WTI membership and
  monthly own-return continuation;
- Fligner and Policello (1981), *Robust Rank Procedures for the Behrens-Fisher
  Problem*, *Journal of the American Statistical Association* 76(373),
  162-168, DOI `10.1080/01621459.1981.10477623`, limited to publisher metadata
  and abstract; and
- official CRAN `NSM3` 1.20 documentation plus the complete pinned CRAN-mirror
  `R/pFligPoli.R` implementation, Git commit
  `4f610ad57ca573f82a76f413455206b0ccce2ac2`, blob
  `9a41229d88e5ff0173ca6ec3273a3ae0dcec0834`.

The WTI carrier and continuation direction transfer from the trading paper;
the pair-placement score transfers from the method implementation. The fixed
ten/ten trading conjunction, `0.600` activity boundary, risk, stop, spread,
and lifecycle are disclosed pre-result QM choices. Retrieval evidence is
`strategy-seeds/sources/AI-CODEX-WTI-MFP-SHIFT-20260902/retrieval_route_20260902.json`.

## Locked mechanic

At the first executable D1 tick of each genuine broker month:

1. Persist the normalized month key before all fallible gates and never retry
   the same month.
2. Reconstruct twenty-one consecutive completed WTI month-end closes and form
   twenty adjacent log returns, fixed as ten old and ten recent.
3. Compute exact half-credit ties and the source-defined `p_i`, `q_j`,
   placement means, separate squared deviations, `p_bar*q_bar` term, and
   Fligner-Policello score.
4. At a denominator no greater than `1e-12`, use a finite signed `1e6` limit
   only when the numerator is directional; otherwise consume flat.
5. Buy at `U_FP >= +0.600`, sell at `U_FP <= -0.600`, and consume flat inside
   the band. Never use the score for sizing.
6. Open at most one exact-WTI slot-0 position with `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread cap.
7. Close at the next genuine broker month or after forty calendar days. Both
   news axes and Friday close remain off so the monthly hold is preserved.

Exact pre-data enumeration of all `C(20,10)=184756` distinct-rank allocations
qualifies `97,616`, a `52.8351%` activity density or 6.340 theoretical attempts
per twelve month clocks. This is not market evidence or significance. Receipt:
`artifacts/qm5_wti_mfp_shift_tr_threshold_density_20260902.json`.

## Reputable-source findings

- R1 `PASS_WITH_AI_SYNTHESIS_AND_METHOD_BODY_BOUNDARY`: one durable AI source,
  complete-read peer-reviewed WTI evidence, peer-reviewed method metadata and
  abstract, a complete pinned official implementation, and explicit no-result
  boundaries.
- R2 `PASS`: the data clock, blocks, pair placements, statistic, degeneracy,
  threshold, side, attempt, risk, stop, spread, and exits are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 history
  and MT5-native state supply every runtime input.
- R4 `PASS`: deterministic native arithmetic only; no ML, banned signal
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Non-duplicate decision

The corrected-root checker scanned 4,783 registry identities, 1,419 cards,
and 45 Strategy Wiki nodes, found no exact identity, and raised `QM5_41183`
and `QM5_41251` for manual review.

- `QM5_41183` is a six-by-six price-level KS maximum-gap rule; this candidate
  is a ten-by-ten monthly-return average-placement statistic with a
  heteroskedastic dispersion denominator.
- `QM5_41251` is corrected Brunner-Munzel pooled/within-rank
  studentization. This candidate uses Fligner-Policello pair-placement
  deviations and the `p_bar*q_bar` term. A fixed rank allocation qualifies
  here while remaining flat under that neighbor's locked threshold.
- Equal Mann-Whitney totals can fall on opposite sides of this candidate's
  boundary, proving it is not the unstudentized `QM5_41176` rule.
- Raw Welch, scale, CDF-supremum, change-point, and certified XNG RSI families
  use different state functions, carriers, or lifecycles.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_TEN_BY_TEN_FLIGNER_POLICELLO_UNEQUAL_SHAPE_RANK_LOCATION_CONTINUATION`.

## Kill and safety boundary

Q02 retires the unchanged baseline on zero positions, fewer than five
completed positions in any full scored post-warm-up year, nonpositive
governed economics, future leakage, wrong return orientation or membership,
wrong placement arithmetic, wrong degeneracy or boundary behavior, missing
stop, invalid fixed-risk mode, malformed lifecycle, or nondeterminism. No
after-result parameter rescue is authorized.

Direct WTI adds a physical crude-oil carrier absent from the certified book,
but this is not a decorrelation claim. Q09 alone may evaluate overlap.

Excluded: manual backtests; live/demo/shadow/stress/optimization presets;
terminal control; AutoTrading; `T_Live`; deploy/live manifests; portfolio-gate
changes; portfolio admission; correlation waivers; and any live-use authority.
