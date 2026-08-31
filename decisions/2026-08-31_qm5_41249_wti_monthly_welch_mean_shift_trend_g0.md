# QM5_41249 WTI Monthly Welch Mean-Shift Trend - G0 Decision

Date: 2026-08-31

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`, bounded by
`decisions/2026-08-31_wti_monthly_welch_mean_shift_trend_source_approval.md`.

## Identity

- EA ID: `QM5_41249`
- slug: `wti-mwelch-shift-tr`
- strategy ID: `AI-CODEX-WTI-MWELCH-20260831_S01`
- source ID: `AI-CODEX-WTI-MWELCH-20260831`
- host: exact `XTIUSD.DWX`, D1, slot 0
- intended magic after governed allocation: `412490000`

The identity was reserved atomically by `farmctl reserve-ea-ids` at commit
`4a36345998`. Magic allocation remains a separate deterministic step after
the EA directory and approved card-of-record exist.

## Gate findings

### R1 - single governed source: PASS with explicit synthesis boundary

The single source is the durable AI-originated packet
`strategy-seeds/sources/AI-CODEX-WTI-MWELCH-20260831/source.md`, approved at
commit `de569f5f74`. It preserves complete-read peer-reviewed WTI momentum
evidence, Welch's named peer-reviewed unequal-variance mean-comparison
record, complete public SciPy method documentation and tag-pinned source,
and an explicit boundary around the exact trading synthesis. No inaccessible
source content or source performance is imported.

### R2 - mechanical: PASS

The card locks thirteen consecutive completed month-end closes, twelve
adjacent log returns, fixed older/recent samples of six, arithmetic means,
unbiased within-sample variances, the unequal-variance standard error,
`0.75` score boundary, recent-mean sign alignment, one consumed month, fixed
risk, frozen ATR stop, spread cap, next-month renewal, and forty-day repair.

### R3 - data: PASS with continuous-CFD basis risk

Registered `XTIUSD.DWX` D1 history and native MT5 timestamps, closes, ATR,
quotes, positions, deals, and terminal state supply every runtime input. WTI
futures-to-CFD transport, roll, financing, gap, and broker-month-label risks
remain binding falsification items.

### R4 - deterministic / ML ban: PASS

The rule uses timestamps, completed closes, logarithms, finite sums, means,
variances, square roots, comparisons, ATR risk control, quotes, positions,
deals, and persistent state. It uses no trained output, banned signal
indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Non-duplicate resolution

The corrected-root canonical receipt
`artifacts/qm5_wti_mwelch_shift_tr_preallocation_dedup_20260831.json`,
SHA-256 `418F80E037B15060AA00B11736783446818B7AAA892B49EF9C9F9A95B0777D67`,
scanned 4,748 registry rows, 1,386 cards, and 45 Strategy Wiki nodes. It
returned `CLEAN` with no exact or fuzzy identity.

Manual mechanic review separates the closest structural families:

- `QM5_41176` counts old/new pair wins among monthly price levels; this card
  compares adjacent monthly returns in magnitude units with two variances.
- `QM5_41183` uses a maximum signed ECDF count gap; this card uses no ranks,
  combined sort, or ECDF.
- `QM5_41184` counts pooled sample-label runs; this card has no run state.
- `QM5_41137` compares daily log-price medians in two months; this card uses
  twelve monthly returns split into fixed half-years.
- `QM5_41245` searches eleven return splits and retains a unique centered-
  CUSUM maximum; this card fixes one six/six split and standardizes by two
  within-block variances.
- certified `QM5_12567` is a long-only short-horizon XNG cumulative-RSI
  pullback, not a symmetric monthly direct-WTI return-regime rule.

Verdict:
`CLEAN_WTI_MONTHLY_FIXED_SIX_BY_SIX_WELCH_RETURN_MEAN_SHIFT_ALIGNED_CONTINUATION`.

## Build and kill boundary

Build is authorized only from
`strategy-seeds/cards/approved/QM5_41249_wti-mwelch-shift-tr_card.md`, after
the slot-0 magic row exists. Q01 must compile strictly and prove registry,
setfile, risk, input-group, and reference-fixture cleanliness.

Q02 receives one locked `RISK_FIXED=1000` baseline. Retire on zero positions,
fewer than five positions in any full post-warm-up year, nonpositive governed
economics, future leakage, wrong block membership or return orientation,
wrong variance denominator, degenerate-standard-error entry, wrong boundary
or sign alignment, missing stop, invalid risk mode, malformed lifecycle, or
nondeterminism. There is no after-result parameter rescue.

Approval covers the card, branch-only build, deterministic reference tests,
strict Q01, and one paced Q02 enqueue only while the governed whole-host CPU
ceiling is clear. It does not authorize a manual tester run, portfolio-gate
edit, correlation waiver, portfolio admission, live preset, deploy manifest,
`T_Live`, terminal control, or AutoTrading action.
