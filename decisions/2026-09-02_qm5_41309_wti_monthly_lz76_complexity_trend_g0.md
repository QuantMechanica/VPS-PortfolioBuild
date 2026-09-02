# QM5_41309 WTI Monthly LZ76 Complexity Trend - G0 Decision

Date: 2026-09-02

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`, bounded by
`decisions/2026-09-02_wti_monthly_lz76_complexity_trend_source_approval.md`.

## Identity

- EA ID: `QM5_41309`
- slug: `wti-mlz76-tr`
- strategy ID: `AI-CODEX-WTI-MLZ76-TREND-20260902_S01`
- source ID: `AI-CODEX-WTI-MLZ76-TREND-20260902`
- host: exact `XTIUSD.DWX`, D1, slot 0
- intended magic after governed allocation: `413090000`

The identity was reserved atomically by `farmctl reserve-ea-ids` at commit
`d28df0ea6ad0b2de1c3646d34bc037fa0d0db852`. Magic allocation remains a
separate deterministic step after the EA directory and approved card of record
exist.

## Gate findings

### R1 - single governed source: PASS

The single source is the durable AI-originated packet
`strategy-seeds/sources/AI-CODEX-WTI-MLZ76-TREND-20260902/source.md`, SHA-256
`6C03347BB420026B8B5B7D607A593158BE518C4AB8AF3EC258E345D1143095CD`,
approved at commit `1496422063436b9ae09b9b825761dd52c572d96e`. It preserves a
complete accessible read of the LZ76 finite-sequence definitions, verified
original IEEE provenance, a complete governed read of peer-reviewed WTI
monthly-momentum evidence, and explicit boundaries around the trading
synthesis. No source performance, significance, CFD equivalence, or portfolio
statistic is imported.

### R2 - mechanical: PASS

The card locks twenty-one completed month-end closes, twenty log returns, the
binary sign map and tie rule, the exact LZ76 shortest-new-phrase search prefix,
the final-component exception, phrase reconstruction, raw component bounds,
inclusive `C<=6` gate, newest twelve-month continuation side, one consumed
month, fixed risk, frozen ATR stop, spread cap, next-month renewal, and
forty-day repair.

### R3 - data: PASS with continuous-CFD basis risk

Registered `XTIUSD.DWX` D1 history and native MT5 timestamps, closes, ATR,
quotes, positions, deals, and terminal state supply every runtime input. WTI
futures-to-CFD transport, roll, financing, gaps, and broker-month-label risks
remain binding falsification items.

### R4 - deterministic / ML ban: PASS

The rule uses timestamps, completed closes, logarithms, comparisons, a bounded
binary string, substring equality, integer counts, ATR risk control, quotes,
positions, deals, and persistent state. It uses no trained output, prohibited
runtime feed, random tie breaking, grid, martingale, scale-in, or pyramid.

## Non-duplicate resolution

The corrected-root receipt
`artifacts/qm5_wti_mlz76_tr_preallocation_dedup_20260902.json`, SHA-256
`765F81B5494C0DEFBC3F8A017B743493073A4803AAE4BF6C7AB72A8927058B69`,
scanned 4,794 registry rows, 1,423 cards, and all 45 Strategy Wiki nodes. It
found no exact identity and no fuzzy match above the configured threshold.

Manual semantic review resolves the closest families:

- `QM5_41308` counts six order-three permutations from return magnitudes and
  applies Shannon entropy. This card builds variable-length phrases from one
  binary sign word and computes no histogram or entropy.
- WTI sign-run and Wald-Wolfowitz systems observe adjacent transitions or
  grouped runs, not shortest-new-substring phrase boundaries.
- Sign-count, breadth, majority-vote, block-vote, endpoint, regression, rank,
  distribution-shift, scale, calendar, event, and channel systems cannot
  reconstruct the LZ76 phrase history.
- A fixed pair of twenty-bit words in the card has identical sign and run
  counts but complexity six versus seven, proving that the gate is not a
  renamed sign/run threshold.
- `QM5_12567` is a long-only short-horizon XNG cumulative-RSI pullback, not a
  symmetric monthly direct-WTI structural stream.

Verdict:
`CLEAN_WTI_MONTHLY_20_RETURN_SIGN_LZ76_EXHAUSTIVE_HISTORY_COMPLEXITY_LE6_GATED_12M_CONTINUATION`.

## Build and kill boundary

Build is authorized only from
`strategy-seeds/cards/approved/QM5_41309_wti-mlz76-tr_card.md`, after the
slot-0 magic row exists. Q01 must compile strictly and prove registry, setfile,
risk, input-group, reference-fixture, phrase reconstruction, and boundary
cleanliness.

Q02 receives one locked `RISK_FIXED=1000` baseline. Retire on zero positions,
fewer than five positions in any full scored post-warm-up year, nonpositive
governed economics, future leakage, wrong sign or phrase arithmetic, accepted
tie, complexity boundary error, wrong momentum slice or side, missing stop,
invalid risk mode, malformed lifecycle, or nondeterminism. There is no
after-result parameter rescue.

Approval covers the card, branch-only build, deterministic reference tests,
strict Q01, and one paced Q02 enqueue only while the governed whole-host CPU
ceiling is clear. It does not authorize a manual tester run, portfolio-gate
edit, correlation waiver, portfolio admission, live preset, deploy manifest,
`T_Live`, terminal control, or AutoTrading action.
