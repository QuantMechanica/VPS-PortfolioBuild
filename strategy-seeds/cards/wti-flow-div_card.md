---
card_schema_version: 2
type: strategy
strategy_id: WILLIAMS-MOP-WTI-WFLOWDIV-2026_S01
variant_id: WILLIAMS-MOP-WTI-WFLOWDIV-2026_S01
source_id: WILLIAMS-MOP-WTI-WFLOWDIV-2026
ea_id: QM5_41032
slug: wti-flow-div
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41032_wti-flow-div_card.md
execution_contract_status: APPROVED
created: 2026-08-16
created_by: Research+Development
last_updated: 2026-08-16
g0_status: APPROVED
g0_decision: decisions/2026-08-16_wti_weekly_flow_divergence_g0.md
source_approval: decisions/2026-08-16_wti_weekly_flow_divergence_source_approval.md
source_author: "Larry R. Williams; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Larry R. Williams; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Williams (1999), Long-Term Secrets to Short-Term Trading, Wiley Trading; Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: practitioner_book
    citation: "Williams, L. R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading."
    location: "OWNER-supplied Tier-A extraction at strategy-seeds/sources/SRC03/source.md; Pro-Go close/open decomposition in raw/probe_pp15-30.txt, PDF page 18"
    quality_tier: A
    role: close_to_open_public_flow_and_open_to_close_professional_flow_decomposition
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence and retrieval hash in strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: explicit_wti_commodity_carrier_and_adverse_scope_discipline
strategy_mechanic: exact-prior-monday-friday-wti-close-open-and-open-close-log-flow-sign-opposition-follow-session-entry-next-monday-friday-flat
sources:
  - "[[sources/WILLIAMS-MOP-WTI-WFLOWDIV-2026]]"
concepts:
  - "[[concepts/price-flow-decomposition]]"
  - "[[concepts/public-professional-flow-divergence]]"
  - "[[concepts/weekly-session-following]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, price-flow-decomposition, flow-divergence, weekly-entry, friday-close, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410320000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 15-30 completed WTI positions per full post-warm-up year after strict component opposition and holiday exclusions; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 22
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: NOT_RUN
q02_status: NOT_ENQUEUED
review_focus: "Falsify an exact-calendar WTI weekly public/professional-flow divergence sleeve outside the certified XAU/SP500/NDX/XNG book. Verify all ten completed close/open endpoints, strict component opposition, session-following direction, no late or repeated Monday entry, and Friday flattening; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_weekday_sequence, normalized_energy_label, completed_close_open_endpoints, strict_flow_sign_opposition, session_following_direction, monday_decision_clock, weekly_attempt_state, no_current_bar_leakage, no_late_restart_entry, risk_mode_dual, friday_close_enabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 complete OWNER-supplied Tier-A flow-decomposition extraction plus complete-read peer-reviewed WTI carrier lineage with disclosed conjunction risk; R2 exact sequence, endpoints, opposition, direction, timing, retry, risk, and lifecycle; R3 native XTI D1 only; R4 deterministic arithmetic without banned signal or trained logic; canonical dedup raised the expected agreement-family neighbor and manual review fixed the disjoint eligible state and all material boundaries."
---

# QM5_41032 WTI Weekly Public/Professional Flow Divergence

## Hypothesis

A completed WTI week whose close-to-open public flow opposes its open-to-close
session flow may contain a structural disagreement between overnight repricing
and the liquid session. The next week may follow the session component rather
than the overnight component. The candidate enters on the next genuine Monday
only when the two completed weekly sums have opposite strict signs, follows the
session sign, and closes Friday.

This is a falsifiable price-flow and calendar translation. The sources do not
test this exact five-session opposition state, fixed Monday clock, WTI-only
continuous CFD, session-following direction, Friday lifecycle, or the QM
portfolio.

## Source Traceability And Claim Boundary

The sole governed composite packet is
`strategy-seeds/sources/WILLIAMS-MOP-WTI-WFLOWDIV-2026/source.md`, approved
before card extraction in
`decisions/2026-08-16_wti_weekly_flow_divergence_source_approval.md` at commit
`ae0550fda`.

Williams supplies the two daily price-flow objects: prior close to current open
and current open to current close. He frames them as public and professional
flows and discusses averages, divergences, and crossings. Moskowitz, Ooi, and
Pedersen establish WTI as a commodity-futures carrier and own-return
continuation as a separate source family; they do not validate this
information-time opposition rule.

The exact completed-week sequence, separate five-session log sums, strict
opposition gate, session-following direction, broker-calendar normalization,
Monday opening grace, continuous-CFD carrier, Friday close, hard stop,
fixed-dollar risk, spread cap, and attempt ledger are disclosed QM choices. No
source return, alpha, coefficient, significance, trade density, drawdown, cost,
CFD equivalence, decorrelation, or portfolio result transfers.

## Non-Duplicate Decision

The deterministic pre-allocation checker scanned 4,519 EA-registry rows and
615 root-card files. It found no exact match and raised two fuzzy neighbors.
Manual review fixes the load-bearing boundaries:

