---
card_schema_version: 2
ea_id: QM5_20044
slug: gap-hilo-fade
status: DRAFT
g0_status: APPROVED
symbol: SP500.DWX
timeframe: M30
variant_id: GAP_HILO_FADE_BASELINE
execution_contract_ref: framework/registry/dxz23_execution_contracts.json#ea_id=20044
execution_contract_status: DRAFT
target_symbols: [SP500.DWX, WS30.DWX]
expected_trades_per_year_per_symbol: 85
g0_approval_reasoning: "R1 C-tier Sanches-Costa 2008 mirror, edge UNVERIFIED pending DEV; R2 mechanical M30 gap/HiLo fade with 85/year ordering prior to falsify; R3 .DWX M30/D1/session data; R4 deterministic RISK_FIXED, no ML"
last_updated: 2026-07-22
expected_pf: 1.2
expected_dd_pct: 15.0
source_id: SANCHES-COSTA-2008-GAPHILO
ml_required: false
r1_track_record: PASS
r1_reasoning: "Quality-tier C practitioner artifact with unreproduced author statistics; the transferred edge is an UNVERIFIED hypothesis to be validated only by the DEV 2018-2023 study."
r2_mechanical: PASS
r2_reasoning: "Fully mechanical M30 prior-close gap, ATR bounds, directional HiLo(10) and session-extreme confirmation, next-bar entry, frozen signal-bar stop, prior-close target, and 15:55 ET exit."
r3_data_available: PASS
r3_reasoning: "SP500.DWX and WS30.DWX real ticks can form session-aligned M30/D1 inputs, with the governed New York cash-session calendar, for DEV/OOS/sealed testing."
r4_ml_forbidden: PASS
r4_reasoning: "Deterministic session, price, ATR, geometry, and cost rules with RISK_FIXED sizing; no grid, martingale, stop-and-reverse, discretionary feature, or ML."
source_citations:
  - type: strategy_document_mirror
    citation: "Sanches, Eduardo; Costa, Isac. (2008). Estratégia Gap HiLo Índice v1.0. https://pt.scribd.com/doc/164360203/Estrategia-Gap-HiLo-Indice-V1-0"
    location: "August 2008 practitioner document for M30 WIN gap/HiLo rules, protective exits, session close, and an author-reported 2006-2008 sample."
    quality_tier: C
    role: primary
---

# Prior-cash-close gap HiLo inversion fade

## Source-defined rules

Sanches and Costa's 2008 practitioner document *Estratégia Gap HiLo Índice
v1.0*, recovered through the Scribd mirror at
https://pt.scribd.com/doc/164360203/Estrategia-Gap-HiLo-Indice-V1-0,
describes an `M30` Brazilian WIN strategy that conditions an index gap trade on
a ten-bar HiLo state change, uses protective stop/target rules, and closes
within the trading session. The document reports 182 gap-inversion trades over
489 sessions from 2006-07-03 through 2008-07-01, approximately 93 per year,
along with win and profit statistics.

The mirror is a quality-tier C practitioner artifact. Its performance claims
are **UNVERIFIED**, were not reproduced, and are not evidence for `.DWX`
instruments. Mapping WIN to US cash-index CFDs, defining the gap from the prior
16:00 ET cash close, ATR normalization, the exact session-extreme tolerance,
entry deadline, bounded stop distance, 1.25-to-1 feasibility gate, and cost
overlay are disclosed QM transfer rules rather than verbatim 2008 claims.

## QM interpretations

Every mechanic in this section is frozen under variant
`GAP_HILO_FADE_BASELINE` for `SP500.DWX` and `WS30.DWX`, independently, on
session-aligned `M30` bars.

