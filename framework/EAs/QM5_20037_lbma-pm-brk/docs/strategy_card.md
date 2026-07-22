---
card_schema_version: 2
ea_id: QM5_20037
slug: lbma-pm-brk
status: DRAFT
g0_status: APPROVED
symbol: XAUUSD.DWX
timeframe: M5
variant_id: LBMA_PM_BRK_BASELINE
execution_contract_ref: framework/registry/dxz23_execution_contracts.json#ea_id=20037
execution_contract_status: DRAFT
target_symbols: [XAUUSD.DWX]
expected_trades_per_year_per_symbol: 200
g0_approval_reasoning: "R1 Caminschi-Heaney 2014 JFM34 DOI 10.1002/fut.21636; R2 mechanical 14:55-15:15 London PM-auction window; R3 XAUUSD.DWX M5 real ticks and auction calendar; R4 deterministic auction breakout, no ML"
last_updated: 2026-07-22
expected_pf: 1.25
expected_dd_pct: 12.0
source_id: CAMINSCHI-HEANEY-2014
ml_required: false
r1_track_record: PASS
r1_reasoning: "Peer-reviewed Journal of Futures Markets 34(11), 2014, with DOI 10.1002/fut.21636; the modern-auction transfer is explicitly treated as a regime-port hypothesis rather than a replication claim."
r2_mechanical: PASS
r2_reasoning: "Fully mechanical M5 London PM-auction window: frozen pre-auction range and thrust, closed-bar confirmation, opposite-range hard stop, and 15:15 London time exit."
r3_data_available: PASS
r3_reasoning: "XAUUSD.DWX M5 real-tick history and DST-aware London auction-calendar inputs are available for DEV 2018-2023, OOS 2024, and sealed 2025."
r4_ml_forbidden: PASS
r4_reasoning: "Deterministic clock/range rules with RISK_FIXED sizing, one position per magic, and no grid, martingale, discretionary order-flow input, or ML."
source_citations:
  - type: academic_paper
    citation: "Caminschi, A. & Heaney, R. (2014). Fixing a leaky fixing: short-term market reactions to the London PM gold price fixing. Journal of Futures Markets 34(11):1003-1039. DOI 10.1002/fut.21636."
    location: "Evidence that opening-minutes fixing trades predict fixing direction and that the London PM fixing affects exchange-traded gold instruments."
    quality_tier: B
    role: primary
---

# LBMA PM gold-auction breakout

## Source-defined rules

Caminschi and Heaney (2014), *Fixing a Leaky Fixing: Short-Term Market
Reactions to the London PM Gold Price Fixing*, *Journal of Futures Markets*
34(11), 1003-1039, DOI https://doi.org/10.1002/fut.21636, report that
opening-minutes fixing trades predict the fixing direction and that the London
PM fixing materially affects exchange-traded gold instruments. This establishes
a source-supported benchmark-auction information-concentration mechanism.

The paper studies the former London fixing process. It does not define a rule
for the current LBMA PM auction, `XAUUSD.DWX`, `M5`, a 14:55 pre-auction bar, a
closed-bar breakout, an opposite-range stop, or a 15:15 exit. Transfer to the
current 15:00 London PM auction is an explicitly unverified regime-port
hypothesis; no paper return statistic or auction-imbalance feed is imported.

## QM interpretations

Every rule in this section belongs to variant `LBMA_PM_BRK_BASELINE`.

- **Eligible clock and date.** Use `Europe/London` and only a provenance-locked,
  officially scheduled LBMA PM auction date. Freeze `pre_high`, `pre_low`,
  `pre_open`, and `pre_close` from the completed `[14:55,15:00)` London `M5`
  bar. Require positive `pre_high-pre_low`; an unresolved holiday, auction
  status, clock conversion, or incomplete bar fails closed.
- **Thrust.** Arm LONG when `pre_close > pre_open` and SHORT when
  `pre_close < pre_open`. Equality after tick-size normalization is a doji and
  gives no trade. `XAUUSD.DWX` tick volume and price are not represented as
  auction order flow.
- **Entry.** Inspect only the completed `[15:00,15:05)` and
  `[15:05,15:10)` `M5` bars. LONG requires the first qualifying close strictly
  above `pre_high`; SHORT requires the first qualifying close strictly below
  `pre_low`. A wick does not qualify. A completed break through the boundary
  opposite the frozen thrust cancels the auction date. Enter in the armed
  direction at the next `M5` open, at 15:05 or 15:10 London. No entry is allowed
  at or after 15:15, and there is at most one attempt per auction date.
