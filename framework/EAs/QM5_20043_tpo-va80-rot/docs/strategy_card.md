---
card_schema_version: 2
ea_id: QM5_20043
slug: tpo-va80-rot
status: DRAFT
g0_status: APPROVED
symbol: NDX.DWX
timeframe: M30
variant_id: TPO_VA80_ROT_BASELINE
execution_contract_ref: framework/registry/dxz23_execution_contracts.json#ea_id=20043
execution_contract_status: DRAFT
target_symbols: [NDX.DWX, WS30.DWX, SP500.DWX]
expected_trades_per_year_per_symbol: 45
g0_approval_reasoning: "R1 single D-tier FTMO 2026 source, edge UNVERIFIED pending DEV; R2 mechanical M30 prior-value rotation; R3 .DWX M30/session data; R4 deterministic RISK_FIXED, no ML"
last_updated: 2026-07-22
expected_pf: 1.2
expected_dd_pct: 15.0
source_id: FTMO-MARKETPROFILE-80-2026
ml_required: false
r1_track_record: PASS
r1_reasoning: "Single canonical quality-tier D FTMO source; the '80%' edge is an UNVERIFIED hypothesis to be validated only by DEV 2018-2023, while Reddit links are discovery context rather than independent attribution."
r2_mechanical: PASS
r2_reasoning: "Fully mechanical M30 prior-RTH TPO proxy, outside-value open, two-bar value re-entry, fixed 10:30 ET entry, first-hour stop, opposite-value target, and 16:00 ET exit."
r3_data_available: PASS
r3_reasoning: "NDX.DWX, WS30.DWX, and SP500.DWX M30 real-tick histories plus the governed New York cash-session calendar support the prescribed DEV/OOS/sealed study."
r4_ml_forbidden: PASS
r4_reasoning: "Deterministic price-row, session-clock, geometry, and cost rules with RISK_FIXED sizing; no centralized profile feed, grid, martingale, discretionary input, or ML."
source_citations:
  - type: web_blog
    citation: "FTMO (2026). Market Profile: Master the 80% Trading Strategy & Hidden Magnets. https://ftmo.com/en/blog/market-profile-master-the-80-trading-strategy-hidden-magnets/"
    location: "Outside-value open, two consecutive 30-minute periods accepted back inside prior value, and rotation toward the opposite value boundary."
    quality_tier: D
    role: primary
---

# Prior-RTH TPO value-area re-entry rotation

## Source-defined rules

The FTMO 2026 article *Market Profile: Master the 80% Trading Strategy &
Hidden Magnets*, URL
https://ftmo.com/en/blog/market-profile-master-the-80-trading-strategy-hidden-magnets/,
describes a practitioner setup in which the market opens outside the previous
value area, returns to it for two consecutive 30-minute periods, and then may
rotate toward the opposite value boundary. That FTMO article is the card's one
canonical source and sole rule attribution. A 2024 r/Daytrading discussion,
URL https://www.reddit.com/r/Daytrading/comments/1dh8ro0, and a separate 2023
discussion, URL https://www.reddit.com/r/Daytrading/comments/1059wv1, are
recorded only as discovery context; they supply no independent rule, evidence,
or source lineage to this card.

The quality-tier D FTMO source provides neither an audited trade list nor a
complete protective-stop and execution specification. The community's “80%”
name is an **UNVERIFIED hypothesis**, not a win-rate estimate and not accepted
evidence. The bar-derived TPO construction, 70% value-area algorithm,
tie-breaking, first-hour-extreme stop, 1.5-to-1 feasibility gate, cost gate,
and same-session time exit are QM completion rules rather than source claims.

## QM interpretations

Every mechanic in this section is frozen under variant
`TPO_VA80_ROT_BASELINE` for `NDX.DWX`, `WS30.DWX`, and backtest-only
`SP500.DWX`, independently, on `M30`.

- **Prior-session TPO proxy.** Use the previous complete US regular trading
  session `[09:30,16:00)` in DST-aware `America/New_York`, comprising exactly
  thirteen completed `M30` bars. Quantize every bar's inclusive low-to-high
  span to the symbol's minimum tick and assign one TPO to each price row
  touched by each bar. This is a bar-derived proxy, not centralized futures
  volume or an exchange Market Profile feed. Missing, shortened, duplicated,
  misaligned, or otherwise incomplete prior-session bars fail closed.
- **POC and value area.** POC is the row with the greatest TPO count. On a POC
  tie, choose the row closest to the arithmetic midpoint of the prior RTH high
  and low; if still tied after tick normalization, choose the lower row. Start
  with POC selected. Repeatedly compare the next unselected adjacent row above
  with the next below: add the larger TPO count, or on equality add both in
  lower-then-upper order. Stop once selected counts are at least 70% of all TPO
  counts. Freeze `VAL` and `VAH` as the lowest and highest selected rows for the
  next eligible RTH session. A non-positive or degenerate profile fails closed.
- **Opening location and entry window.** Record the first tradable 09:30 ET
  opening print. It must be strictly below prior `VAL` to arm LONG or strictly
  above prior `VAH` to arm SHORT; an open on or inside a boundary is no trade.
  For a below-value open, both completed bars `[09:30,10:00)` and
  `[10:00,10:30)` must close `> VAL` and `<= VAH`. For an above-value open,
  both must close `>= VAL` and `< VAH`. Enter only at the first tradable quote
  of the 10:30 ET `M30` open, provided the actual fill remains within
  `[VAL,VAH]` and strictly on the safe side of the proposed stop. There is one
  attempt per symbol per RTH date; no later sequence, re-entry, POC discretion,
  candle overlay, or volume confirmation is authorized.