- `QM5_41029_wti-flow-agree` uses the same completed-week endpoints but trades
  only when the two component signs agree and follows their common sign. This
  card is flat on every agreement state, trades only strict opposition, and
  follows the session component.
- `QM5_12784_progo-xti` compares fourteen-day signed-value averages, trades
  line crossings on any D1 bar, and exits on an opposite crossing or time.
  This card uses two fixed five-session log sums, no moving line or crossover,
  and a Monday-Friday lifecycle.
- `QM5_41030_xauxag-flowdiv` subtracts silver flows from gold flows and trades
  an equal-notional two-metal basket. This card performs no cross-metal
  calculation and owns one direct WTI position.
- `QM5_21520_xng-flow-mom` is a five-close XNG continuation rule gated by a
  40-window tick-volume rank. It has none of this card's carrier, endpoints,
  opposition state, or exact calendar lifecycle.
- `QM5_12567_cum-rsi2-commodity` is a long-only oscillator pullback rather
  than a symmetric structural WTI flow rule.

Verdict:
`CLEAN_WTI_WEEKLY_PUBLIC_PROFESSIONAL_FLOW_DIVERGENCE_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Host and target: exact `XTIUSD.DWX`.
- Timeframe: D1; magic slot 0; planned magic `410320000`.
- Decision: first executable tick of an eligible broker Monday.
- Signal: opposite strict signs for the completed prior week's close-to-open
  and open-to-close log-return sums; direction equals session-flow sign.
- Normal exit: framework Friday close at broker hour 21.
- Expected cadence: approximately 15-30 completed positions/year after
  opposition and holiday exclusions.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Rules

The rules below are the complete authorized baseline. No magnitude,
volatility, month, event, curve, volume, oscillator, range, breakout, moving
line, crossover, or external-data signal filter is authorized.

### 4. Entry Rules

1. Evaluate the entry path only on a new `XTIUSD.DWX` D1 bar.
2. Require the broker clock, not the raw D1 label, to be Monday.
3. Support native same-day D1 labels and the governed factory energy
   convention that labels a session with the preceding calendar date. When the
   current raw label is 24-48 hours behind the broker date, normalize it and
   all six completed labels by one uniform `+1` calendar day. Apply no other
   offset, holiday shift, nearest-bar substitution, or per-bar repair.
4. Read exactly six immediately preceding completed D1 bars. After uniform
   normalization require them, newest first, to be prior Friday, Thursday,
   Wednesday, Tuesday, Monday, and the preceding Friday.
5. Require their normalized dates to be exactly 3, 4, 5, 6, 7, and 10
   calendar days before the current broker Monday. A missing or shifted holiday
   session consumes the Monday flat; it is never substituted.
6. Derive the attempt key as the exact current broker Monday `yyyymmdd`. If no
   durable attempt exists, persist it before history validation, return
   calculation, news, spread, quote, ATR, sizing, or order gates. Never retry
   the Monday.
7. Compute elapsed time since executable session open as broker time minus the
   raw D1 label modulo one day. If elapsed time is negative or greater than 180
   minutes, consume the attempt flat and never backfill after restart.
8. For completed shifts 5 through 1, require positive finite `Open[shift]`,
   `Close[shift]`, and `Close[shift+1]`.
9. Compute
   `overnight_flow = sum(shift=5..1, log(Open[shift]/Close[shift+1]))` and
   `session_flow = sum(shift=5..1, log(Close[shift]/Open[shift]))`. The current
   Monday price enters neither sum.
10. BUY only when `session_flow > 0` and `overnight_flow < 0`. SELL only when
    `session_flow < 0` and `overnight_flow > 0`. Agreement, exact zero, invalid
    arithmetic, or every other state consumes the week flat.
11. Require a valid completed-bar `ATR(20,D1)` and place one frozen hard stop
    at `3.0 * ATR`. Use no take-profit.
12. Require no owned position, a valid positive quote, and no genuinely
    positive spread wider than 1,500 points. A zero modeled `.DWX` spread is
    valid.
13. Use magic slot 0 only. Signal magnitude never scales risk. No pending
    order, second entry, scale-in, grid, martingale, or pyramid exists.

### 5. Exit Rules

1. Framework Friday close is enabled and closes owned exposure at broker hour
   21. Trade management and close logic remain reachable before every
   entry-only gate.
2. Close exposure that survives into a later broker week at its first
   observable D1 boundary. This is stale repair, not the ordinary exit.
3. Close after eight elapsed calendar days as a final stale guard.
4. Close owned exposure with invalid open time, volume, price, symbol, magic,
   or direction.
5. The frozen broker hard stop and framework kill switch remain authoritative.
6. No target, opposite-signal exit, trailing stop, break-even move, partial
   exit, discretionary close, or Friday-close override is authorized.

### 6. Filters (No-Trade Module)

- Exact chart symbol: `XTIUSD.DWX`; exact period: D1; EA ID `41032`; slot 0.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes are OFF because the signal uses native completed prices and
  the fixed weekly lifecycle must not be altered by an event mode.
- Friday close is ON at broker hour 21 and is load-bearing.
- Entry spread must be finite and no greater than 1,500 points when genuinely
  positive; modeled zero spread is accepted.
- History, label normalization, weekday continuity, opening grace, quote, ATR,
  and risk sizing must all be valid.
- Failure at any fallible gate after attempt persistence consumes the current
  Monday. No same-week retry is allowed.

### 7. Trade Management Rules

- Own at most one `XTIUSD.DWX` position under magic `410320000`.
- Freeze the original broker hard stop; never widen, trail, or remove it.
- Run malformed and stale ownership repair on every tick before entry-only
  logic.
- Do not add to, pyramid, grid, hedge, partially close, or reverse an owned
  position.
- Persist the last attempted broker-Monday key in terminal global state so a
  restart cannot create a second weekly attempt.
- Recover entry timing from the owned position or deal record; never infer a
  new entry after attachment.

## Risk

- Backtest mode only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Risk budget applies to the one WTI position and is sized from the frozen stop
  distance through the V5 risk helper.
- Baseline stop: `3.0 * ATR(20,D1)` from completed data.
- No take-profit and no signal-magnitude sizing.
- Invalid stop distance, tick value, tick size, volume step, minimum volume, or
  computed lot size consumes the week without an order.
- WTI gaps, continuous-CFD basis and financing, energy session-label mapping,
  and the untested dominance of session over overnight flow are material risks.
- This card creates no live, demo, shadow, stress, or optimization preset.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_atr_period` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.0 | frozen hard-stop distance |
| `strategy_max_spread_points` | 1500 | entry cost guard |
| `strategy_entry_grace_minutes` | 180 | restart-safe Monday boundary |
| `strategy_max_hold_days` | 8 | stale repair only |
| `friday_close_enabled` | true | ordinary weekly exit |
| `friday_close_hour_broker` | 21 | ordinary exit clock |