- **Stop and time exit.** LONG has an immutable broker hard stop at `pre_low`;
  SHORT has one at `pre_high`. If the actual fill is at or beyond the stop, or
  initial monetary risk is non-positive, do not enter. There is no profit
  target, trail, breakeven move, scale, average, or partial close. Force-flat at
  the first tradable quote at or after 15:15 London. Resolve any stop/time
  collision from executable bid/ask tick chronology.
- **Sizing and cost.** Size once from the setfile's locked `RISK_FIXED` amount
  and actual fill-to-stop monetary distance; `RISK_PERCENT` is not authorized.
  Resolve current commission, notional conversion, spread, tick value, volume
  step, and broker stop constraints from governed runtime data rather than an
  indicative hard-coded value. Require
  `(commission + spread) / initial_monetary_risk <= 0.10R`; a missing input,
  unrepresentable lot step, or failed cost gate blocks entry.
- **Density and risk family.** The honest, untested prior is approximately 200
  completed trades/year for `XAUUSD.DWX` before auction holidays, dojis,
  unconfirmed breaks, and cost rejections. Other gold sleeves may share a
  portfolio exposure cap, but may not supply replacement signals to this card.

## Framework execution overrides

- The framework emergency/account kill switch disables entries and may flatten
  an open position before any strategy-managed exit.
- The default framework news pause remains active. It may block the scheduled
  auction entry, but it cannot create a trade or delay an entry beyond the two
  authorized confirmation bars.
- The framework Friday broker-time close remains enabled as an unreachable
  safety flatten after the card's same-session 15:15 London exit.
- No generic session entry, volume overlay, trailing stop, portfolio rescue,
  grid, martingale, pyramid, or loss-dependent sizing override is authorized.

## Exit precedence

1. Framework emergency/account kill-switch close.
2. Executed broker hard stop at the frozen opposite pre-auction extreme.
3. Card time exit at 15:15 London; after a restart or rejected close, retry
   immediately and before any new-entry evaluation.
4. Framework Friday safety close if a position somehow remains open.
5. Auction-calendar expiry, hash failure, or staleness blocks new entries only;
   it never cancels the broker stop or deterministic time close on an open
   trade.

## Runtime data dependencies

- Primary chart, signal, and order route: `XAUUSD.DWX`, `M5`. At build,
  generate exactly its per-symbol setfile for variant
  `LBMA_PM_BRK_BASELINE`; there are no sibling order routes.
- Tester account currency is USD. Runtime must supply current tick value,
  notional and account-currency conversion, volume step, stop level,
  commission schedule, and spread at the decision tick.
- Pin an IANA timezone database version covering `Europe/London`; log local,
  UTC, and broker clocks. Ambiguous or nonexistent conversions fail closed.
- Use a provenance-locked official PM-auction calendar with source URL,
  retrieval date, and hash, covering the prescribed study and
  `valid_through=2025-12-31`. A missing auction day must never be guessed.
- `XAUUSD.DWX` synchronized real-tick history must cover DEV 2018-2023, OOS
  2024, and untouched sealed 2025; dataset `valid_through=2025-12-31`. No
  external auction imbalance, centralized volume, or ML service is required.

## Falsification and requalification

- Freeze post-electronic-auction DEV 2018-2023, OOS 2024, and untouched sealed
  2025. Report LONG/SHORT, first/second confirmation bar, and every calendar
  year separately. Reject if one side, one year, or the former fixing regime is
  needed to carry the result.
- Apply governed nonzero commission and historical spread, then shift entry and
  exit one tick adversely. Reject if OOS or sealed expectancy is not positive
  or any admitted trade requires `cost_R > 0.10R`.
- Reject if correct auction holidays or London DST remove the result, if wicks
  are treated as closes, or if profitability requires an unobservable auction
  imbalance. The source mechanism alone cannot qualify the modern port.
- Dedup boundary: unlike `QM5_12792_gold-asian-drift` and
  `QM5_12974_xau-asia-session-drift`, this card is flat until a verified 15:00
  London PM-auction window, requires a same-thrust closed-bar break of the
  immediately preceding `M5` range, and exits at 15:15 London.
- Any change to auction membership or hashes, timezone mapping, range bar,
  thrust rule, confirmation bars, entry time, stop geometry, time exit, cost
  model, risk mode, symbol route, or variant identity requires a new binary,
  price/calendar reconciliation, and full portfolio requalification. An
  unresolved item is `BLOCKED`; Development may not fill it in.
