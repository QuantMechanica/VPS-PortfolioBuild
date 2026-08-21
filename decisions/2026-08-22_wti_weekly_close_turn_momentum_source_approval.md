# WTI weekly close-turn recovery momentum source approval

Date: 2026-08-22

Decision: `APPROVED_SOURCE`

## Authority and bounded scope

The current explicit OWNER instruction delivered to Codex on branch
`agents/board-advisor` authorizes one new structural, low-frequency
commodity/energy edge outside the certified XAU/SP500/NDX/XNG book. It
requires a reputable-source record, one QM card and build, `RISK_FIXED`
backtest configuration, one paced Q02 enqueue, branch-only commits, and no
`T_Live`, AutoTrading, portfolio-gate, or `T_Live`-manifest changes.

This decision approves source intake for one bounded candidate:

- planned source ID: `BIANCHI-MOP-WTI-WCLOSE-TURN-MOM-2026`;
- planned strategy ID:
  `BIANCHI-MOP-WTI-WCLOSE-TURN-MOM-2026_S01`;
- planned slug: `wti-wclose-turn-mom`;
- carrier and clock: exact `XTIUSD.DWX`, D1, evaluated once at the first
  tradable bar of a new normalized Monday-anchored broker week; and
- governed source records read completely before this approval:
  - `strategy-seeds/sources/BIANCHI-MOMREV-2015/source.md`, SHA-256
    `F2EA59689B0FA0AE21A0BE5689A8F965062C65055516737C5210C65F6B072752`;
  - `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
    `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

The first record covers Robert J. Bianchi, Michael E. Drew, and John Hua Fan
(2015), "Combining Momentum with Reversal in Commodity Futures,"
*Journal of Banking & Finance* 59, 423-444, DOI
`10.1016/j.jbankfin.2015.07.006`, with an end-to-end read of the 59-page
accepted manuscript. The second covers Tobias J. Moskowitz, Yao Hua Ooi, and
Lasse Heje Pedersen (2012), "Time Series Momentum," *Journal of Financial
Economics* 104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, with an
end-to-end read of the published 23-page paper and a durable PDF hash. Both
source universes explicitly include WTI crude oil futures.

This is source approval only. It does not approve a Strategy Card, allocate
an EA ID or magic, authorize live use, establish efficacy or decorrelation,
or waive any deterministic Q gate.

## Candidate mechanic authorized for extraction

On the first tradable `XTIUSD.DWX` D1 bar of a new normalized broker week,
load the exact immediately completed Monday-anchored broker week. Require
exact seven-calendar-day adjacency, three to five unique and strictly ordered
valid sessions, one uniform energy-label convention, and no current-week
signal data.

Let `c[0] ... c[n-1]` be the completed sessions' closes in chronological
order. Trade only one strict interior close-path turn that fully recovers past
the first close:

```text
there is one k, 1 <= k <= n-2, such that
c[0] > c[1] > ... > c[k] < c[k+1] < ... < c[n-1]
and c[n-1] > c[0]                                      => BUY XTIUSD.DWX

there is one k, 1 <= k <= n-2, such that
c[0] < c[1] < ... < c[k] > c[k+1] > ... > c[n-1]
and c[n-1] < c[0]                                      => SELL XTIUSD.DWX

otherwise                                               => FLAT
```

The strict monotone segments make the interior trough or peak unique.
Equality between adjacent closes, an endpoint turn, more than one turn,
incomplete recovery, malformed or nonadjacent history, or invalid prices
remain flat. Turn depth, recovery magnitude, and turn index never change
size.

The intended baseline follows the completed recovery direction for exactly
one broker week. It consumes one durable weekly attempt, uses one fixed-risk
position with a frozen completed-bar ATR hard stop and no target, and reads no
external runtime data. Q00 must lock the exact labels, chronology, risk,
lifecycle, and falsification rules before any build.

## Preliminary non-duplicate boundary

The canonical fail-closed pre-allocation checker scanned 4,588 EA-registry
identities and 1,267 repository cards. It found no exact or fuzzy match. Its
configured optional Strategy-Wiki root was unavailable, so it correctly
returned `INPUT_ERROR_FAIL_CLOSED` rather than a false clean result. The
machine-readable receipt is
`artifacts/qm5_wti_wclose_turn_mom_preallocation_dedup_20260822.json`.

Manual repository-wide family review fixes the load-bearing distinctions:

- `QM5_41098_wti-wextreme-sequence-mom` orders the sessions carrying the
  completed week's unique aggregate high and low and confirms with the weekly
  open-to-close sign. This candidate ignores opens, highs, and lows; it uses
  every chronological session close, requires one interior close turn, and
  requires a full endpoint recovery.