No parameter sweep, after-result threshold, weekday substitution, component
resize, sign reversal, or lifecycle rescue is authorized by this card.

## Data Requirements

- Native `XTIUSD.DWX` D1 OHLC and tick timestamps from the registered factory
  history route.
- Native broker clock, symbol quote and properties, position state, deal
  history, and terminal global variables.
- No external market-data API, futures curve, COT positioning, EIA series,
  analyst forecast, CSV feed, or manually maintained event calendar.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact symbol/period, attempt, history, component sums, opposition, spread, ATR, sizing | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed and stale ownership repair | Trade Management | `Strategy_ManageOpenPosition` |
| Friday lifecycle | Trade Close | `Strategy_ExitSignal` returns false; framework Friday close owns the ordinary exit |
| kill switch, session ownership, risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | `Strategy_NewsFilterHook` returns false; both modes OFF |

## Kill Criteria

Retire rather than tune when any of the following occurs:

- fewer than five completed positions per full post-warm-up year at Q02;
- zero trades or nonpositive governed economics;
- a trade on a non-Monday clock or after the 180-minute grace;
- a holiday-shifted or nonconsecutive weekday sequence;
- current-bar price leakage into either component sum;
- entry when the two completed component signs agree or equal zero;
- direction opposite the completed session-flow sign;
- more than one attempt for an exact broker Monday;
- survival past the governed Friday or stale lifecycle without repair;
- wrong risk mode, nondeterministic result, or registry and magic mismatch.

No weak result may be rescued by accepting agreement weeks, reversing the
session component, adding a volatility or magnitude filter, moving the entry
clock, or disabling Friday close.

## Validation Plan

Q01 must prove:

1. synthetic weekday sequences accept only exact prior Monday-through-Friday
   history plus the preceding Friday anchor and reject holiday gaps;
2. positive-session and negative-overnight flow maps to BUY, while the exact
   opposite maps to SELL;
3. both agreement states, exact equality, invalid prices, and same-sign flows
   remain flat;
4. signal arithmetic uses all ten intended completed endpoints and excludes
   the current Monday bar;
5. the persistent attempt prevents same-Monday retry after every downstream
   failure and restart;
6. sizing uses fixed-dollar risk and the frozen completed-bar ATR stop;
7. Friday and stale repair paths remain reachable independently of entry
   gates; and
8. strict compile, card lint, build checks, setfile schema, magic resolver,
   reference tests, and static P1 validation pass.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-16 | initial WTI weekly flow-divergence extraction | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-16 | APPROVED | `decisions/2026-08-16_wti_weekly_flow_divergence_g0.md` |
| Q01 Build Validation | - | NOT_RUN | - |
| Q02 Baseline Screening | - | NOT_ENQUEUED | - |

## Safety Boundary

This card authorizes a branch-only non-live build, strict Q01 validation, one
D1 `RISK_FIXED` backtest setfile, and one paced Q02 enqueue if CPU capacity
permits. It does not authorize a manual backtest, tester control,
live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`, a deploy or
T_Live manifest, portfolio-gate change, portfolio admission, or correlation
waiver.

