# WTI Monthly Ordinal-Entropy Trend - Source Approval

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

- proposed slug: `wti-mordinal-entropy-tr`
- proposed strategy ID: `AI-CODEX-WTI-MORDENTROPY-20260902_S01`
- source ID: `AI-CODEX-WTI-MORDENTROPY-20260902`
- host / slot 0: exact `XTIUSD.DWX`, D1
- clock: first executable D1 tick after a genuine broker-month transition
- signal: order-three permutation entropy of eight disjoint triples from
  twenty-four completed monthly WTI log returns, inclusive normalized entropy
  ceiling `0.80`, then newest twelve-month return-sign continuation
- lifecycle: one consumed monthly attempt, one fixed-risk position, frozen
  ATR stop, next-month renewal, and forty-calendar-day stale repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts one.

## Single governed source and evidence boundary

The single R1 lineage is the AI-originated packet
`strategy-seeds/sources/AI-CODEX-WTI-MORDENTROPY-20260902/source.md`.
`processes/qb_reputable_source_criteria.md` permits AI-originated strategies
when their prompt/output trail, claim boundary, and source ID are durable.

Supporting evidence is bounded to:

- the complete official APS four-page read of Bandt and Pompe (2002),
  "Permutation Entropy: A Natural Complexity Measure for Time Series,"
  *Physical Review Letters* 88, 174102, DOI
  `10.1103/PhysRevLett.88.174102`; and
- the complete governed read of Moskowitz, Ooi, and Pedersen (2012), "Time
  Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
  `10.1016/j.jfineco.2011.11.003`, including explicit NYMEX WTI membership
  and monthly own-return continuation.

The method paper supplies ordinal-pattern entropy only. The trading paper
supplies the carrier and continuation direction only. The disjoint triples,
eight-observation entropy sample, `0.80` gate, conjunction, CFD mapping, risk,
stop, spread, and lifecycle are disclosed pre-result QM choices. Retrieval
evidence is
`strategy-seeds/sources/AI-CODEX-WTI-MORDENTROPY-20260902/retrieval_route_20260902.json`.

## Locked mechanic

At the first executable D1 tick of each genuine broker month:

1. Persist the normalized month key before every fallible gate and never retry
   the same month.
2. Reconstruct twenty-five consecutive completed WTI month-end closes and
   form twenty-four adjacent chronological log returns.
3. Partition the returns into eight non-overlapping triples. Reject a
   within-triple relative tie at `1e-12`; no random tie breaker is allowed.
4. Map each triple to one of the six exact order-three rank permutations and
   count the eight labels.
5. Compute normalized permutation entropy
   `-sum(p*ln(p))/ln(6)` and qualify only at inclusive `<=0.80`.
6. Buy when the sum of the newest twelve monthly returns is above `1e-12`,
   sell below `-1e-12`, and consume flat otherwise. Entropy and momentum
   magnitude never size risk.
7. Open at most one exact-WTI slot-0 position with `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread cap.
8. Close at the next genuine broker month or after forty calendar days. Both
   news axes and Friday close remain off so the monthly hold is preserved.

Exact pre-data enumeration of all `6^8=1,679,616` pattern-label strings
qualifies `782,496`, a `46.5878%` state density or `5.591` theoretical states
per twelve monthly clocks. This is not market evidence or significance.
Receipt:
`artifacts/qm5_wti_mordinal_entropy_tr_threshold_density_20260902.json`.

## Reputable-source findings

- R1 `PASS_WITH_AI_SYNTHESIS_AND_COMPLETE_PEER_REVIEWED_EVIDENCE`: one durable
  AI source, complete official method-paper read, complete governed WTI
  trading-paper read, and explicit no-result boundaries.
- R2 `PASS`: data clock, endpoints, returns, triple membership, ordinal map,
  tie rule, entropy, threshold, side, attempt, fixed risk, stop, spread, and
  exits are deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 history
  and MT5-native state supply every runtime input.
- R4 `PASS`: deterministic native arithmetic only; no ML, trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Non-duplicate decision

The corrected-root checker scanned 4,793 registry identities, 1,422 cards,
and all 45 Strategy Wiki nodes and returned `CLEAN` with no exact or fuzzy
match. Receipt:
`artifacts/qm5_wti_mordinal_entropy_tr_preallocation_dedup_20260902.json`.

Manual semantic review separates the candidate from `QM5_9520`, whose M15
up/down/flat Shannon-entropy crossovers use neither ordinal patterns nor WTI
monthly trend; pure WTI twelve-month momentum, which has no complexity gate;
and WTI sign-run, block-vote, breadth, rank, distribution-shift, scale,
calendar, event, and channel rules. Equal positive/negative counts can produce
different six-pattern histograms, so the state is not a renamed sign filter.

Verdict:
`CLEAN_WTI_MONTHLY_24_RETURN_EIGHT_DISJOINT_ORDER3_PATTERN_NORMALIZED_PERMUTATION_ENTROPY_080_GATED_12M_CONTINUATION`.

## Kill and safety boundary

Q02 retires the unchanged baseline on zero positions, fewer than five
completed positions in any full scored post-warm-up year, nonpositive governed
economics, leakage, formula/fixture mismatch, missing stop, invalid fixed-risk
mode, malformed lifecycle, or nondeterminism. No after-result parameter rescue
is authorized. Direct WTI adds a crude-oil carrier absent from the certified
book, but this is not a decorrelation claim; Q09 alone may evaluate overlap.

Excluded: manual backtests; live/demo/shadow/stress/optimization presets;
terminal control; AutoTrading; `T_Live`; deploy/live manifests; portfolio-gate
changes; portfolio admission; correlation waivers; and any live-use authority.
