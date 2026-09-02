# QM5_41308 WTI Monthly Ordinal-Entropy Trend - G0 Decision

Date: 2026-09-02

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`, bounded by
`decisions/2026-09-02_wti_monthly_ordinal_entropy_trend_source_approval.md`.

## Identity

- EA ID: `QM5_41308`
- slug: `wti-mordinal-entropy-tr`
- strategy ID: `AI-CODEX-WTI-MORDENTROPY-20260902_S01`
- source ID: `AI-CODEX-WTI-MORDENTROPY-20260902`
- host: exact `XTIUSD.DWX`, D1, slot 0
- intended magic after governed allocation: `413080000`

The identity was reserved atomically by `farmctl reserve-ea-ids` at commit
`9c88d167a2`. Magic allocation remains a separate deterministic step after the
EA directory and approved card of record exist.

## Gate findings

### R1 - single governed source: PASS

The single source is the durable AI-originated packet
`strategy-seeds/sources/AI-CODEX-WTI-MORDENTROPY-20260902/source.md`, approved
at commit `c277ed7240`. It preserves a complete official four-page APS read of
Bandt and Pompe's peer-reviewed permutation-entropy method, a complete
governed read of peer-reviewed WTI monthly-momentum evidence, and explicit
boundaries around the trading synthesis. No source performance, significance,
CFD equivalence, or portfolio statistic is imported.

### R2 - mechanical: PASS

The card locks twenty-five completed month-end closes, twenty-four returns,
eight disjoint triples, strict deterministic tie rejection, the six exact
order-three patterns, count and entropy arithmetic, inclusive `0.80` gate,
newest twelve-month continuation side, one consumed month, fixed risk, frozen
ATR stop, spread cap, next-month renewal, and forty-day repair.

### R3 - data: PASS with continuous-CFD basis risk

Registered `XTIUSD.DWX` D1 history and native MT5 timestamps, closes, ATR,
quotes, positions, deals, and terminal state supply every runtime input. WTI
futures-to-CFD transport, roll, financing, gaps, and broker-month-label risks
remain binding falsification items.

### R4 - deterministic / ML ban: PASS

The rule uses timestamps, completed closes, logarithms, comparisons, bounded
integer counts, natural logarithms, ATR risk control, quotes, positions, deals,
and persistent state. It uses no trained output, prohibited signal input,
external runtime feed, random tie breaking, grid, martingale, scale-in, or
pyramid.

## Non-duplicate resolution

The corrected-root receipt
`artifacts/qm5_wti_mordinal_entropy_tr_preallocation_dedup_20260902.json`
scanned 4,793 registry rows, 1,422 cards, and 45 Strategy Wiki nodes. It found
no exact identity and no fuzzy match above the configured threshold.

Manual semantic review resolves the closest families:

- `QM5_9520` trades M15 up/down/flat Shannon-entropy crossover/compression
  events across several symbols. The approved card uses monthly WTI,
  six ordinal patterns from disjoint triples, and entropy solely as a gate.
- `QM5_12603` follows a twelve-month WTI return without the ordinal state.
- WTI sign-run, block-vote, breadth, rank, distribution-shift, scale,
  same-calendar, event, and channel rules cannot reproduce the six-pattern
  histogram from the same sign count.
- `QM5_12567` is a long-only short-horizon XNG cumulative-RSI pullback, not a
  symmetric monthly direct-WTI structural stream.

Verdict:
`CLEAN_WTI_MONTHLY_24_RETURN_EIGHT_DISJOINT_ORDER3_PATTERN_NORMALIZED_PERMUTATION_ENTROPY_080_GATED_12M_CONTINUATION`.

## Build and kill boundary

Build is authorized only from
`strategy-seeds/cards/approved/QM5_41308_wti-mordinal-entropy-tr_card.md`, after
the slot-0 magic row exists. Q01 must compile strictly and prove registry,
setfile, risk, input-group, and deterministic reference-fixture cleanliness.

Q02 receives one locked `RISK_FIXED=1000` baseline. Retire on zero positions,
fewer than five positions in any full scored post-warm-up year, nonpositive
governed economics, future leakage, wrong block membership or return
orientation, accepted tie, wrong order map/count/entropy, boundary error,
missing stop, invalid risk mode, malformed lifecycle, or nondeterminism. There
is no after-result parameter rescue.

Approval covers the card, branch-only build, deterministic reference tests,
strict Q01, and one paced Q02 enqueue only while the governed whole-host CPU
ceiling is clear. It does not authorize a manual tester run, portfolio-gate
edit, correlation waiver, portfolio admission, live preset, deploy manifest,
`T_Live`, terminal control, or AutoTrading action.
