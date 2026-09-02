# WTI Monthly LZ76 Complexity Trend - Source Approval

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

- proposed slug: `wti-mlz76-tr`
- proposed strategy ID: `AI-CODEX-WTI-MLZ76-TREND-20260902_S01`
- source ID: `AI-CODEX-WTI-MLZ76-TREND-20260902`
- host / slot 0: exact `XTIUSD.DWX`, D1
- clock: first executable D1 tick after a genuine broker-month transition
- signal: LZ76 unique exhaustive-history component count of twenty completed
  monthly WTI return signs, inclusive raw complexity ceiling six, then newest
  twelve-month return-sign continuation
- lifecycle: one consumed monthly attempt, one fixed-risk position, frozen
  ATR stop, next-month renewal, and forty-calendar-day stale repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts one.

## Single governed source and evidence boundary

The single R1 lineage is the AI-originated packet
`strategy-seeds/sources/AI-CODEX-WTI-MLZ76-TREND-20260902/source.md`.
`processes/qb_reputable_source_criteria.md` permits AI-originated strategies
when the origin, claim boundary, and source ID are durable.

Supporting evidence is bounded to:

- a complete read of Szczepanski's four-section manuscript, later published
  in peer-reviewed *Information Sciences* 179(9), DOI
  `10.1016/j.ins.2008.12.019`, which restates the unique LZ76 exhaustive
  history, component-count complexity, and finite-sequence distribution;
- verified bibliographic provenance for Lempel and Ziv (1976), *IEEE
  Transactions on Information Theory* 22(1), DOI
  `10.1109/TIT.1976.1055501`, without claiming inaccessible pages were read;
  and
- the complete governed read of Moskowitz, Ooi, and Pedersen (2012), "Time
  Series Momentum," *Journal of Financial Economics* 104(2), DOI
  `10.1016/j.jfineco.2011.11.003`, including explicit NYMEX WTI membership
  and monthly own-return continuation.

The method evidence supplies finite-word parsing only. The trading paper
supplies carrier and continuation direction only. The twenty-bit window,
binary return map, `C<=6` gate, conjunction, CFD mapping, risk, stop, spread,
and lifecycle are disclosed pre-result QM choices. Retrieval evidence is
`strategy-seeds/sources/AI-CODEX-WTI-MLZ76-TREND-20260902/retrieval_route_20260902.json`.

## Locked mechanic

At the first executable D1 tick of each genuine broker month:

1. Persist the normalized month key before every fallible gate and never retry
   the same month.
2. Reconstruct twenty-one consecutive completed WTI month-end closes and form
   twenty adjacent chronological log returns.
3. Encode each return as one above `+1e-12` or zero below `-1e-12`; consume an
   inclusive tie flat and never jitter it.
4. Build the unique LZ76 exhaustive history by choosing at each start the
   shortest phrase absent from the prefix ending just before that phrase's
   terminal bit. Permit only the final phrase to be non-exhaustive.
5. Require exact twenty-bit phrase reconstruction and raw component count
   `2..9`; qualify only at inclusive `C<=6`. No normalizer, compression
   library, dictionary variant, LZ77/LZ78 rule, or entropy substitution is
   allowed.
6. Buy when the sum of the newest twelve monthly returns is above `1e-12`,
   sell below `-1e-12`, and consume flat otherwise. Complexity and momentum
   magnitude never size risk.
7. Open at most one exact-WTI slot-0 position with `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread cap.
8. Close at the next genuine broker month or after forty calendar days. Both
   news axes and Friday close remain off for the full-month native-price hold.

Exact pre-data enumeration of all `2^20=1,048,576` binary words qualifies
`590,076` at `C<=6`, a `56.2740%` word density or `6.7529` theoretical states
per twelve monthly clocks. This is not market evidence or significance.
Receipt: `artifacts/qm5_wti_mlz76_tr_threshold_density_20260902.json`.

## Reputable-source findings

- R1 `PASS_WITH_AI_SYNTHESIS_AND_COMPLETE_METHOD_AND_TRADING_READ`: one
  durable AI source, complete accessible method manuscript, original IEEE
  provenance, complete governed WTI trading-paper read, and explicit no-result
  boundaries.
- R2 `PASS`: data clock, endpoints, returns, binary map, tie rule, phrase
  boundary/search prefix, last-component exception, complexity gate, side,
  attempt, fixed risk, stop, spread, and exits are deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1
  history and native MT5 state supply every runtime input.
- R4 `PASS`: deterministic native arithmetic and bounded string comparison
  only; no ML, trained output, banned signal input, external runtime feed,
  random tie breaking, grid, martingale, scale-in, or pyramid.

## Non-duplicate decision

The corrected-root checker scanned 4,794 registry identities, 1,423 cards,
and all 45 Strategy Wiki nodes and returned `CLEAN` with no exact or fuzzy
match. Receipt:
`artifacts/qm5_wti_mlz76_tr_preallocation_dedup_20260902.json`.

Manual semantic review separates the candidate from `QM5_41308`, which uses
return-magnitude ordinal triples and a six-state Shannon entropy rather than a
binary variable-length phrase history; WTI sign-run/Wald-Wolfowitz systems,
which observe transitions or grouped runs rather than phrase novelty; and
sign-count, vote, block, endpoint, regression, rank, distribution, scale,
calendar, event, and channel systems. Words with identical sign and run counts
can have different LZ76 complexity, including a fixed `C=6`/`C=7` boundary
pair preserved in the source packet.

Verdict:
`CLEAN_WTI_MONTHLY_20_RETURN_SIGN_LZ76_EXHAUSTIVE_HISTORY_COMPLEXITY_LE6_GATED_12M_CONTINUATION`.

## Kill and safety boundary

Q02 retires the unchanged baseline on zero positions, fewer than five
completed positions in any full scored post-warm-up year, nonpositive governed
economics, leakage, sign/phrase/fixture mismatch, missing stop, invalid fixed
risk, malformed lifecycle, or nondeterminism. No after-result parameter rescue
is authorized. Direct WTI adds a crude-oil carrier absent from the certified
book, but this is not a decorrelation claim; Q09 alone may evaluate overlap.

Excluded: manual backtests; live/demo/shadow/stress/optimization presets;
terminal control; AutoTrading; `T_Live`; deploy/live manifests; portfolio
admission; portfolio-gate changes; correlation waivers; and live-use authority.