- **Stop, target, and time exit.** For LONG, place an immutable broker hard stop
  one minimum tick below the lower low of the 09:30 and 10:00 bars and a fixed
  take-profit at prior-day `VAH`. For SHORT, place the stop one tick above the
  higher high of those bars and the target at prior-day `VAL`. Compute geometry
  from the actual fill and skip unless target distance is positive and at least
  `1.5 * fill_to_stop_distance`; equality qualifies. If the target was already
  crossed before entry, this gate fails. Resolve stop/target order from
  executable bid/ask tick chronology. If neither protective order closes the
  trade, force-flat at the first tradable quote at or after 16:00 ET. There is
  no partial close, breakeven move, trail, scale, averaging, or retry.
- **Sizing and costs.** Backtests use only the setfile's locked `RISK_FIXED`
  monetary amount. Size once from actual fill-to-stop monetary risk;
  `RISK_PERCENT` is unauthorized. Resolve commission, current spread, tick
  value, account-currency conversion, volume step, and broker stop constraints
  from governed runtime data, with no invented commission or swap assumption.
  Require `(commission + spread) / initial_monetary_risk <= 0.10R`; missing or
  non-positive inputs, an unrepresentable volume, or a failed broker constraint
  blocks entry.
- **Density and family.** The conservative authoring prior recorded for queue
  ordering is 45 trades/year/symbol, inside the untested 20-70 range after all
  gates. Concurrent US-index instances are one correlated auction-value risk
  family and may not be counted as independent portfolio evidence.

## Framework execution overrides

- The framework emergency/account kill switch disables new entries and may
  flatten an open position before any strategy-managed exit.
- The default governed news blackout remains enabled. It may suppress the
  10:30 ET entry but cannot create, postpone, or relocate a signal; a blocked
  entry consumes that symbol-date.
- The framework Friday broker-time close remains enabled as a safety flatten;
  the card's 16:00 ET exit normally makes it unreachable.
- No generic breakout, session-entry, trailing, portfolio rescue, grid,
  martingale, pyramid, loss-dependent sizing, or ML override is authorized.

## Exit precedence

1. Framework emergency/account kill-switch close.
2. Executed broker hard stop or fixed opposite-value target, ordered solely by
   executable bid/ask tick chronology rather than `M30` bar extrema.
3. Card force-flat at the first tradable quote at or after 16:00 ET; after a
   restart or rejected close, retry immediately before evaluating any entry.
4. Framework Friday safety close if a position somehow remains open.
5. Calendar, profile, price-history, or cost-data failure blocks new entries
   only; it never cancels an existing broker stop, target, or mandatory close.

## Runtime data dependencies

- Generate **per-symbol setfiles at build** for `NDX.DWX`, `WS30.DWX`, and
  `SP500.DWX`, all on `M30`, all bound to `TPO_VA80_ROT_BASELINE` and
  `RISK_FIXED`. Each setfile derives its own profile and routes orders only to
  its named symbol; there is no cross-symbol signal.
- Supply synchronized real ticks and complete session-anchored `M30` bars,
  symbol tick size, tick value, account-currency conversion, volume step, stop
  level, governed commission, and observed spread. Missing execution data
  fails closed.
- Pin an IANA timezone-database version covering `America/New_York` and a
  provenance-locked US cash-session/holiday/early-close calendar. Log local,
  UTC, and broker timestamps; ambiguous or nonexistent conversions fail closed.
- Histories and calendars must cover DEV 2018-2023, OOS 2024, and untouched
  sealed 2025 with dataset `valid_through=2025-12-31`. `SP500.DWX` remains
  backtest-only until any later FTMO `US500` mapping is separately qualified.
- No centralized order-flow, volume-profile, swap forecast, discretionary
  input, or ML service is required or permitted.

## Falsification and requalification

- Freeze DEV 2018-2023, OOS 2024, and untouched sealed 2025. Report each
  symbol, LONG/SHORT side, outside-open side, entry year, stop/target/time exit,
  and cost rejection separately. The practitioner edge is validated only by
  this DEV study and must survive OOS and sealed confirmation before any later
  promotion.
- Reject if the “80%” label is used as a probability prior, one symbol/year or
  ambiguous within-bar ordering carries the result, correct holidays or DST
  remove it, or the completed first-hour and fixed 70% profile rules are not
  preserved.
- Apply governed nonzero commission and historical spread, then shift entry
  and exits one tick adversely. Reject if OOS or sealed expectancy is not
  positive, the 1.5 geometry gate is required only through fill idealization,
  or any admitted trade has `cost_R > 0.10R`.
- **Dedup boundary:** unlike any opening-range or session breakout sleeve, this
  card never trades expansion away from a newly formed range. It requires an
  outside open, two completed `M30` closes accepting back into the *prior*
  session's TPO value area, and mean-reverts toward its opposite boundary.
- Any change to session identity, timezone mapping, TPO row construction,
  tie-breaking, 70% selection, acceptance bars, 10:30 entry, stop geometry,
  1.5 feasibility gate, target, 16:00 exit, cost model, risk mode, symbol route,
  or variant identity requires a new binary and full data, execution, and
  portfolio requalification. Backtests remain `RISK_FIXED`; no ML is allowed,
  and Development must mark any unresolved mechanic `BLOCKED` rather than
  invent it.
