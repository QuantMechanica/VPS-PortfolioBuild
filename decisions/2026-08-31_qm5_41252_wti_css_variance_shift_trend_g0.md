# QM5_41252 WTI Centered-Sum-of-Squares Variance-Shift Trend - G0 Decision

Date: 2026-08-31

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`, bounded by
`decisions/2026-08-31_wti_css_variance_shift_trend_source_approval.md`.

## Identity

- EA ID: `QM5_41252`
- slug: `wti-css-volshift-tr`
- strategy ID: `AI-CODEX-WTI-CSSVOLSHIFT-20260831_S01`
- source ID: `AI-CODEX-WTI-CSSVOLSHIFT-20260831`
- host: exact `XTIUSD.DWX`, D1, slot 0
- intended magic after governed allocation: `412520000`

The identity was reserved in the deterministic EA registry at commit
`baf0e953d5`. Magic allocation remains a separate deterministic step after
the EA directory and approved card-of-record exist.

## Gate findings

### R1 - single governed source: PASS with explicit synthesis boundary

The single source is the durable AI-originated packet
`strategy-seeds/sources/AI-CODEX-WTI-CSSVOLSHIFT-20260831/source.md`, approved
at commit `ccd9946d05`. It preserves a complete read of Inclan and Tiao's
peer-reviewed variance-change paper and the complete governed WTI
time-series-momentum record. No source performance, significance, CFD
equivalence, or portfolio statistic is imported.

### R2 - mechanical: PASS

The card locks 253 completed D1 closes, 252 adjacent log returns, full-window
mean centering, squared centered returns, the centered cumulative-sum path,
interior splits `21..231`, `sqrt(252/2)` normalization, most-recent exact-tie
selection, inclusive `0.63` activity boundary, post-shift raw-return sign,
one consumed month, fixed risk, frozen ATR stop, spread cap, next-month
renewal, and forty-day repair.

### R3 - data: PASS with continuous-CFD basis risk

Registered `XTIUSD.DWX` D1 history and native MT5 timestamps, closes, ATR,
quotes, positions, deals, and terminal state supply every runtime input. WTI
futures-to-CFD transport, roll, financing, gaps, and broker-month-label risks
remain binding falsification items.

### R4 - deterministic / ML ban: PASS

The rule uses timestamps, completed closes, logarithms, finite arithmetic,
squares, cumulative sums, comparisons, ATR risk control, quotes, positions,
deals, and persistent state. It uses no trained output, banned signal
indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Non-duplicate resolution

The corrected-root canonical receipt
`artifacts/qm5_wti_css_volshift_tr_preallocation_dedup_20260831.json`,
SHA-256 `01CE89DC5CF0DCDA910AF86E00BAECB1BA3816504B3F9EA3F66E2DB80DB3FFD7`,
scanned 4,751 registry rows, 1,389 cards, and 45 Strategy Wiki nodes. It found
no exact identity and no fuzzy match.

Manual mechanic review separates the candidate from the closest families:

- `QM5_41245` accumulates centered monthly return levels and searches a mean
  shift. This card accumulates squared centered daily returns and estimates a
  variance shift, then obtains direction from a separate post-shift raw
  return.
- `QM5_41250` compares two fixed monthly blocks through exact permutations of
  MAD. This card retains 252-return time order, searches an interior break
  location, and performs no permutation.
- `QM5_20298` ranks monthly volatility-of-volatility. This card uses the
  source-defined centered CSS path and no volatility rank.
- certified `QM5_12567` is a long-only two-day XNG cumulative-RSI pullback,
  not a symmetric monthly direct-WTI structural-break trend.

Verdict:
`DISTINCT_WTI_MONTHLY_252_D1_CENTERED_CUMULATIVE_SQUARES_DOMINANT_INTERIOR_VARIANCE_SHIFT_POST_BREAK_RETURN_CONTINUATION`.

## Build and kill boundary

Build is authorized only from
`strategy-seeds/cards/approved/QM5_41252_wti-css-volshift-tr_card.md`, after
the slot-0 magic row exists. Q01 must compile strictly and prove registry,
setfile, risk, input-group, and reference-fixture cleanliness.

Q02 receives one locked `RISK_FIXED=1000` baseline. Retire on zero positions,
fewer than five positions in any full post-warm-up year, nonpositive governed
economics, future leakage, wrong centering/squared path, wrong split or tie
selection, wrong score boundary, wrong post-shift direction, missing stop,
invalid risk mode, malformed lifecycle, or nondeterminism. There is no after-
result parameter rescue.

Approval covers the card, branch-only build, deterministic reference tests,
strict Q01, and one paced Q02 enqueue only while the governed whole-host CPU
ceiling is clear. It does not authorize a manual tester run, portfolio-gate
edit, correlation waiver, portfolio admission, live preset, deploy manifest,
`T_Live`, terminal control, or AutoTrading action.
