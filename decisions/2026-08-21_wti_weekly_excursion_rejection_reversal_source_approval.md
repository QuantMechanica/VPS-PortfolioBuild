# WTI weekly excursion-rejection reversal source approval

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

- planned source ID: `BIANCHI-YANG-WTI-WEXCURSION-REJECT-RV-2026`;
- planned strategy ID:
  `BIANCHI-YANG-WTI-WEXCURSION-REJECT-RV-2026_S01`;
- planned slug: `wti-wexcursion-reject-rv`;
- carrier and clock: exact `XTIUSD.DWX`, D1, evaluated once at the first
  tradable bar of a new normalized Monday-anchored broker week; and
- governed source records read completely before this approval:
  - `strategy-seeds/sources/BIANCHI-MOMREV-2015/source.md`, SHA-256
    `F2EA59689B0FA0AE21A0BE5689A8F965062C65055516737C5210C65F6B072752`;
  - `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`, SHA-256
    `52DBFDAC58E6444D14AACFC97D26E4F8FA0010B6A10F0768DBE56067055ED7F7`.

This is source approval only. It does not approve a Strategy Card, allocate
an EA ID or magic, authorize live use, establish efficacy or decorrelation,
or waive any deterministic Q gate.

## Candidate mechanic authorized for extraction

Aggregate the exact immediately completed broker week from native WTI D1
OHLC. Require three to five unique, strictly ordered valid sessions and exact
seven-calendar-day adjacency to the current normalized Monday anchor. Exclude
all current-week OHLC.

Let `O`, `H`, `L`, and `C` be that completed week's chronological first open,
aggregate high, aggregate low, and chronological final close. Define:

```text
U = H - O
D = O - L
```

Trade only a strict dominant excursion that the final settlement rejects:

```text
U > 2*D and C < O  => SELL XTIUSD.DWX
D > 2*U and C > O  => BUY XTIUSD.DWX
otherwise          => FLAT
```

Ratio equality, close/open equality, excursion/settlement agreement, invalid
geometry, malformed or nonadjacent history, and an incomplete package remain
flat. Magnitude beyond the strict qualification never changes size.

The intended baseline fades the rejected completed auction for exactly one
broker week. It consumes one durable weekly attempt, uses one fixed-risk
position with a frozen completed-bar ATR hard stop and no target, and reads no
external runtime data. Q00 must lock exact labels, sessions, risk, lifecycle,
and falsification rules before any build.

## Preliminary non-duplicate boundary

The canonical fail-closed pre-allocation checker scanned 4,585 EA-registry
identities and 1,265 repository cards. Its configured optional Strategy-Wiki
root was unavailable, so it correctly returned `FUZZY_MATCH` rather than a
false clean result. The machine-readable receipt is
`artifacts/qm5_wti_wexcursion_reject_rv_preallocation_dedup_20260821.json`.

The single fuzzy match was
`QM5_41095_wti-wexcursion-imbalance-mom` at mechanic score `0.90`. Manual
review finds a close family relationship but a disjoint signal:

- `QM5_41095` requires `U > 2*D and C > O` for BUY or `D > 2*U and C < O`
  for SELL. It follows a dominant excursion only when settlement agrees.
- This candidate requires the exact complementary settlement-rejection
  states: `U > 2*D and C < O` for SELL or `D > 2*U and C > O` for BUY.
  Agreement is explicitly flat. No completed week can qualify both rules.
- `QM5_41092_wti-wbody-dominance-mom` compares absolute close/open body with
  full range. This candidate compares the two open-centred excursions and
  requires the close sign to oppose the dominant excursion; body magnitude
  cannot qualify it.
- `QM5_41080_wti-wclose-location-mom` requires a parent-to-newest close
  return plus an outer-fifth close. This candidate reads no parent return and
  has no close-location threshold.
- `QM5_41089_wti-wrange-migrate-mom` compares aggregate extremes across two
  weeks. This candidate is invariant to the parent week.
- `QM5_41093_wti-wclose-breakout-mom` requires a newest close beyond a prior
  closing channel. This candidate reads no prior channel.
- `QM5_41073_wti-woutside-settle` requires outside-parent geometry and a
  close beyond a parent extreme. This candidate aggregates one week only.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback below a slow mean. This candidate is direct WTI,
  symmetric, weekly, and oscillator-free.

The exact WTI carrier, one immediately completed weekly OHLC package, strict
open-centred two-to-one imbalance, opposing settlement sign, agreement-flat
behavior, first-new-week entry, durable attempt, fixed risk, and next-week
exit are jointly load-bearing. Q00 still owes a post-allocation identity scan;
any exact implementation discovered before approval stops the build.

## Source and claim boundary

Bianchi, Drew, and Fan (2015), *Journal of Banking & Finance* 59, 423-444,
DOI `10.1016/j.jbankfin.2015.07.006`, supplies peer-reviewed commodity
reversal lineage from a complete accepted-manuscript read. Its universe
includes crude oil. Yang, Goncu, and Pantelous, SSRN 3069253, supplies a
supplemental fixed-horizon commodity momentum/reversal lineage already
governed for WTI translations.

Neither source tests weekly open-centred excursion imbalance, settlement
rejection, a two-to-one threshold, Darwinex continuous CFDs, fixed cash risk,
an ATR stop, or a one-week hold. Those are transparent QM hypotheses. No
source return, WTI-only alpha, frequency, profit factor, drawdown, cost, CFD
equivalence, neutrality, or portfolio-correlation result may transfer.

## Reputable-source criteria

- R1 `PASS_WITH_WEEKLY_FAILED_AUCTION_TRANSLATION_RISK`: the primary lineage
  is a named-author peer-reviewed paper with DOI and complete institutional
  manuscript read; the supplemental working paper is identified separately.
  The weekly failed-auction rule is explicitly untested.
- R2 `PASS`: carrier, label convention, week anchor, session count, OHLC
  aggregation, strict inequalities, rejection direction, attempt, fixed risk,
  spread, hard stop, and lifecycle must be fully mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 state provide every runtime input. Q02 owns
  label, density, fill, cost, and continuous-CFD falsification.
- R4 `PASS`: timestamps, completed OHLC, arithmetic, comparisons, ATR, quotes,
  positions, deals, and terminal state only; no banned indicator, trained
  output, external feed, adaptive fit, grid, martingale, scale-in, or pyramid.

## Falsification and safety boundary

Expected cadence is approximately five to fifteen completed positions per
full post-warm-up year. Q02 must retire a full scored year below five trades,
zero trades, nonpositive governed economics, or any label, anchor, OHLC,
inequality, direction, attempt, risk, lifecycle, or determinism defect. A weak
result may not be rescued by moving the two-to-one boundary, accepting
equality or settlement agreement, changing direction or hold, or adding a
body, wick, close-location, trend, calendar, volatility, volume, event,
inventory, moving-average, oscillator, or external-data filter.

This approval authorizes only complete reading of the bounded governed
sources, one child source packet, and subsequent Q00 consideration. It does
not authorize a manual backtest, terminal control, live/demo/shadow/stress/
optimization preset, AutoTrading, `T_Live`, deploy or `T_Live` manifest,
portfolio-gate change, portfolio admission, correlation waiver, after-result
salvage, or a duplicate queue row.
