# WTI weekly extreme-sequence momentum source approval

Date: 2026-08-21

Decision: `APPROVED_SOURCE`

## Authority and bounded scope

The current explicit OWNER instruction delivered to Codex on branch
`agents/board-advisor` authorizes one new structural, low-frequency
commodity/energy edge outside the certified XAU/SP500/NDX/XNG book. It
requires a reputable-source record, one QM card and build, `RISK_FIXED`
backtest configuration, one paced Q02 enqueue, branch-only commits, and no
`T_Live`, AutoTrading, portfolio-gate, or `T_Live`-manifest changes.

This decision approves source intake for one bounded candidate:

- planned source ID: `MOP-WTI-WEXTREME-SEQUENCE-MOM-2026`;
- planned strategy ID: `MOP-WTI-WEXTREME-SEQUENCE-MOM-2026_S01`;
- planned slug: `wti-wextreme-sequence-mom`;
- carrier and clock: exact `XTIUSD.DWX`, D1, evaluated once at the first
  tradable bar of a new normalized Monday-anchored broker week; and
- governed source record read completely before this approval:
  `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
  `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

The parent record covers Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje
Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. It records an end-to-end
read of the published 23-page paper, a retrieval receipt, the published-PDF
hash, and WTI crude oil as an explicit commodity-futures constituent.

This is source approval only. It does not approve a Strategy Card, allocate
an EA ID or magic, authorize live use, establish efficacy or decorrelation,
or waive any deterministic Q gate.

## Candidate mechanic authorized for extraction

On the first tradable `XTIUSD.DWX` D1 bar of a new normalized broker week,
aggregate the exact immediately completed broker week from native completed
D1 OHLC. Require exact seven-calendar-day adjacency to the current Monday
anchor and three to five unique, strictly ordered valid sessions. Exclude all
current-week OHLC.

Let `O` be the chronological first session open, `H` the aggregate high, `L`
the aggregate low, and `C` the chronological final session close. Identify
the unique session index of `H` and the unique session index of `L`. A tied
extreme, an extreme repeated on more than one session, or both extremes on
the same session is ambiguous and remains flat.

Trade only when the order of unique completed-week extremes and the final
settlement direction agree:

```text
unique low occurs before unique high and C > O  => BUY XTIUSD.DWX
unique high occurs before unique low and C < O  => SELL XTIUSD.DWX
otherwise                                       => FLAT
```

Close/open equality, extreme-order/settlement disagreement, invalid geometry,
malformed or nonadjacent history, an incomplete package, repeated extremes,
and same-session extremes remain flat. Extreme timing or return magnitude
never changes size.

The intended baseline follows the completed directional auction for exactly
one broker week. It consumes one durable weekly attempt, uses one fixed-risk
position with a frozen completed-bar ATR hard stop and no target, and reads no
external runtime data. Q00 must lock exact labels, sessions, risk, lifecycle,
and falsification rules before any build.

## Preliminary non-duplicate boundary

The canonical fail-closed pre-allocation checker scanned 4,587 EA-registry
identities and 1,266 repository cards. It found no exact or fuzzy match. Its
configured optional Strategy-Wiki root was unavailable, so it correctly
returned `INPUT_ERROR_FAIL_CLOSED` rather than a false clean result. The
machine-readable receipt is
`artifacts/qm5_wti_wextreme_sequence_mom_preallocation_dedup_20260821.json`.

Manual repository-wide family review fixes the load-bearing distinctions:

- `QM5_41095_wti-wexcursion-imbalance-mom` compares aggregate
  `high-open` and `open-low` magnitudes at a strict two-to-one threshold. This
  candidate has no excursion-size comparison and instead requires the unique
  chronological order of the sessions carrying the weekly extremes.
- `QM5_41096_wti-wexcursion-reject-rv` uses the same excursion magnitudes but
  requires settlement rejection. This candidate ignores excursion magnitude
  and trades only extreme-order/settlement agreement.
