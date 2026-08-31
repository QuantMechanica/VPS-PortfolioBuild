# QM5_41254 WTI Scanned Two-Regression Structural-Break Trend - G0 Decision

Date: 2026-08-31

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`, bounded by
`decisions/2026-08-31_wti_chow_break_trend_source_approval.md`.

## Identity

- EA ID: `QM5_41254`
- slug: `wti-chow-break-tr`
- strategy ID: `AI-CODEX-WTI-CHOWBREAK-20260831_S01`
- source ID: `AI-CODEX-WTI-CHOWBREAK-20260831`
- host: exact `XTIUSD.DWX`, D1, slot 0
- intended magic after governed allocation: `412540000`

The identity was reserved in the deterministic EA registry at commit
`bb95450bb5`. Magic allocation remains a separate deterministic step after
the EA directory and approved card-of-record exist.

## Gate findings

### R1 - single governed source: PASS with explicit policy boundary

The single source is the durable AI-originated packet
`strategy-seeds/sources/AI-CODEX-WTI-CHOWBREAK-20260831/source.md`, approved at
commit `08fb72d7bb`. The current OWNER mission is captured as its prompt trail.
The complete governed Moskowitz-Ooi-Pedersen packet supports only WTI,
monthly cadence, and own-return continuation. The Chow bibliographic route is
policy-deferred and supplies no inaccessible content, result, or nominal
significance claim.

### R2 - mechanical: PASS

The card locks 252 completed D1 log prices, pooled intercept/slope OLS, every
two-segment OLS split `63..189`, the exact RSS-improvement score, finite and
degenerate guards, relative negative-improvement tolerance, most-recent exact-
tie selection, inclusive `3.0` activity boundary, selected recent-slope side,
one consumed month, fixed risk, frozen ATR stop, spread cap, next-month
renewal, and forty-day repair.

### R3 - data: PASS with continuous-CFD basis risk

Registered `XTIUSD.DWX` D1 history and native MT5 timestamps, closes, ATR,
quotes, positions, deals, and terminal state supply every runtime input. WTI
futures-to-CFD transport, roll, financing, gaps, and broker-month-label risks
remain binding falsification items.

### R4 - deterministic / ML ban: PASS

The rule uses timestamps, completed closes, logarithms, finite OLS arithmetic,
comparisons, ATR risk control, quotes, positions, deals, and persistent state.
It uses no trained output, banned signal indicator, external runtime feed,
grid, martingale, scale-in, or pyramid.

## Non-duplicate resolution

The corrected-root canonical receipt
`artifacts/qm5_wti_chow_break_tr_preallocation_dedup_20260831.json`, SHA-256
`393FEF0D9514EAFB790722F6E9DCA3C249BF89F99E8AF8A6557970C2C03D19D8`,
scanned 4,753 registry rows, 1,391 cards, and 45 Strategy Wiki nodes. It found
no exact identity and no fuzzy match.

Manual mechanic review separates the candidate from:

- `QM5_20261`, which fits one whole-window OLS trend and gates R-squared;
- `QM5_41245`, which searches a centered CUSUM of monthly return levels;
- `QM5_41249`, which compares two fixed monthly-return means by Welch score;
- `QM5_41252`, which searches a daily squared-return path for a variance
  change; and
- certified `QM5_12567`, a long-only two-day XNG oscillator pullback.

Verdict:
`DISTINCT_WTI_MONTHLY_252_D1_LOG_PRICE_SCANNED_POOLED_VS_TWO_SEGMENT_OLS_RSS_BREAK_POST_SEGMENT_SLOPE_CONTINUATION`.

## Build and kill boundary

Build is authorized only from
`strategy-seeds/cards/approved/QM5_41254_wti-chow-break-tr_card.md`, after the
slot-0 magic row exists. Q01 must compile strictly and prove registry, setfile,
risk, input-group, and deterministic reference-fixture cleanliness.

Q02 receives one locked `RISK_FIXED=1000` baseline. Retire on zero positions,
fewer than five positions in any full post-warm-up year, nonpositive governed
economics, future leakage, wrong OLS/RSS arithmetic, wrong split or tie,
wrong threshold, wrong selected-slope direction, missing stop, invalid risk
mode, malformed lifecycle, or nondeterminism. There is no after-result
parameter rescue.

Approval covers the card, branch-only build, deterministic reference tests,
strict Q01, and one paced Q02 enqueue only while the governed whole-host CPU
ceiling is clear. It does not authorize a manual tester run, portfolio-gate
edit, correlation waiver, portfolio admission, live preset, deploy manifest,
`T_Live`, terminal control, or AutoTrading action.
