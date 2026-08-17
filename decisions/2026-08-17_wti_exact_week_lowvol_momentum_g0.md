# QM5_21503 XTI Exact-Week Low-Volatility Momentum G0 Authorization

Date: 2026-08-17

Decision: `APPROVED` for G0 research intake, recovery of the reserved unbuilt
identity, deterministic non-live development, strict Q01 validation, and one
paced non-live Q02 enqueue if CPU capacity permits.

Authority: OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`, durably recorded before extraction in
`decisions/2026-08-17_wti_exact_week_lowvol_momentum_source_approval.md` at
commit `398b88395`.

## Approved Identity

- EA: `QM5_21503_xti-weekly-tsmom-lowvol`
- EA ID: `21503`, reserved by the canonical registry on 2026-08-13
- slug: `xti-weekly-tsmom-lowvol`
- normalized strategy ID: `ZHAO-ST-MOMREV-2026_XTI_S02`
- source ID: `28681f5d-aa78-584e-9698-750d1402e485`
- governed card:
  `strategy-seeds/cards/approved/QM5_21503_xti-weekly-tsmom-lowvol_card.md`
- source approval:
  `decisions/2026-08-17_wti_exact_week_lowvol_momentum_source_approval.md`
- carrier: exact `XTIUSD.DWX`, D1, planned slot 0 and magic `215030000`

The card and its execution contract are both `APPROVED` for this non-live
build. This decision does not approve live use, certification, portfolio
admission, or a correlation waiver.

## Locked Hypothesis

At the first executable tick of a genuine broker Monday, reconstruct the
immediately completed exact Monday-through-Friday WTI week and its preceding
Friday anchor. Follow the completed weekly return sign only when the same
week's five-return realized volatility ranks in the lowest fixed tercile of
forty older, non-overlapping five-return blocks:

```text
weekly_return = sum(log(Close_newer / Close_older), five prior-week intervals)
current_rv = sqrt(sum(prior_week_daily_log_return^2))
rank_count = count(older_block_rv <= current_rv), forty disjoint blocks

require exact prior Monday-Friday plus anchor
require weekly-return endpoint reconciliation within 1e-10
require rank_count <= 13

