# QM5_41251 WTI Monthly Brunner-Munzel Shift Trend - G0 Decision

Date: 2026-08-31

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`, bounded by
`decisions/2026-08-31_wti_monthly_brunner_munzel_shift_trend_source_approval.md`.

## Identity

- EA ID: `QM5_41251`
- slug: `wti-mbrunner-shift-tr`
- strategy ID: `AI-CODEX-WTI-MBRUNNER-20260831_S01`
- source ID: `AI-CODEX-WTI-MBRUNNER-20260831`
- host: exact `XTIUSD.DWX`, D1, slot 0
- intended magic after governed allocation: `412510000`

The identity was reserved atomically by `farmctl reserve-ea-ids` at commit
`592f0c2bb8`. Magic allocation remains a separate deterministic step after
the EA directory and approved card-of-record exist.

## Gate findings

### R1 - single governed source: PASS with explicit synthesis boundary

The single source is the durable AI-originated packet
`strategy-seeds/sources/AI-CODEX-WTI-MBRUNNER-20260831/source.md`, approved at
commit `7fa33b6ea0`. It preserves complete-read peer-reviewed WTI monthly
momentum evidence, peer-reviewed Brunner-Munzel method metadata, the official
CRAN manual, a complete pinned corrected implementation, and an explicit
boundary around the exact trading synthesis. No source performance,
significance, CFD equivalence, or portfolio statistic is imported.

### R2 - mechanical: PASS

The card locks twenty-one consecutive completed month-end closes, twenty
adjacent log returns, fixed old/recent samples of ten, exact average ranks for
ties, combined and within ranks, separate placement variances, the corrected
studentized score, finite complete-separation handling, inclusive `0.625`
boundaries, one consumed month, fixed risk, frozen ATR stop, spread cap,
next-month renewal, and forty-day repair.

### R3 - data: PASS with continuous-CFD basis risk

Registered `XTIUSD.DWX` D1 history and native MT5 timestamps, closes, ATR,
quotes, positions, deals, and terminal state supply every runtime input. WTI
futures-to-CFD transport, roll, financing, gaps, and broker-month-label risks
remain binding falsification items.

### R4 - deterministic / ML ban: PASS

The rule uses timestamps, completed closes, logarithms, finite ranks, sums,
squares, square roots, comparisons, ATR risk control, quotes, positions,
deals, and persistent state. It uses no trained output, banned signal
indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Non-duplicate resolution

The corrected-root canonical receipt
`artifacts/qm5_wti_mbrunner_shift_tr_preallocation_dedup_20260831.json`
scanned 4,750 registry rows, 1,388 cards, and 45 Strategy Wiki nodes. It found
no exact identity and fuzzy neighbors `QM5_41249` and `QM5_41250`.

Manual mechanic review separates the closest structural families:

- `QM5_41249` uses raw means and raw sample variances; this card uses only
  pooled and within midranks plus rank-placement variances.
- `QM5_41250` qualifies robust scale expansion using 924 runtime label
  assignments; this card qualifies a studentized stochastic-order location
  effect and performs no runtime enumeration.
- `QM5_41176` thresholds an unstudentized Mann-Whitney pair count; this card
  separately estimates rank-placement variance and can distinguish equal-U
  allocations.
- `QM5_41183` takes a maximum empirical-CDF gap; this card uses an average
  relative effect with studentization.
- `QM5_41172` searches candidate change points; this card fixes one ten/ten
  chronological split.
- certified `QM5_12567` is a long-only short-horizon XNG oscillator pullback,
  not a symmetric monthly direct-WTI rank trend.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_TEN_BY_TEN_BRUNNER_MUNZEL_STUDENTIZED_RANK_PLACEMENT_STOCHASTIC_DOMINANCE_CONTINUATION`.

## Build and kill boundary

Build is authorized only from
`strategy-seeds/cards/approved/QM5_41251_wti-mbrunner-shift-tr_card.md`, after
the slot-0 magic row exists. Q01 must compile strictly and prove registry,
setfile, risk, input-group, and reference-fixture cleanliness.

Q02 receives one locked `RISK_FIXED=1000` baseline. Retire on zero positions,
fewer than five positions in any full post-warm-up year, nonpositive governed
economics, future leakage, wrong block membership or return orientation,
wrong rank or placement variance, wrong degenerate-denominator behavior,
boundary error, missing stop, invalid risk mode, malformed lifecycle, or
nondeterminism. There is no after-result parameter rescue.

Approval covers the card, branch-only build, deterministic reference tests,
strict Q01, and one paced Q02 enqueue only while the governed whole-host CPU
ceiling is clear. It does not authorize a manual tester run, portfolio-gate
edit, correlation waiver, portfolio admission, live preset, deploy manifest,
`T_Live`, terminal control, or AutoTrading action.