- **Eligible sessions and gap.** Use a provenance-locked US cash-session
  calendar in DST-aware `America/New_York`. Require a previous and current
  normal session `[09:30,16:00)` with complete data; a holiday, scheduled early
  close, missing print, or ambiguous mapping fails closed. Freeze
  `prior_cash_close` from the previous 16:00 ET session close and
  `cash_open_today` from the first tradable 09:30 ET print. Define
  `gap = cash_open_today - prior_cash_close`; never substitute a broker-midnight
  D1 open.
- **Gap gate.** Construct session-anchored D1 OHLC bars and compute standard
  Wilder `ATR(20)` from completed bars through the prior eligible session,
  excluding today. This ATR choice is a QM normalization. Arm only when ATR is
  positive and `0.25 <= abs(gap) / ATR20_D1 <= 1.25`; equality at either bound
  qualifies. A positive gap arms SHORT only, a negative gap arms LONG only,
  and a zero gap gives no trade.
- **HiLo and extreme confirmation window.** Candidate signal bars are completed
  cash-session `M30` bars whose close timestamp is at or before 12:30 ET; the
  entry following the last eligible bar is therefore no later than 12:30 ET.
  For each candidate, calculate the simple average of the lows and separately
  the highs of the ten completed session-aligned `M30` bars immediately before
  it, excluding the candidate and carrying across prior eligible sessions as
  required. Missing members fail closed. Compute Wilder `ATR(14)` on completed
  bars through the candidate and freeze it at that close. For a gap up, the
  first qualifying candidate must close strictly below the prior-ten-low
  average and satisfy `close - session_low <= 0.10 * ATR14_M30`. For a gap down,
  it must close strictly above the prior-ten-high average and satisfy
  `session_high - close <= 0.10 * ATR14_M30`. `session_low` and `session_high`
  include all cash-session ticks through the candidate. Equality qualifies
  only for the 0.10 tolerance, not for the HiLo crossing.
- **Entry.** Enter once in the armed direction at the first tradable quote of
  the next `M30` open immediately following the first qualifying signal bar.
  No late entry, immediate open fade, pending opening-range order, retry,
  reversal, or second position is allowed. An existing position or a consumed
  symbol-date blocks the entry.
- **Stop, target, and time exit.** Freeze the signal bar's `ATR14_M30`, high,
  and low. SHORT stop is `signal_high + 0.25 * ATR14_M30`; LONG stop is
  `signal_low - 0.25 * ATR14_M30`. From the actual fill, skip unless the
  positive fill-to-stop price distance is within the inclusive interval
  `[0.75,1.50] * ATR14_M30`. The fixed profit target is
  `prior_cash_close`; it must be strictly favorable and at least
  `1.25 * fill_to_stop_distance` from the fill. A target crossed before entry
  or a fill at/beyond the stop fails geometry. Resolve stop/target ordering
  from executable bid/ask ticks. Force-flat at the first tradable quote at or
  after 15:55 ET. No trail, breakeven, partial, scale, averaging, grid,
  martingale, or stop-and-reverse is authorized.
- **Sizing and costs.** Backtests use only the setfile's locked `RISK_FIXED`
  monetary amount, sized once from actual fill-to-stop monetary risk;
  `RISK_PERCENT` is unauthorized. Resolve commission, observed spread, tick
  value, account-currency conversion, volume step, and broker stop constraints
  from governed runtime data, without invented commission, swap, or fill
  assumptions. Require
  `(commission + spread) / initial_monetary_risk <= 0.10R`; missing inputs,
  non-positive risk, an unrepresentable volume, or a failed constraint blocks
  entry.
- **Density and transfer boundary.** The mandated queue-ordering prior is 85
  trades/year/symbol. It is anchored only to the source author's UNVERIFIED
  native count of approximately 93/year and is neither a claim that all QM
  gates preserve that density nor a validation gate; the DEV study must measure
  the realized post-filter count and may falsify it. `SP500.DWX` is
  backtest-only pending any separate FTMO `US500` requalification. Both index
  variants are one correlated gap-fade risk family.

## Framework execution overrides

- The framework emergency/account kill switch disables entries and may flatten
  an open position before any strategy-managed exit.
