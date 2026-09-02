# QM5_41284 WTI Monthly Fligner-Policello Shift Trend - G0 Decision

Date: 2026-09-02

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`, bounded by
`decisions/2026-09-02_wti_monthly_fligner_policello_shift_trend_source_approval.md`.

## Identity

- EA ID: `QM5_41284`
- slug: `wti-mfp-shift-tr`
- strategy ID: `AI-CODEX-WTI-MFP-SHIFT-20260902_S01`
- source ID: `AI-CODEX-WTI-MFP-SHIFT-20260902`
- host: exact `XTIUSD.DWX`, D1, slot 0
- intended magic after governed allocation: `412840000`

The identity was reserved atomically by `farmctl reserve-ea-ids` at commit
`e5c8f5c8db`. Magic allocation remains a separate deterministic step after the
EA directory and approved card-of-record exist.

## Gate findings

### R1 - single governed source: PASS with explicit synthesis boundary

The single source is the durable AI-originated packet
`strategy-seeds/sources/AI-CODEX-WTI-MFP-SHIFT-20260902/source.md`, approved at
commit `3df48ffd73`. It preserves a complete governed read of peer-reviewed WTI
monthly-momentum evidence, original peer-reviewed method metadata and
abstract, a complete pinned CRAN method implementation, and an explicit
boundary around the exact trading synthesis. The method paper body is not
represented as read. No source performance, significance, CFD equivalence,
or portfolio statistic is imported.

### R2 - mechanical: PASS

The card locks twenty-one consecutive completed month-end closes, twenty
adjacent log returns, fixed ten/ten samples, exact half-credit cross-block
ties, the Fligner-Policello pair-placement score, finite complete-separation
handling, inclusive `0.600` boundaries, one consumed month, fixed risk, frozen
ATR stop, spread cap, next-month renewal, and forty-day repair.

### R3 - data: PASS with continuous-CFD basis risk

Registered `XTIUSD.DWX` D1 history and native MT5 timestamps, closes, ATR,
quotes, positions, deals, and terminal state supply every runtime input. WTI
futures-to-CFD transport, roll, financing, gaps, and broker-month-label risks
remain binding falsification items.

### R4 - deterministic / ML ban: PASS

The rule uses timestamps, completed closes, logarithms, comparisons, sums,
squares, square roots, ATR risk control, quotes, positions, deals, and
persistent state. It uses no trained output, prohibited signal input, external
runtime feed, grid, martingale, scale-in, or pyramid.

## Non-duplicate resolution

The corrected-root receipt
`artifacts/qm5_wti_mfp_shift_tr_preallocation_dedup_20260902.json` scanned
4,783 registry rows, 1,419 cards, and 45 Strategy Wiki nodes. It found no exact
identity and surfaced two fuzzy neighbors.

Manual formula review resolves them and the closest structural families:

- `QM5_41183` is a maximum signed ECDF gap over two six-price blocks; this
  card averages all pair placements over two ten-return blocks and estimates
  unequal-shape placement dispersion.
- `QM5_41251` uses pooled/within midranks and corrected Brunner-Munzel
  studentization; this card uses Fligner-Policello `p_i/q_j` deviations plus
  `p_bar*q_bar`. A fixed distinct-rank vector qualifies here while remaining
  flat under that neighbor's locked boundary.
- `QM5_41176` thresholds one unstudentized Mann-Whitney total; two fixed
  allocations with the same total lie on opposite sides of this card's
  placement-dispersion boundary.
- `QM5_41249` uses raw means and variances, while this card is pooled-rank
  invariant.
- Certified `QM5_12567` is a long-only two-day XNG oscillator pullback, not a
  symmetric monthly direct-WTI rank trend.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_TEN_BY_TEN_FLIGNER_POLICELLO_UNEQUAL_SHAPE_RANK_LOCATION_CONTINUATION`.

## Build and kill boundary

Build is authorized only from
`strategy-seeds/cards/approved/QM5_41284_wti-mfp-shift-tr_card.md`, after the
slot-0 magic row exists. Q01 must compile strictly and prove registry,
setfile, risk, input-group, and deterministic reference-fixture cleanliness.

Q02 receives one locked `RISK_FIXED=1000` baseline. Retire on zero positions,
fewer than five positions in any full scored post-warm-up year, nonpositive
governed economics, future leakage, wrong block membership or return
orientation, wrong placement dispersion, wrong complete-separation behavior,
boundary error, missing stop, invalid risk mode, malformed lifecycle, or
nondeterminism. There is no after-result parameter rescue.

Approval covers the card, branch-only build, deterministic reference tests,
strict Q01, and one paced Q02 enqueue only while the governed whole-host CPU
ceiling is clear. It does not authorize a manual tester run, portfolio-gate
edit, correlation waiver, portfolio admission, live preset, deploy manifest,
`T_Live`, terminal control, or AutoTrading action.
