---
card_schema_version: 2
ea_id: QM5_20045
slug: london-box
status: DRAFT
g0_status: APPROVED
symbol: GBPUSD.DWX
timeframe: M15
variant_id: LONDON_BOX_027_BASELINE
execution_contract_ref: framework/registry/dxz23_execution_contracts.json#ea_id=20045
execution_contract_status: DRAFT
target_symbols: [GBPUSD.DWX, EURGBP.DWX]
expected_trades_per_year_per_symbol: 160
g0_approval_reasoning: "R1 C-tier ForexFactory 2010 source, edge UNVERIFIED pending DEV; R2 mechanical M15 fixed-UTC box/OCO; R3 .DWX M15/clock/news data; R4 deterministic RISK_FIXED, no ML"
last_updated: 2026-07-22
expected_pf: 1.22
expected_dd_pct: 14.0
source_id: FF-MER071898-2010-LONBRK
ml_required: false
r1_track_record: PASS
r1_reasoning: "Quality-tier C forum source without a portable audited trade list; the London-box edge and claimed win rate are UNVERIFIED hypotheses to be validated only by the DEV 2018-2023 study."
r2_mechanical: PASS
r2_reasoning: "Fully mechanical M15 03:00-06:00 UTC box, fixed 27% OCO extensions, opposite-box stops, one-box targets, noon London expiry, and 16:00 London exit."
r3_data_available: PASS
r3_reasoning: "GBPUSD.DWX and EURGBP.DWX M15 real ticks, UTC/London clock conversion, and governed news-calendar inputs support the prescribed DEV/OOS/sealed study."
r4_ml_forbidden: PASS
r4_reasoning: "Deterministic range, clock, OCO, geometry, and cost rules with RISK_FIXED sizing; martingale is explicitly excluded and no discretionary input or ML is permitted."
source_citations:
  - type: web_forum
    citation: "mer071898 (2010). A Simple London Breakout. ForexFactory. https://www.forexfactory.com/thread/230640-a-simple-london-breakout"
    location: "First post and author clarifications: M15, fixed 03:00-06:00 GMT box, 27%/38.2% entry extensions, one-box target, opposite-side stop, one-trade option, and 40-50-pip box guidance."
    quality_tier: C
    role: primary
---

# Fixed-GMT London box breakout

## Source-defined rules

ForexFactory user mer071898's 2010 thread *A Simple London Breakout*, URL
https://www.forexfactory.com/thread/230640-a-simple-london-breakout, specifies
literal `M15` bars, a fixed `03:00-06:00 GMT` range, breakout entries at 27% or
38.2% of the box beyond its boundaries, a one-box target, opposite-box-side
stop geometry, a one-trade option, and guidance that the box should not exceed
roughly 40-50 pips.

The thread is a quality-tier C practitioner source and its approximately
65-75% author win-rate statement is **UNVERIFIED**: it has no portable audited
trade list or accepted `.DWX` out-of-sample record. The downloadable package
was not imported. This baseline independently rebuilds only the prose rules.
The 27% branch and 40-pip cap are frozen here; noon pending-order expiry,
same-day 16:00 London flatten, governed news handling, cost gate, and
`RISK_FIXED` sizing are disclosed QM/FTMO execution rules.

## QM interpretations

Every mechanic in this section is frozen under variant
`LONDON_BOX_027_BASELINE` for `GBPUSD.DWX` and `EURGBP.DWX`, independently, on
`M15`.

- **Box clock and construction.** GMT means fixed UTC with no daylight-saving
  shift. On each eligible trading date, require exactly the twelve complete
  `M15` bars in `[03:00,06:00)` UTC and freeze `H` as their highest executable
  high, `L` as their lowest executable low, and `B = H - L`. Missing,
  duplicated, non-monotonic, or clock-ambiguous data fails closed. Require
  `B > 0` and `B <= 40 pips`; for both authorized four-decimal FX quotes, one
  logical pip is `0.0001` quote units irrespective of broker point digits.
- **Entry window and OCO.** At 06:00 UTC, after the box is complete, calculate
  `buy_trigger = H + 0.27 * B + one minimum tick` and
  `sell_trigger = L - 0.27 * B - one minimum tick`. Place a two-sided OCO pair
  of stop entries only if both requested prices and protective levels satisfy
  broker constraints and neither trigger is already marketable; otherwise the
  date fails closed rather than converting an order to market. The first
  executable fill wins, the opposite order is cancelled immediately, and the
  symbol-date is consumed. No reversal, retry, or second fill is authorized.
  Unfilled orders are live only until 12:00 `Europe/London`; cancel them before
  processing any entry at that timestamp.
- **Stop, target, and time exit.** LONG has an immutable broker hard stop at
  frozen `L` and take-profit at `actual_fill + B`. SHORT has the stop at frozen
  `H` and target at `actual_fill - B`. If an actual fill is at or beyond its
  stop, or monetary risk is non-positive, fail closed and do not treat it as a
  valid study trade. Resolve stop/target ordering from executable bid/ask tick
  chronology. If neither protective order closes the position, force-flat at
  the first tradable quote at or after 16:00 `Europe/London`. There is no
  partial close, breakeven move, trail, scale, averaging, grid, martingale, or
  repeat entry.
