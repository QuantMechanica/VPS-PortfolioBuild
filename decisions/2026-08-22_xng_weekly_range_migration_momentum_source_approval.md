# XNG weekly auction-range migration momentum source approval

Date: 2026-08-22

Decision: `APPROVED_SOURCE`

## Authority and bounded scope

The current explicit OWNER instruction delivered to Codex on branch
`agents/board-advisor` authorizes one new structural, low-frequency
commodity/energy edge outside the certified XAU/SP500/NDX/XNG book. It
explicitly permits a second `XNGUSD` edge when its logic differs from
`QM5_12567`, requires a reputable-source record, one QM card and build,
`RISK_FIXED` backtest configuration, and one paced Q02 enqueue, and forbids
`T_Live`, AutoTrading, portfolio-gate, and `T_Live`-manifest changes.

This decision approves source intake for one bounded candidate:

- planned source ID: `MOP-XNG-WRANGE-MIGRATE-MOM-2026`;
- planned strategy ID: `MOP-XNG-WRANGE-MIGRATE-MOM-2026_S01`;
- planned slug: `xng-wrange-migrate-mom`;
- carrier and clock: exact `XNGUSD.DWX`, D1, evaluated once at the first
  tradable bar of a new normalized Monday-anchored broker week; and
- primary governed source record to read completely before extraction:
  `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, current SHA-256
  `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

The parent record covers Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje
Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. Its governed receipt
records an end-to-end read of the published paper and a durable PDF hash, and
natural-gas futures are an explicit member of the source universe.

This is source approval only. It does not approve a Strategy Card, allocate
an EA ID or magic, authorize a build or live use, establish efficacy or
decorrelation, or waive any deterministic Q gate.

## Candidate mechanic authorized for extraction

Aggregate the two immediately preceding consecutive completed XNG broker
weeks from native D1 OHLC. Each completed week must contain three to five
unique sessions, the current decision week must be excluded, and one uniform
raw or `+1`-day energy-label convention must apply to current and historical
bars.

- BUY only when the newest completed week has both a strict higher high and a
  strict higher low than its parent week.
- SELL only when it has both a strict lower high and a strict lower low.
- Mixed, equal, overlapping, malformed, incomplete, or nonconsecutive states
  remain flat.

The intended baseline follows this completed weekly auction-range migration
for exactly one broker week, with one durable attempt, one fixed-risk
position, a frozen completed-bar ATR hard stop, no target, and no external
runtime data. Source extraction and Q00 must lock the exact label, session,
risk, lifecycle, and falsification contracts before build.

## Preliminary non-duplicate boundary

The canonical fail-closed pre-allocation checker scanned 4,590 EA-registry
identities, 1,269 repository cards, and 45 Strategy-Wiki nodes. It returned
no exact slug or strategy-ID collision and the expected fuzzy match to
`QM5_41089_wti-wrange-migrate-mom`. The machine-readable receipt is
`artifacts/qm5_xng_wrange_migrate_mom_preallocation_dedup_20260822.json`.

Manual semantic review classifies the WTI hit as a separately falsifiable
carrier sibling rather than an in-place revision. The current OWNER mission
explicitly permits another XNG edge when its logic differs from `QM5_12567`,
and the registry precedent `QM5_41080`/`QM5_41081` assigns separate identities
to predeclared WTI and XNG carriers of one completed-week mechanic. No WTI
result transfers; XNG history, cost, density, basis, and portfolio overlap
must be falsified independently.

The load-bearing distinctions from existing XNG work are:

- certified `QM5_12567_cum-rsi2-commodity` is a long-only, two-day cumulative-
  RSI2 pullback under a slow trend filter. This candidate is symmetric,
  oscillator-free, compares two complete weekly high-low packages, and holds
  to the next weekly boundary;
- `QM5_41081_xng-wclose-location-mom` follows a parent-to-newest close return
  only when the newest close lies in the matching edge of its own range. This
  candidate never reads a close and uses only strict migration of both weekly
  range endpoints;
- `QM5_41094_xng-wbody-dominance-mom` uses one completed week's open-close
  body share. This candidate reads neither weekly open nor close and requires
  two consecutive high-low packages;
- `QM5_41063_xng-week-nr7-brk` ranks seven ranges and waits for a current-week
  breakout. This candidate ranks nothing and excludes every current-week
  price from the signal; and
- `QM5_41089_wti-wrange-migrate-mom` is the exact WTI carrier sibling. It is
  the expected fuzzy match and creates no XNG performance prior.

The exact XNG carrier, two consecutive completed Monday-anchored weekly OHLC
packages, three-to-five sessions each, strict `HH+HL` long / `LH+LL` short
state, every equality/inside/outside/mixed state flat, boundary entry, durable
attempt, fixed risk, and next-week exit are jointly load-bearing. Q00 still
owes a post-allocation identity scan; any second XNG implementation found
before approval stops the build.

## Source and claim boundary

Moskowitz, Ooi, and Pedersen are approved only as lineage for the proposition
that an asset's own past price direction can contain continuation information;
the governed record identifies natural gas in the paper's commodity universe.
The authors do not test a weekly XNG higher-high/higher-low or lower-high/
lower-low state, a Darwinex continuous CFD, fixed cash risk, an ATR stop, or a
one-week hold. Those are transparent QM hypotheses, not source claims.

No source return, natural-gas-specific alpha, profit factor, drawdown, trade
count, cost, CFD equivalence, neutrality, or portfolio-correlation statistic
may transfer to the card. Q02 owns frequency and baseline economics. Q09 alone
may establish realized portfolio correlation.

## Reputable-source criteria

- R1 `PASS_WITH_WEEKLY_RANGE_STATE_TRANSLATION_RISK`: the planned bounded
  child source traces to named authors, a peer-reviewed JFE paper, DOI,
  complete-paper evidence, durable retrieval hash, and explicit natural-gas
  membership; the weekly range-state proxy is disclosed as untested.
- R2 `PASS`: the extraction must fix the clock, label normalization, week
  anchors, session counts, OHLC aggregation, strict endpoint comparisons,
  side, attempt, risk, spread, stop, and lifecycle.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XNGUSD.DWX` D1 history and MT5 state provide every planned runtime input.
  Q02 owns label, history, density, fill, cost, and CFD-basis sufficiency.
- R4 `PASS`: timestamps, completed OHLC, comparisons, ATR, quotes, positions,
  deals, and terminal state only; no banned indicator, trained output,
  external feed, adaptive fit, grid, martingale, scale-in, or pyramid.

## Falsification and safety boundary

Expected cadence is approximately twelve to twenty-four completed positions
per full post-warm-up year. Q02 must retire a full scored year below five
trades, zero trades, nonpositive governed economics, or any label, anchor,
session, OHLC, strict-range-state, direction, attempt, risk, lifecycle, or
determinism defect. A weak result may not be rescued by accepting equality or
mixed states, changing week membership or direction, adding current-week
confirmation, changing the hold, or adding a return, close-location,
volatility, volume, calendar, moving-average, oscillator, event, inventory,
or external-data filter.

This approval authorizes only complete reading of the bounded governed source,
creation of one child source packet, and subsequent Q00 consideration. It does
not authorize a manual backtest, terminal control, live/demo/shadow/stress/
optimization preset, AutoTrading, `T_Live`, deploy or `T_Live` manifest,
portfolio-gate change, portfolio admission, correlation waiver, after-result
salvage, or a duplicate queue row.
