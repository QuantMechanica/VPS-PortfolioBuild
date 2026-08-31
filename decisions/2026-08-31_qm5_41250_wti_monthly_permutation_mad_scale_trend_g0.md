# QM5_41250 WTI Monthly Exact-Permutation Robust Scale Trend - G0 Decision

Date: 2026-08-31

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`, bounded by
`decisions/2026-08-31_wti_monthly_permutation_mad_scale_trend_source_approval.md`.

## Identity

- EA ID: `QM5_41250`
- slug: `wti-mperm-scale-tr`
- strategy ID: `AI-CODEX-WTI-MPERMSCALE-20260831_S01`
- source ID: `AI-CODEX-WTI-MPERMSCALE-20260831`
- host: exact `XTIUSD.DWX`, D1, slot 0
- intended magic after governed allocation: `412500000`

The identity was reserved atomically by `farmctl reserve-ea-ids` at commit
`69814733e5`. Magic allocation remains a separate deterministic step after
the EA directory and approved card-of-record exist.

## Gate findings

### R1 - single governed source: PASS with explicit synthesis boundary

The single source is the durable AI-originated packet
`strategy-seeds/sources/AI-CODEX-WTI-MPERMSCALE-20260831/source.md`, approved
at commit `45721646e9`. It preserves complete-read peer-reviewed WTI monthly
momentum evidence and the exact pre-result permutation-MAD trading
translation. No source performance, significance, CFD equivalence, or
portfolio statistic is imported.

### R2 - mechanical: PASS

The card locks thirteen consecutive completed month-end closes, twelve
adjacent log returns, fixed older/recent samples of six, exact median and MAD
definitions, all 924 six/six label assignments, the inclusive upper-tail
comparison with `1e-14` tolerance, tail cap `416`, recent-mean direction, one
consumed month, fixed risk, frozen ATR stop, spread cap, next-month renewal,
and forty-day repair.

### R3 - data: PASS with continuous-CFD basis risk

Registered `XTIUSD.DWX` D1 history and native MT5 timestamps, closes, ATR,
quotes, positions, deals, and terminal state supply every runtime input. WTI
futures-to-CFD transport, roll, financing, gap, and broker-month-label risks
remain binding falsification items.

### R4 - deterministic / ML ban: PASS

The rule uses timestamps, completed closes, logarithms, finite sorts,
medians, absolute deviations, deterministic enumeration, comparisons, ATR
risk control, quotes, positions, deals, and persistent state. It uses no
trained output, banned signal indicator, external runtime feed, grid,
martingale, scale-in, or pyramid.

## Non-duplicate resolution

The corrected-root canonical receipt
`artifacts/qm5_wti_mperm_scale_tr_preallocation_dedup_20260831.json`,
SHA-256 `133C36BA2F3B6CA20F658794A67CAD7A5277B8A454903A3C52F1D545D7928D4D`,
scanned 4,749 registry rows, 1,387 cards, and 45 Strategy Wiki nodes. It found
no exact identity and one expected fuzzy neighbor, `QM5_41249`, at score
`0.53`.

Manual mechanic review separates the candidate from the closest families:

- `QM5_41249` standardizes an old/recent arithmetic-mean difference with two
  sample variances. This card qualifies on a robust MAD scale expansion and
  its exact 924-assignment label distribution; mean difference does not
  qualify the setup.
- `QM5_20298` compares two 252-sample distributions of rolling 20-day
  realized volatility-of-volatility and trades a low-minus-high premium.
  This card uses only twelve monthly returns and follows a recent robust
  scale expansion.
- `QM5_41108` compares two completed monthly OHLC high-low widths and follows
  the latest candle body. This card uses no monthly high, low, open, or body.
- `QM5_20288` normalizes twelve individual monthly returns by their separate
  within-month daily L2 paths. This card does not normalize returns.
- certified `QM5_12567` is a long-only two-day XNG cumulative-RSI pullback,
  not a symmetric monthly direct-WTI scale-regime continuation rule.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_EXACT_924_LABEL_PERMUTATION_ROBUST_SCALE_EXPANSION_RECENT_MEAN_CONTINUATION`.

## Build and kill boundary

Build is authorized only from
`strategy-seeds/cards/approved/QM5_41250_wti-mperm-scale-tr_card.md`, after
the slot-0 magic row exists. Q01 must compile strictly and prove registry,
setfile, risk, input-group, and reference-fixture cleanliness.

Q02 receives one locked `RISK_FIXED=1000` baseline. Retire on zero positions,
fewer than five positions in any full post-warm-up year, nonpositive governed
economics, future leakage, wrong block membership or return orientation,
wrong even-sample median or MAD, missing/duplicate label assignments, wrong
inclusive comparison, wrong `416` cap, wrong recent-mean direction, missing
stop, invalid risk mode, malformed lifecycle, or nondeterminism. There is no
after-result parameter rescue.

Approval covers the card, branch-only build, deterministic reference tests,
strict Q01, and one paced Q02 enqueue only while the governed whole-host CPU
ceiling is clear. It does not authorize a manual tester run, portfolio-gate
edit, correlation waiver, portfolio admission, live preset, deploy manifest,
`T_Live`, terminal control, or AutoTrading action.