- `QM5_41084_wti-wdaybreadth-mom` counts positive and negative adjacent D1
  returns in an exact five-session week and requires four-of-five breadth plus
  a parent-close-to-final-close sign. This candidate has no sign count or
  parent close and rejects every multi-turn path even if one sign dominates.
- `QM5_41092_wti-wbody-dominance-mom` compares aggregate open/close body size
  with the weekly high-low range. This candidate reads neither the weekly open
  nor range and imposes no body-share threshold.
- `QM5_41095_wti-wexcursion-imbalance-mom` and
  `QM5_41096_wti-wexcursion-reject-rv` compare open-centred high/low
  excursions at a strict two-to-one threshold. This candidate compares no
  excursion distances and is invariant to intraday highs and lows.
- `QM5_41065`, `QM5_41068` through `QM5_41072`, `QM5_41074`, and
  `QM5_41082` classify sequences of completed week-end returns. This
  candidate uses one completed week's within-week session-close path and no
  older week-end return.
- `QM5_41029`, `QM5_41032`, and `QM5_41033` decompose overnight and
  intraday flows. This candidate uses only chronological completed closes and
  performs no open-to-close or gap decomposition.
- the generic `QM5_9361_mql5-ichi-kumo-bounce` uses a three-bar Ichimoku-cloud
  touch plus ADX/DI on M30. It is not a WTI weekly native-close path and uses
  different state, filters, and lifecycle.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback below a slow mean. This candidate is direct WTI,
  symmetric, weekly, oscillator-free, and based on a strict completed-close
  turn and recovery.

The exact WTI carrier, one immediately completed three-to-five-session week,
every chronological session close, one strict interior turning point, strict
monotone legs, final-close recovery beyond the first close, boundary entry,
durable attempt, fixed risk, and next-week exit are jointly load-bearing. Q00
still owes a post-allocation identity scan; any exact implementation found
before approval stops the build.

## Source and claim boundary

Bianchi, Drew, and Fan supply peer-reviewed evidence that commodity returns
can contain distinct momentum and longer-horizon reversal components.
Moskowitz, Ooi, and Pedersen supply peer-reviewed own-return continuation
evidence. WTI is present in both source universes.

Neither source tests a within-week single-turn close path, strict monotone
segments, full endpoint recovery, a weekly WTI-only rule, Darwinex continuous
CFDs, broker-label normalization, fixed cash risk, an ATR stop, or a one-week
hold. Those are transparent QM hypotheses. No source return, WTI-only alpha,
frequency, profit factor, drawdown, cost, CFD equivalence, or portfolio-
correlation result may transfer.

## Reputable-source criteria

- R1 `PASS_WITH_WEEKLY_CLOSE_PATH_TRANSLATION_RISK`: both lineages are
  named-author, peer-reviewed DOI sources with complete manuscript reads and
  explicit WTI membership. The single-turn/full-recovery conjunction is
  explicitly untested.
- R2 `PASS`: carrier, uniform label convention, week anchor, session count,
  close ordering, strict inequalities, unique interior turn, recovery side,
  attempt, fixed risk, spread, hard stop, and lifecycle must be mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 state provide every runtime input. Q02 owns
  label, density, fill, cost, and continuous-CFD falsification.
- R4 `PASS`: timestamps, completed closes, comparisons, ATR, quotes,
  positions, deals, and terminal state only; no banned indicator, trained
  output, external feed, adaptive fit, grid, martingale, scale-in, or pyramid.

## Falsification and safety boundary

Expected cadence is approximately six to eighteen completed positions per
full post-warm-up year. Q02 must retire a full scored year below five trades,
zero trades, nonpositive governed economics, or any label, anchor, session,
chronology, strict-turn, recovery, direction, attempt, risk, lifecycle, or
determinism defect. A weak result may not be rescued by accepting equality,
endpoint or multiple turns, incomplete recovery, changing the hold, or
adding a turn-depth, return, range, body, wick, close-location, calendar,
volatility, volume, moving-average, oscillator, event, inventory, or external-
data filter.

This approval authorizes only extraction of one complete bounded child source
packet and subsequent Q00 consideration. It does not authorize a manual
backtest, terminal control, live/demo/shadow/stress/optimization preset,
AutoTrading, `T_Live`, deploy or `T_Live` manifest, portfolio-gate change,
portfolio admission, correlation waiver, after-result salvage, or a duplicate
queue row.
