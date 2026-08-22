# WTI monthly auction-range migration momentum source approval

Date: 2026-08-22

Decision: `APPROVED_SOURCE`

## Authority and bounded scope

The current explicit OWNER instruction delivered to Codex on branch
`agents/board-advisor` authorizes one new structural, low-frequency
commodity/energy edge outside the certified XAU/SP500/NDX/XNG book. It calls
for a genuinely different commodity exposure, one reputable-source QM card
and V5 build, `RISK_FIXED` backtest configuration, and one paced Q02 enqueue,
while forbidding `T_Live`, AutoTrading, portfolio-gate, and `T_Live`-manifest
changes.

This decision approves source intake for one bounded direct-WTI candidate:

- planned source ID: `MOP-WTI-MRANGE-MIGRATE-MOM-2026`;
- planned strategy ID: `MOP-WTI-MRANGE-MIGRATE-MOM-2026_S01`;
- planned slug: `wti-mrange-migrate-mom`;
- carrier and clock: exact `XTIUSD.DWX`, D1, evaluated once at the first
  tradable normalized D1 bar of a new broker-calendar month; and
- primary governed source record read completely before extraction:
  `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
  `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

The parent record covers Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje
Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. Its governed receipt
records an end-to-end read of the published 23-page paper, the author-faculty
retrieval route, and PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
WTI crude is an explicit member of the source commodity-futures universe.

This is source approval only. It does not approve a Strategy Card, allocate
an EA ID or magic, authorize a build or live use, establish efficacy or
decorrelation, or waive any deterministic Q gate.

## Candidate mechanic authorized for extraction

Aggregate the immediately completed `XTIUSD.DWX` broker-calendar month and
its consecutive parent month from native completed D1 high/low bars. Each
month must contain 17 through 23 unique, strictly ordered sessions, the
current decision month must be excluded, and one uniform raw or `+1`-day
energy-label convention must apply to the current and every historical bar.

- BUY only when the newest completed month has both a strict higher high and
  a strict higher low than its parent month.
- SELL only when it has both a strict lower high and a strict lower low.
- Equality at either endpoint, inside/outside geometry, one-endpoint
  migration, malformed data, incomplete months, or nonconsecutive months
  remain flat.

The intended baseline follows this completed monthly auction-range migration
until the next broker-month boundary, with one durable attempt, one fixed-risk
position, a frozen completed-bar ATR hard stop, no target, and no external
runtime data. Source extraction and Q00 must lock the exact label, session,
risk, lifecycle, and falsification contracts before build.

## Preliminary non-duplicate boundary

The canonical fail-closed pre-allocation checker scanned 4,591 EA-registry
identities, 1,270 repository cards, and 45 Strategy-Wiki nodes. It returned
no exact slug or strategy-ID collision and the expected fuzzy weekly-family
matches. The machine-readable receipt is
`artifacts/qm5_wti_mrange_migrate_mom_preallocation_dedup_20260822.json`.

Manual semantic review classifies the fuzzy hits as adjacent but separately
falsifiable families:

- `QM5_41089_wti-wrange-migrate-mom` applies the two-endpoint comparison to
  two completed broker weeks and holds one week. The candidate aggregates
  roughly a full month of sessions into each package, decides only twelve
  times per year, and holds the next complete broker month. The formation
  sample, auction horizon, turnover, financing exposure, and lifecycle are
  jointly different; no weekly result transfers.
- `QM5_41101_xng-wrange-migrate-mom` is both the weekly carrier sibling and a
  natural-gas exposure. This candidate is direct WTI on a monthly clock.
- `QM5_20187_wti-tsmom1m` reads only two completed month-end closes and trades
  their return sign. This candidate never reads a close, instead aggregating
  every accepted session high and low in two complete months and requiring
  both auction endpoints to migrate together.
- `QM5_20008_wti-month-ch3` compares the latest completed month-end close with
  three earlier month-end closes. This candidate has no close-channel rule
  and compares two aggregate high/low packages only.
- `QM5_41064_wti-mflip-mom` requires a sign change between two adjacent
  completed-month close returns. This candidate uses no return, close, sign
  handoff, or flip condition.
- `QM5_41073_wti-woutside-settle`, `QM5_41090_wti-wmid-overlap-mom`, and
  `QM5_41093_wti-wclose-breakout-mom` are weekly close/settlement, midpoint,
  or outside-range mechanics. They do not implement two complete monthly
  high/low packages with the strict same-direction endpoint rule.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only, two-day XNG
  cumulative-RSI2 pullback below a slow trend filter. The candidate is
  symmetric, oscillator-free, direct WTI, monthly, and structural.

The exact WTI carrier, two consecutive completed broker-calendar monthly
high/low packages, 17-to-23-session contract, strict `HH+HL` long / `LH+LL`
short state, every equality/inside/outside/mixed state flat, first-new-month
entry, durable attempt, fixed risk, and next-month lifecycle are jointly
load-bearing. Q00 still owes a post-allocation identity scan; any exact
monthly WTI implementation found before approval stops the build.

## Source and claim boundary

Moskowitz, Ooi, and Pedersen are approved as lineage for the proposition that
an asset's own past price direction can contain monthly continuation
information; the governed record identifies WTI in the paper's commodity
universe and documents explicit monthly formation/holding tests. The authors
do not test a WTI monthly higher-high/higher-low or lower-high/lower-low
auction-range state, a Darwinex continuous CFD, fixed cash risk, an ATR stop,
or the QM portfolio. Those are transparent QM hypotheses, not source claims.

No source return, WTI-specific alpha, profit factor, drawdown, trade count,
transaction cost, CFD equivalence, neutrality, or portfolio-correlation
statistic may transfer to the card. Q02 owns frequency and baseline economics.
Q09 alone may establish realized portfolio correlation.

## Reputable-source criteria

- R1 `PASS_WITH_MONTHLY_RANGE_STATE_TRANSLATION_RISK`: the bounded child will
  trace to named authors, a peer-reviewed JFE paper, DOI, complete-paper
  evidence, durable retrieval hash, and explicit WTI membership; the monthly
  range-state proxy is disclosed as untested.
- R2 `PASS`: the extraction must fix the clock, label normalization, month
  adjacency, session counts, high/low aggregation, strict endpoint
  comparisons, side, attempt, risk, spread, stop, and lifecycle.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 state provide every planned runtime input.
  Q02 owns label, history, density, fill, cost, and CFD-basis sufficiency.
- R4 `PASS`: timestamps, completed OHLC, comparisons, ATR, quotes, positions,
  deals, and terminal state only; no banned indicator, trained output,
  external feed, adaptive fit, grid, martingale, scale-in, or pyramid.

## Falsification and safety boundary

Expected cadence is approximately five to nine completed positions per full
post-warm-up year. Q02 must retire a full scored year below five trades, zero
trades, nonpositive governed economics, or any label, month, session, OHLC,
strict-range-state, direction, attempt, risk, lifecycle, or determinism
defect. A weak result may not be rescued by accepting equality or mixed
states, changing month membership or direction, adding current-month
confirmation, shortening the hold, or adding return, close-location,
volatility, volume, calendar-season, moving-average, oscillator, event,
inventory, or external-data filters.

This approval authorizes only complete reading of the bounded governed source,
creation of one child source packet, and subsequent Q00 consideration. It does
not authorize a manual backtest, terminal control, live/demo/shadow/stress/
optimization preset, AutoTrading, `T_Live`, deploy or `T_Live` manifest,
portfolio-gate change, portfolio admission, correlation waiver, after-result
salvage, or a duplicate queue row.