- `QM5_41092_wti-wbody-dominance-mom` compares absolute close/open body with
  the full weekly range. This candidate has no body-share threshold.
- `QM5_41084_wti-wdaybreadth-mom` counts positive and negative D1 session
  bodies. This candidate counts no body signs and uses only the unique session
  locations of the aggregate high and low plus the weekly settlement sign.
- `QM5_41029`, `QM5_41032`, `QM5_41033`, and their monthly variants decompose
  close-to-open and open-to-close flow. This candidate performs no overnight
  or session-flow decomposition.
- `QM5_41073_wti-woutside-settle`, `QM5_41080_wti-wclose-location-mom`, and
  `QM5_41089_wti-wrange-migrate-mom` require a parent-week range, return, or
  close-location comparison. This candidate is invariant to its parent week.
- `QM5_12965_wti-week-orb` and `QM5_13075_xti-inweek-brk` require a
  current-week breakout after formation. This candidate uses no current-week
  signal price and enters only at the boundary.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback below a slow mean. This candidate is direct WTI,
  symmetric, weekly, oscillator-free, and based on completed extreme order.

The exact WTI carrier, one immediately completed weekly package, unique
high/low occurrences, chronological extreme order, matching settlement sign,
ambiguous/disagreement-flat behavior, first-new-week entry, durable attempt,
fixed risk, and next-week exit are jointly load-bearing. Q00 still owes a
post-allocation identity scan; any exact implementation discovered before
approval stops the build.

## Source and claim boundary

Moskowitz, Ooi, and Pedersen supply peer-reviewed evidence for own-return
continuation across liquid futures and a symmetric sign-to-direction map.
WTI is present in the source universe.

The paper's tested formation and holding horizons are monthly. It does not
test the chronological order of weekly high and low sessions, settlement
agreement, Darwinex continuous CFDs, broker-label normalization, fixed cash
risk, an ATR stop, or a one-week hold. Those are transparent QM hypotheses.
No source return, WTI-only alpha, frequency, profit factor, drawdown, cost,
CFD equivalence, or portfolio-correlation result may transfer.

## Reputable-source criteria

- R1 `PASS_WITH_WEEKLY_EXTREME_SEQUENCE_TRANSLATION_RISK`: the lineage is a
  named-author, peer-reviewed DOI source with a complete published-paper read,
  durable retrieval hash, and explicit WTI membership. The weekly path-state
  proxy is explicitly untested.
- R2 `PASS`: carrier, uniform label convention, week anchor, session count,
  OHLC validation, unique-extreme rule, chronological comparison, settlement
  sign, attempt, fixed risk, spread, hard stop, and lifecycle must be fully
  mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 state provide every runtime input. Q02 owns
  label, density, fill, cost, and continuous-CFD falsification.
- R4 `PASS`: timestamps, completed OHLC, integer sequence comparisons, ATR,
  quotes, positions, deals, and terminal state only; no banned indicator,
  trained output, external feed, adaptive fit, grid, martingale, scale-in, or
  pyramid.

## Falsification and safety boundary

Expected cadence is approximately fifteen to thirty completed positions per
full post-warm-up year. Q02 must retire a full scored year below five trades,
zero trades, nonpositive governed economics, or any label, anchor, session,
extreme-uniqueness, ordering, direction, attempt, risk, lifecycle, or
determinism defect. A weak result may not be rescued by accepting repeated or
same-session extremes, dropping settlement agreement, reversing direction,
changing the hold, or adding an excursion, body, wick, close-location, range,
trend, calendar, volatility, volume, event, inventory, moving-average,
oscillator, or external-data filter.

This approval authorizes only extraction of one complete bounded child source
packet and subsequent Q00 consideration. It does not authorize a manual
backtest, terminal control, live/demo/shadow/stress/optimization preset,
AutoTrading, `T_Live`, deploy or `T_Live` manifest, portfolio-gate change,
portfolio admission, correlation waiver, after-result salvage, or a duplicate
queue row.