- The default campaign news pause, spread guard, and loss controls remain
  enabled. A news pause may block the next-bar entry but may not create a
  signal, delay it to a later bar, or replace the required HiLo confirmation;
  a blocked entry consumes that symbol-date.
- The framework Friday broker-time close remains enabled as a safety flatten;
  the card's 15:55 ET close normally occurs first.
- No opening-range breakout, generic gap trade, alternate session entry,
  trailing, portfolio rescue, pyramid, loss-dependent sizing, or ML override is
  authorized.

## Exit precedence

1. Framework emergency/account kill-switch close.
2. Executed broker hard stop or fixed prior-cash-close target, ordered solely
   by executable bid/ask tick chronology rather than `M30` bar extrema.
3. Card force-flat at the first tradable quote at or after 15:55 ET; after a
   restart or rejected close, retry immediately before evaluating any entry.
4. Framework Friday safety close if a position somehow remains open.
5. Session-calendar, history, ATR, or cost-data failure blocks new entries
   only; it never cancels an existing broker stop, target, or mandatory close.

## Runtime data dependencies

- Generate **per-symbol setfiles at build** for `SP500.DWX` and `WS30.DWX`,
  both on `M30`, both bound to `GAP_HILO_FADE_BASELINE` and `RISK_FIXED`.
  Each setfile derives signals and routes orders only for its named symbol.
- Supply synchronized real ticks sufficient to construct ET cash-session
  `M30` bars and session-anchored D1 OHLC bars, plus symbol tick size, tick
  value, account-currency conversion, volume step, stop level, governed
  commission, and observed spread. Missing execution data fails closed.
- Pin an IANA timezone-database version covering `America/New_York` and a
  provenance-locked US cash-session/holiday/early-close calendar. Log local,
  UTC, and broker timestamps; ambiguous or nonexistent conversions fail closed.
- Histories and calendars must cover DEV 2018-2023, OOS 2024, and untouched
  sealed 2025 with dataset `valid_through=2025-12-31`.
- No broker-midnight daily-open substitution, external discretionary signal,
  swap forecast, or ML service is required or permitted.

## Falsification and requalification

- Freeze DEV 2018-2023, OOS 2024, and untouched sealed 2025. Report each
  symbol, gap direction, year, normalized-gap bucket, signal time, exit cause,
  and cost rejection separately. The transferred practitioner edge is
  validated only by DEV and must survive OOS and sealed confirmation before any
  later promotion.
- Run the preregistered ablation that removes only the HiLo(10) and
  session-extreme confirmation while preserving gap, session, exit, sizing,
  and cost rules. Reject or merge if the confirmation has no stable OOS lift,
  the result is an unconditional opening gap fade, or audited density falls
  below 60 trades/year/symbol.
- Apply governed nonzero commission and historical spread, then shift entry
  and exits one tick adversely. Reject if OOS or sealed expectancy is not
  positive, one symbol/year carries the result, correct holidays or DST remove
  it, or any admitted trade has `cost_R > 0.10R`.
- **Dedup boundary:** unlike any ORB or cash-open breakout logic, this card does
  not trade a break of an opening range and never enters at the opening print.
  It first requires a prior-close-to-open gap, then a direction-opposing
  HiLo(10) close plus a new-session-extreme confirmation, and fades toward the
  prior cash close. Without those two confirmations it is a duplicate gap fade
  and must be rejected or merged.
- Any change to session identity, timezone mapping, gap endpoints, ATR method
  or bounds, HiLo lookback, extreme tolerance, signal deadline, next-bar entry,
  stop geometry, 1.25 feasibility gate, target, 15:55 exit, cost model, risk
  mode, symbol route, or variant identity requires a new binary and full data,
  execution, dedup, and portfolio requalification. Backtests remain
  `RISK_FIXED`; no ML is allowed, and Development must mark any unresolved
  mechanic `BLOCKED` rather than invent it.