weekly_return > 0 => BUY XTIUSD.DWX
weekly_return < 0 => SELL XTIUSD.DWX
otherwise         => consume week flat
```

All prices are completed before the current Monday. Signal and baseline may
share boundary closes but share no return interval. Persist the Monday
attempt before fallible gates, allow no retry, size one frozen-stop position
from one fixed-dollar budget, and close Friday.

## Source And Claim Boundary

The single bounded source packet is
`strategy-seeds/sources/28681f5d-aa78-584e-9698-750d1402e485/source.md`, covering
Zhao, Ding, Yu, and Kang (2026), "Momentum and Reversal on the Short-Term
Horizon: Evidence from Commodity Markets," SSRN 6425598, DOI
`10.2139/ssrn.6425598`.

The packet and its governed runtime note preserve only accessible metadata and
abstract/methodology material. The source reports positive next-week
prediction from a residual weekly commodity-return component and stronger
short-term momentum under low volatility or uncertainty. Full text was
inaccessible, and no unavailable table, coefficient, parameter, return, or
significance is reconstructed.

The source uses investor-position decomposition. This EA instead tests a
disclosed native-price proxy. The exact calendar, WTI CFD carrier, RV
estimator, block count, tercile boundary, fixed clock, risk, stop, spread, and
lifecycle are QM choices. No source performance, WTI-only efficacy, CFD
equivalence, neutrality, decorrelation, or portfolio result transfers.

## Reputable-Source Gates

- R1 `PASS_WITH_ACCESS_AND_PROXY_RISK`: one durable source ID with named
  authors, title, date, DOI, URL, bounded accessible-material record, exact
  policy-deferred retrieval status, and explicit claim limits.
- R2 `PASS`: completed endpoints, exact weekday identity, return/RV formulas,
  non-overlapping blocks, inclusive rank, direction, attempt state, entry
  grace, risk, stop, spread, and lifecycle are deterministic.
- R3 `PASS_FOR_DISCLOSED_PROXY`: registered native `XTIUSD.DWX` D1 history and
  MT5 execution state supply every runtime input; no position/COT or other
  external signal feed is required.
- R4 `PASS`: fixed native calendar and price arithmetic only, one position on
  one planned registered magic, no trained output, prohibited signal logic,
  grid, martingale, scale-in, or pyramid.

Both deterministic card linters returned `status: ok` for the root and
approved copies. The copies are byte-identical with SHA-256
`FD41EC3723D0D8DCF71FFC89933AD424D9F0C879FAFF40F839588BE35DAF24B7`.

## Non-Duplicate Authorization

The pre-card inventory contained 4,526 registry rows, 622 root-card files,
575 approved-card files, and 3,630 EA directories. Exact review found the
reserved `21503` row but no corresponding card, directory, magic,
setfile, binary, or pipeline work item. Manual family review returned
`CLEAN_RESERVED_UNBUILT_WTI_EXACT_WEEK_LOW_TERCILE_MOMENTUM`:

- `QM5_13049` uses rolling any-day returns, a magnitude threshold,
  overlapping 20-D1 volatility observations, a 55th-percentile cap, and
  reversal/time exits. This card uses exact week identity, no return
  threshold, five-return RV, forty older non-overlapping blocks, a 13-of-40
  inclusive rank boundary, and Friday close.
- `QM5_13101` applies the rolling/magnitude family to XNG, not this WTI rule.
- `QM5_41020` uses only a Tuesday-Friday segment and no volatility state.
- `QM5_41022` requires two within-week segment signs to agree and has no
  volatility state; this card uses the full-week sign.
- `QM5_21521` ranks tick volume and switches between continuation and
  reversal; this card reads no volume and never reverses the weekly sign.
- Existing WTI event, calendar, inventory, roll, carry, breakout, long-horizon
  trend, reversal, and relative-value families use different state objects or
  clocks.
- `QM5_12567` is a long-only XNG cumulative-oscillator pullback, not symmetric
  exact-week WTI continuation.

No failure may be rescued by adding a return threshold, switching to
overlapping volatility windows, widening the tercile, shifting a holiday
week, reversing direction, or extending the hold.

## Build Contract

Development may create exactly:

- `framework/EAs/QM5_21503_xti-weekly-tsmom-lowvol/` from the V5 skeleton;
- one active slot-0 registry row for exact `XTIUSD.DWX` after the EA directory
  exists, with resolver regeneration and survival verification;
- one `RISK_FIXED=1000`, `RISK_PERCENT=0`, D1 backtest setfile;
- deterministic reference tests for calendar identity, endpoint
  reconciliation, non-overlap, RV arithmetic, inclusive rank, direction,
  attempt state, risk, and lifecycle; and
- one strict compile and static Q01 evidence set.

The implementation must preserve both news axes OFF, Friday close ON at
broker hour 21, a frozen `3.0 * ATR(20,D1)` hard stop, a 1,500-point spread
ceiling, the 180-minute entry grace, a `1e-10` reconciliation tolerance, and
the eight-day stale guard.

## Kill And Safety Boundary

Q02 must retire on zero trades, fewer than five completed positions per full
post-warm-up year, nonpositive governed economics, wrong week identity,
current-bar leakage, overlapping signal/baseline return intervals, wrong
inclusive rank, late or repeated Monday entry, direction different from the
completed weekly sign, wrong Friday lifecycle, invalid risk mode, registry
mismatch, or nondeterminism. Q09 alone may establish realized book
correlation.

This authorization excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate edits; portfolio admission; and
correlation waivers. If the tester CPU ceiling is binding, stop before queue
mutation and record the handoff.
