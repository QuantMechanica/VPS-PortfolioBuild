# QM5_41253 GBPUSD Weekend Tail Fade - G0 Decision

Date: 2026-08-31

Decision: `APPROVED`

Authority: current explicit OWNER paced-fleet portfolio mission on branch
`agents/board-advisor`, bounded by
`decisions/2026-08-31_gbpusd_weekend_tail_fade_source_approval.md`.

## Identity

- EA ID: `QM5_41253`
- slug: `gbpusd-weekend-tail-fade`
- strategy ID: `AI-CODEX-GBP-WGAP-TAIL-20260831_S01`
- source ID: `AI-CODEX-GBP-WGAP-TAIL-20260831`
- host: exact `GBPUSD.DWX`, D1, slot 0
- intended magic after governed allocation: `412530000`

The identity was reserved atomically by `farmctl reserve-ea-ids`. Magic
allocation remains a separate deterministic step after the EA directory and
approved card-of-record exist.

## Gate findings

### R1 - single governed source: PASS with explicit synthesis boundary

The single source is the durable AI-originated packet
`strategy-seeds/sources/AI-CODEX-GBP-WGAP-TAIL-20260831/source.md`. It binds a
complete-read peer-reviewed institutional postprint at SHA-256
`46AD758FA8341903A4B03203152F8AE05D21B344356467BB3F0B62A1976E8642`.
The paper explicitly studies GBP/USD weekend gaps, empirical tails,
contrarian direction, and weekly holds. The 52-week/10% translation is
disclosed and no source performance or significance is imported.

### R2 - mechanical: PASS

The card locks exact GBPUSD/D1, Monday after Friday, current-gap exclusion,
exactly 52 prior gaps, ascending sort, lower index 5, upper index 46, strict
tail comparisons, contrarian side, one consumed week, fixed risk, frozen ATR
stop, spread cap, framework Friday close, and seven-day stale repair.

### R3 - data: PASS with source-fix proxy risk

Registered `GBPUSD.DWX` D1 history covers 2017-2026 across T1-T10. Native MT5
timestamps, OHLC, ATR, quotes, positions, deals, and terminal state provide
every runtime input. Broker D1 versus Australian-open/US-close timing,
holidays, DST, gaps, financing, and CFD/spot basis remain binding risks.

### R4 - deterministic / ML ban: PASS

The rule uses timestamps, completed/current-bar open and close fields,
logarithms, one bounded finite sort, comparisons, ATR risk control, quotes,
positions, deals, and persistent state. It uses no trained output, banned
signal indicator, external runtime feed, grid, martingale, scale-in, or
pyramid.

## Non-duplicate resolution

The corrected-root canonical receipt
`artifacts/qm5_gbpusd_weekend_tail_fade_preallocation_dedup_20260831.json`
scanned 4,751 registry rows, 1,389 cards, and 45 Strategy Wiki nodes and found
no exact or fuzzy identity.

Manual mechanic review separates the nearest families:

- `QM5_10013` uses a fixed ATR threshold, gap-fill target, and 24-hour/Tuesday
  exit; this card uses a 52-gap empirical distribution and Friday exit.
- `QM5_12494` uses every M1 broker-day boundary and a five-bar hold; this card
  is Monday-only D1 and weekly.
- `QM5_11458` enters from Friday breakout structure before the Monday gap;
  this card enters after observing the gap.
- `QM5_10946` enters long late Friday for weekend continuation; this card is
  post-gap, bidirectional, and contrarian.

Verdict:
`DISTINCT_GBPUSD_WEEKLY_CURRENT_GAP_VERSUS_TRAILING_52_WEEK_EMPIRICAL_TAIL_CONTRARIAN_FRIDAY_EXIT`.

## Build and kill boundary

Build is authorized only from
`strategy-seeds/cards/approved/QM5_41253_gbpusd-weekend-tail-fade_card.md`,
after the slot-0 magic row exists. Q01 must compile strictly and prove
registry, setfile, risk, input-group, bounded-history, and reference-fixture
cleanliness.

Q02 receives one locked `RISK_FIXED=1000` baseline. Retire on zero positions,
fewer than five positions in any full scored post-warm-up year, nonpositive
governed economics, future leakage, malformed Friday/Monday membership,
wrong sample or sort indexes, threshold-tie entry, wrong side, missing stop,
invalid risk mode, malformed lifecycle, or nondeterminism. There is no after-
result parameter rescue.

Approval covers the card, branch-only build, deterministic reference tests,
strict Q01, and one paced Q02 enqueue only while the governed whole-host CPU
ceiling is clear. It does not authorize a manual tester run, portfolio-gate
edit, correlation waiver, portfolio admission, live preset, deploy manifest,
`T_Live`, terminal control, or AutoTrading action.
