# QM5_41245 WTI Monthly Centered-CUSUM Shift Trend — G0 Decision

Date: 2026-08-31

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`, bounded by
`decisions/2026-08-31_wti_monthly_centered_cusum_shift_trend_source_approval.md`.

## Identity

- EA ID: `QM5_41245`
- slug: `wti-mcusum-shift-tr`
- strategy ID: `AI-CODEX-WTI-MCUSUM-20260831_S01`
- source ID: `AI-CODEX-WTI-MCUSUM-20260831`
- host: exact `XTIUSD.DWX`, D1, slot 0
- intended magic after governed allocation: `412450000`

The identity is already present in
`framework/registry/ea_id_registry.csv`. Magic allocation remains a separate
deterministic step after the EA directory and approved card-of-record exist.

## Gate Findings

### R1 — single governed source: PASS with explicit synthesis boundary

The single source is the durable AI-originated packet
`strategy-seeds/sources/AI-CODEX-WTI-MCUSUM-20260831/source.md`. It preserves
a complete-read peer-reviewed WTI momentum packet, Page's named peer-reviewed
CUSUM bibliographic record, a complete official NIST CUSUM page, and the
access boundary for each. The exact trading conjunction is openly identified
as a pre-result QM synthesis. No inaccessible source content or source
performance is imported.

### R2 — mechanical: PASS

The card locks thirteen consecutive completed month-end closes, twelve
adjacent log returns, full-sample arithmetic centering, all eleven nonterminal
cumulative sums, `1e-12` tie handling, one unique split in `4..8`, post-split
mean direction, one consumed month, fixed risk, frozen ATR stop, spread cap,
next-month renewal, and forty-day stale repair.

### R3 — data: PASS with continuous-CFD basis risk

Registered `XTIUSD.DWX` D1 history and native MT5 timestamps, closes, ATR,
quotes, positions, deals, and terminal state supply every runtime input. WTI
futures-to-CFD transport, roll, financing, gap, and broker-month-label risks
remain binding falsification items.

### R4 — deterministic / ML ban: PASS

The rule uses timestamps, completed closes, logarithms, finite sums, means,
comparisons, ATR risk control, quotes, positions, deals, and persistent state.
It uses no ML, trained output, banned signal indicator, external runtime feed,
grid, martingale, scale-in, or pyramid.

## Non-Duplicate Resolution

`artifacts/qm5_wti_mcusum_shift_tr_preallocation_dedup_20260831.json` scanned
4,744 registry rows, 1,382 cards, and 45 Strategy Wiki nodes against the
corrected vault root. It returned `CLEAN` with no exact or fuzzy identity.

Manual mechanic review separates the closest structural families:

- `QM5_41172` uses ranks of thirteen price levels and the signed Pettitt path;
  this card uses magnitude-bearing monthly returns, arithmetic centering, and
  the post-split return mean for side.
- `QM5_41183` uses one fixed six/six split and a signed maximum ECDF count gap;
  this card searches all eleven return splits and retains one central maximum
  excursion.
- `QM5_41176` counts fixed-block price pair wins; this card has no ranks or
  pair counts.
- `QM5_20261` fits an OLS log-price slope and `R^2`; this card fits no line.
- `QM5_41224` compares exact same-calendar returns across ten years; this card
  uses one contiguous twelve-month path.
- certified `QM5_12567` is a long-only short-horizon XNG cumulative-RSI
  pullback, not a symmetric monthly direct-WTI shift rule.

Verdict:
`CLEAN_WTI_MONTHLY_CENTERED_RETURN_CUSUM_UNIQUE_CENTRAL_SHIFT_POST_MEAN_CONTINUATION`.

## Build And Kill Boundary

Build is authorized only from
`strategy-seeds/cards/approved/QM5_41245_wti-mcusum-shift-tr_card.md`, after
the one-slot magic row exists. Q01 must compile strictly and prove registry,
setfile, risk, input-group, and reference-fixture cleanliness.

Q02 receives one locked `RISK_FIXED=1000` baseline. Retire on zero positions,
fewer than five positions in any full post-warm-up year, nonpositive governed
economics, future leakage, wrong return orientation or centering, omitted
split, tied or edge maximum entry, wrong post-mean side, missing stop, invalid
risk mode, malformed lifecycle, or nondeterminism. There is no after-result
parameter rescue.

Approval covers the card, branch-only build, deterministic reference tests,
strict Q01, and one paced Q02 enqueue only while the governed host CPU ceiling
is clear. It does not authorize a manual tester run, portfolio-gate edit,
correlation waiver, portfolio admission, live preset, deploy manifest,
`T_Live`, terminal control, or AutoTrading action.