- **Sizing and costs.** Backtests use only the setfile's locked `RISK_FIXED`
  monetary amount; `RISK_PERCENT` is unauthorized. Size each pending order once
  from its requested-entry-to-opposite-box-stop monetary distance, using the
  same volume on both OCO sides only when both independently represent the
  fixed amount within the governed lot step; otherwise fail closed. At order
  placement and fill, resolve commission, observed spread, tick value,
  account-currency conversion, volume step, and stop constraints from governed
  runtime data, with no invented commission, swap, or DST assumption. Require
  `(commission + spread) / initial_monetary_risk <= 0.10R` and require the
  one-box target's monetary distance to be at least four times the same
  round-trip cost. Missing inputs, non-positive risk, an unrepresentable
  volume, or either failed cost gate blocks or cancels the entry rather than
  allowing a later chase.
- **News and density.** The default high-impact news pause applies throughout
  the entry window. If it becomes active while the OCO pair is pending, cancel
  both orders and consume the symbol-date; never re-place them after the pause.
  The queue-ordering prior is 160 trades/year/symbol, the midpoint of the
  untested 120-200 range after box, news, holiday, cost, and expiry gates.

## Framework execution overrides

- The framework emergency/account kill switch disables new entries, cancels
  pending orders, and may flatten an open position before any strategy-managed
  exit.
- The governed default news blackout remains enabled with the cancel-and-
  consume behavior above. It cannot create a trade, postpone entry beyond the
  original OCO window, or change the frozen box.
- The framework Friday broker-time close remains enabled as a safety flatten;
  the card's 16:00 London exit normally makes it unreachable.
- No broker-time reinterpretation of the UTC box, generic European-session
  signal, indicator overlay, trailing, portfolio rescue, pyramid,
  loss-dependent sizing, grid, martingale, or ML override is authorized.

## Exit precedence

1. Framework emergency/account kill-switch close and pending-order
   cancellation.
2. Executed broker hard stop at the frozen opposite box boundary or fixed
   one-box target, ordered solely by executable bid/ask tick chronology rather
   than `M15` bar extrema.
3. Card force-flat at the first tradable quote at or after 16:00
   `Europe/London`; after a restart or rejected close, retry immediately before
   evaluating any entry.
4. Framework Friday safety close if a position somehow remains open.
5. Noon expiry, news cancellation, calendar failure, or data staleness blocks
   entries and pending orders only; it never removes a stop, target, or
   mandatory close from an open trade.

## Runtime data dependencies

- Generate **per-symbol setfiles at build** for `GBPUSD.DWX` and
  `EURGBP.DWX`, both on `M15`, both bound to `LONDON_BOX_027_BASELINE` and
  `RISK_FIXED`. Each setfile owns its UTC box, OCO state, consumed-date key,
  position, and order route for its named symbol only.
- Supply synchronized executable real ticks and complete `M15` bars from the
  box through the same-day exit, plus tick size, tick value, account-currency
  conversion, volume step, stop/freeze levels, governed commission, and
  observed spread. Missing execution data fails closed.
- Treat `03:00-06:00 GMT` as fixed UTC. Separately pin an IANA timezone-
  database version covering `Europe/London` for pending expiry and time exit,
  and log UTC, London, and broker timestamps. Ambiguous or nonexistent London
  conversions fail closed; broker server time must never redefine the box.
- Use provenance-locked trading-day and governed high-impact news calendars
  covering the study. Calendars and `GBPUSD.DWX`/`EURGBP.DWX` real-tick
  histories must cover DEV 2018-2023, OOS 2024, and untouched sealed 2025 with
  dataset `valid_through=2025-12-31`.
- No downloaded forum binary, discretionary session label, swap forecast,
  centralized volume feed, or ML service is required or permitted.

## Falsification and requalification

- Freeze DEV 2018-2023, OOS 2024, and untouched sealed 2025. Report each
  symbol, LONG/SHORT side, year, box-width bucket, fill time, news cancellation,
  pending expiry, exit cause, and cost rejection separately. The forum edge is
  validated only by DEV and must survive OOS and sealed confirmation before any
  later promotion.
- Reject if the 65-75% author claim is used as a prior, one pair/direction/year
  carries the result, a broker-time rather than UTC box is used, or correct
  London DST and news handling remove the result. Audit every UTC/London
  transition date separately.
- Apply governed nonzero commission and historical spread, then shift entry
  and exits one tick adversely. Reject if OOS or sealed expectancy is not
  positive, the one-box target fails the four-cost rule, or any admitted trade
  has `cost_R > 0.10R`.
- The source's 38.2% extension and 30/50-pip cap alternatives are not baseline
  optimization knobs. Any later test must preregister a distinct variant and
  may not jointly search parameters on OOS or sealed data.
- **Dedup boundary:** unlike other FX London/Frankfurt or broker-session
  sleeves, this card alone freezes a twelve-bar `03:00-06:00 UTC` box, uses
  symmetric 27%-of-box OCO extensions, stops at the opposite box side, targets
  exactly one box from fill, expires orders at noon London, and exits at 16:00
  London. Changed clock labels alone do not establish diversification.
- Any change to box membership, UTC/London mapping, range cap, 27% extension,
  tick offset, OCO semantics, entry expiry, stop geometry, one-box target,
  16:00 exit, news behavior, cost model, risk mode, symbol route, or variant
  identity requires a new binary and full clock, data, execution, dedup, and
  portfolio requalification. Backtests remain `RISK_FIXED`; no ML is allowed,
  and Development must mark any unresolved mechanic `BLOCKED` rather than
  invent it.
