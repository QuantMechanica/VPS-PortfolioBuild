---
card_schema_version: 2
type: strategy
strategy_id: WILLIAMS-MOP-WTI-WFLOWDOM-2026_S01
variant_id: WILLIAMS-MOP-WTI-WFLOWDOM-2026_S01
source_id: WILLIAMS-MOP-WTI-WFLOWDOM-2026
ea_id: QM5_41033
slug: wti-flow-dom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41033_wti-flow-dom_card.md
execution_contract_status: APPROVED
created: 2026-08-17
created_by: Research+Development
last_updated: 2026-08-17
g0_status: APPROVED
g0_decision: decisions/2026-08-17_wti_weekly_flow_dominance_g0.md
source_approval: decisions/2026-08-17_wti_weekly_flow_dominance_source_approval.md
source_author: "Larry R. Williams; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Larry R. Williams; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Williams (1999), Long-Term Secrets to Short-Term Trading, Wiley Trading; Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: practitioner_book
    citation: "Williams, L. R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading."
    location: "OWNER-supplied Tier-A extraction strategy-seeds/sources/SRC03/source.md; Pro-Go close/open decomposition in raw/probe_pp15-30.txt, PDF page 18"
    quality_tier: A
    role: close_to_open_public_flow_and_open_to_close_professional_flow_decomposition
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence and retrieval hash in strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: explicit_wti_commodity_carrier_and_own_return_continuation_scope
strategy_mechanic: exact-prior-monday-friday-wti-close-open-and-open-close-log-flow-sign-opposition-follow-absolute-dominant-component-entry-next-monday-friday-flat
sources:
  - "[[sources/WILLIAMS-MOP-WTI-WFLOWDOM-2026]]"
concepts:
  - "[[concepts/price-flow-decomposition]]"
  - "[[concepts/opposed-flow-dominance]]"
  - "[[concepts/weekly-return-reconciliation]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, price-flow-decomposition, time-series-momentum, opposed-flow-dominance, weekly-entry, friday-close, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410330000
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
q01_status: PASS
q02_status: NOT_ENQUEUED_CPU_CEILING
review_focus: "Falsify an exact-calendar direct-WTI opposed-flow dominance sleeve outside the certified XAU/SP500/NDX/XNG book. Verify all ten completed endpoints, strict opposition, reconciliation, dominant direction, no late/repeated Monday entry, and Friday flattening; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_weekday_sequence, normalized_energy_label, completed_close_open_endpoints, strict_flow_sign_opposition, flow_reconciliation, dominant_component_direction, monday_decision_clock, weekly_attempt_state, no_current_bar_leakage, no_late_restart_entry, risk_mode_dual, friday_close_enabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 complete OWNER-supplied Tier-A flow-decomposition extraction plus complete-read peer-reviewed WTI carrier lineage with disclosed conjunction risk; R2 exact sequence, endpoints, opposition, reconciliation, dominant direction, timing, retry, risk, and lifecycle; R3 native XTI D1 only; R4 deterministic arithmetic without banned signal or trained logic; canonical dedup raised expected family neighbors and manual review fixed the direction truth table and all material boundaries."
---

# QM5_41033 WTI Weekly Opposed-Flow Dominance

## Hypothesis

A completed WTI week whose close-to-open public flow opposes its open-to-close
session flow contains an observable information-time disagreement. The larger
absolute component determines the sign of the fully reconciled weekly return.
Following that dominant component for the next exact week may isolate a
structural continuation state while excluding weeks in which both channels
already agree.

This is a falsifiable price-flow and calendar translation. The sources do not
test the exact five-session opposition gate, absolute dominance rule, fixed
Monday clock, WTI-only continuous CFD, Friday lifecycle, or QM portfolio.

## Source Traceability And Claim Boundary

The sole governed composite packet is
`strategy-seeds/sources/WILLIAMS-MOP-WTI-WFLOWDOM-2026/source.md`, approved
before card extraction in
`decisions/2026-08-17_wti_weekly_flow_dominance_source_approval.md` at commit
`1447c6ba8`.

Williams supplies the two daily price-flow objects: prior close to current
open and current open to current close. He discusses their separate averages,
divergences, and crossings. Moskowitz, Ooi, and Pedersen establish WTI as a
commodity-futures carrier and own-return continuation as a separate source
family; they do not validate this information-time opposition rule.

The exact completed-week sequence, separate five-session log sums, strict
opposition gate, total-return reconciliation, dominant-component direction,
broker-calendar normalization, Monday opening grace, continuous-CFD carrier,
Friday close, hard stop, fixed-dollar risk, spread cap, and attempt ledger are
disclosed QM choices. No source return, alpha, coefficient, significance,
trade density, drawdown, cost, CFD equivalence, decorrelation, or portfolio
result transfers.

## Source-Defined Rules

- Williams defines the two daily information-time components as prior close
  to current open and current open to current close, and treats divergences
  between those components as potentially informative.
- Moskowitz, Ooi, and Pedersen define own-completed-return continuation and
  include WTI futures in the tested commodity universe.
- Neither source defines a five-session WTI aggregation, strict opposition
  gate, dominant-component comparison, CFD session-label policy, ATR stop,
  spread ceiling, Monday attempt ledger, or Friday exit.

## QM Interpretations

- The five-session exact week, opposition-only eligibility, telescoping
  reconciliation, and direction from `sign(total_flow)` are pre-result QM
  mechanizations, not source findings.
- `XTIUSD.DWX` is a continuous-CFD carrier rather than a rolled NYMEX futures
  return series. Same-day versus uniform `+1` D1 label normalization is an
  execution adaptation and never repairs an individual missing session.
- The 180-minute entry grace, persistent attempt, `ATR(20) * 3.0` stop,
  1,500-point spread ceiling, fixed-dollar risk, Friday 21 close, and eight-day
  stale guard are locked safety choices. They convey no efficacy claim.

## Non-Duplicate Decision

The deterministic pre-allocation checker scanned 4,520 EA-registry rows and
616 card files. It found no exact match and raised three fuzzy neighbors.
Manual review fixes the load-bearing boundaries:

- `QM5_41032_wti-flow-div` uses the same completed-week endpoints and strict
  opposition state but always follows session flow. This card follows the
  reconciled total/dominant component: it agrees only when session magnitude
  dominates, takes the opposite side when overnight magnitude dominates, and
  is flat on exact equality.
- `QM5_41029_wti-flow-agree` trades only when both components share a strict
  sign. This card is flat on every agreement state.
- `QM5_41022_wti-wdual-mom` splits a close-to-close week into early and late
  temporal segments. This card decomposes every session by close-to-open and
  open-to-close information time.
- `QM5_13049_xti-1w-mom-vol` uses a rolling five-D1 magnitude threshold and
  realized-volatility rank. This card has no magnitude or volatility gate and
  requires exact-calendar internal opposition.
- `QM5_12784_progo-xti` compares fourteen-day signed-value averages, trades
  line crossings on any D1 bar, and exits on an opposite crossing or time.
  This card uses two fixed five-session log sums and a Monday-Friday lifecycle.
- `QM5_10316_overnight-intraday-reversal` ranks a daily multi-asset basket and
  closes in the same session; this card owns one WTI weekly position.
- `QM5_21520_xng-flow-mom` is an XNG close-return continuation rule gated by a
  tick-volume rank. `QM5_12567_cum-rsi2-commodity` is a long-only oscillator
  pullback.

Verdict:
`CLEAN_WTI_WEEKLY_OPPOSED_FLOW_DOMINANCE_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Host and target: exact `XTIUSD.DWX`.
- Timeframe: D1; magic slot 0; planned magic `410330000`.
- Decision: first executable tick of an eligible broker Monday.
- Signal: opposite strict signs for the completed prior week's close-to-open
  and open-to-close sums; direction equals reconciled total-flow sign.
- Normal exit: framework Friday close at broker hour 21.
- Expected cadence: approximately 15-30 completed positions/year after
  opposition and holiday exclusions.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Formula

For completed prior-week sessions `d`, oldest Monday through newest Friday:

```text
overnight_flow = sum(log(Open[d] / Close[prior_session]))
session_flow   = sum(log(Close[d] / Open[d]))
week_return    = log(PriorFridayClose / PrecedingFridayClose)
total_flow     = overnight_flow + session_flow

require overnight_flow * session_flow < 0
require abs(total_flow - week_return) <= 1e-10

total_flow > 0 => BUY
total_flow < 0 => SELL
otherwise      => flat
```

The telescoping identity proves that total-flow sign is the sign of the
component with larger absolute magnitude under strict opposition. The current
Monday price enters no signal term.

## Rules

The rules below are the complete authorized baseline. No magnitude,
volatility, month, event, curve, volume, oscillator, range, breakout, moving
line, crossover, or external-data signal filter is authorized.

### 4. Entry Rules

1. Evaluate entry only on a new `XTIUSD.DWX` D1 bar.
2. Require the broker clock, not the raw D1 label, to be Monday.
3. Support native same-day D1 labels and the governed factory energy
   convention that labels a session with the preceding calendar date. When
   the current raw label is 24-48 hours behind the broker date, normalize it
   and all six completed labels by one uniform `+1` calendar day. Apply no
   other offset, holiday shift, nearest-bar substitution, or per-bar repair.
4. Read exactly six immediately preceding completed D1 bars. After uniform
   normalization require them, newest first, to be prior Friday, Thursday,
   Wednesday, Tuesday, Monday, and the preceding Friday.
5. Require their normalized dates to be exactly 3, 4, 5, 6, 7, and 10
   calendar days before the current broker Monday. A missing or shifted
   holiday session consumes the Monday flat; it is never substituted.
6. Derive the attempt key as the exact current broker Monday `yyyymmdd`. If no
   durable attempt exists, persist it before history validation, signal,
   news, spread, quote, ATR, sizing, or order gates. Never retry the Monday.
7. Compute elapsed time since executable session open as broker time minus the
   raw D1 label modulo one day. If elapsed time is negative or greater than
   180 minutes, consume the attempt flat and never backfill after restart.
8. For completed shifts 5 through 1, require positive finite `Open[shift]`,
   `Close[shift]`, and `Close[shift+1]`.
9. Compute the two flow sums, the Friday-to-Friday `week_return`, and
   `total_flow` exactly as declared. Require finite arithmetic and
   `abs(total_flow-week_return) <= 1e-10`.
10. Require strict sign opposition. BUY only when `total_flow > 0`; SELL only
    when `total_flow < 0`. Agreement, component equality, exact zero, invalid
    arithmetic, or failed reconciliation consumes the week flat.
11. Require completed-bar `ATR(20,D1)` and place one frozen hard stop at
    `3.0 * ATR`. Use no take-profit.
12. Require no owned position, a valid positive quote, and no genuinely
    positive spread wider than 1,500 points. A zero modeled `.DWX` spread is
    valid.
13. Use magic slot 0 only. Signal magnitude never scales risk. No pending
    order, second entry, scale-in, grid, martingale, or pyramid exists.

### 5. Exit Rules

1. Framework Friday close is enabled and closes owned exposure at broker hour
   21. Trade management and close logic remain reachable before entry gates.
2. Close exposure that survives into a later broker week at its first
   observable D1 boundary. This is stale repair, not the ordinary exit.
3. Close after eight elapsed calendar days as a final stale guard.
4. Close owned exposure with invalid open time, volume, price, symbol, magic,
   or direction.
5. The frozen broker hard stop and framework kill switch remain authoritative.
6. No target, opposite-signal exit, trailing stop, break-even move, partial
   exit, discretionary close, or Friday-close override is authorized.

### 6. Filters (No-Trade Module)

- Exact chart symbol `XTIUSD.DWX`, exact period D1, EA ID `41033`, slot 0.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes are OFF because the signal uses native completed prices and
  the fixed weekly lifecycle must not be altered by an event mode.
- Friday close is ON at broker hour 21 and is load-bearing.
- Entry spread must be finite and no greater than 1,500 points when genuinely
  positive; modeled zero spread is accepted.
- History, label normalization, weekday continuity, opening grace,
  reconciliation, quote, ATR, and risk sizing must all be valid.
- Failure at any fallible gate after attempt persistence consumes the current
  Monday. No same-week retry is allowed.

### 7. Trade Management Rules

- Own at most one `XTIUSD.DWX` position under magic `410330000`.
- Freeze the original broker hard stop; never widen, trail, or remove it.
- Run malformed and stale ownership repair on every tick before entry logic.
- Do not add to, pyramid, grid, hedge, partially close, or reverse exposure.
- Persist the last attempted broker-Monday key in terminal global state so a
  restart cannot create a second weekly attempt.
- Recover timing from the owned position or deal record; never infer a new
  entry after attachment.

## Risk

- Backtest mode only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Risk budget applies to one WTI position and is sized from the frozen stop
  distance through the V5 risk helper.
- Baseline stop: `3.0 * ATR(20,D1)` from completed data.
- No take-profit and no signal-magnitude sizing.
- Invalid stop distance, tick value, tick size, volume step, minimum volume,
  or computed lot size consumes the week without an order.
- WTI gaps, continuous-CFD basis and financing, energy session-label mapping,
  and the untested dominance translation are material risks.
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
| `strategy_reconcile_tolerance` | 1e-10 | telescoping identity guard |
| `qm_friday_close_enabled` | true | ordinary weekly exit |
| `qm_friday_close_hour_broker` | 21 | ordinary exit clock |

No parameter sweep, after-result threshold, weekday substitution, component
resize, sign reversal, or lifecycle rescue is authorized.

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
| exact symbol/period, attempt, history, component sums, opposition, reconciliation, spread, ATR, sizing | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed and stale ownership repair | Trade Management | `Strategy_ManageOpenPosition` |
| Friday lifecycle | Trade Close | `Strategy_ExitSignal` returns false; framework Friday close owns ordinary exit |
| kill switch, session ownership, risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | `Strategy_NewsFilterHook` returns false; both modes OFF |

## Framework Execution Overrides

- `qm_news_temporal=QM_NEWS_TEMPORAL_OFF`,
  `qm_news_compliance=QM_NEWS_COMPLIANCE_NONE`, and legacy news mode OFF.
- `qm_friday_close_enabled=true` and
  `qm_friday_close_hour_broker=21`; this ordinary exit is load-bearing.
- Backtest risk is exclusively `RISK_FIXED=1000` with `RISK_PERCENT=0` and
  `PORTFOLIO_WEIGHT=1`.
- Standard framework kill-switch, magic resolution, risk sizing, stop
  normalization, order management, and close-reason routing remain active.

## Exit Precedence

1. Framework kill switch and broker hard stop.
2. Malformed/wrong-side owned-position repair.
3. First observable later-week D1 boundary and eight-day stale repair.
4. Ordinary framework Friday close at broker hour 21.
5. No signal reversal, target, trail, break-even, or partial-close path.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` D1 OHLC/time, broker clock, executable quote, modeled
spread, symbol contract metadata, completed-bar ATR, positions, deal history,
and terminal global variables only. No external file, API, futures chain,
inventory, volume, open interest, analyst forecast, or portfolio state enters
the signal.

## Falsification And Requalification

Any change to the carrier, timeframe, weekday sequence, label normalization,
flow endpoints, opposition gate, reconciliation tolerance, direction map,
entry grace, attempt semantics, stop, spread, sizing, Friday exit, or stale
guard creates a new execution identity and requires a new card/binary plus
full pipeline requalification. A failed Q02 result is retired rather than
repaired by post-result filtering or direction reversal.

## Kill Criteria

Retire rather than tune when any of the following occurs:

- fewer than five completed positions per full post-warm-up year at Q02;
- zero trades or nonpositive governed economics;
- a trade on a non-Monday clock or after the 180-minute grace;
- a holiday-shifted or nonconsecutive weekday sequence;
- current-bar price leakage into any signal term;
- entry when the two completed component signs agree or equal zero;
- failed total-flow/Friday-to-Friday reconciliation;
- direction different from the reconciled total-flow sign;
- more than one attempt for an exact broker Monday;
- survival past the governed Friday or stale lifecycle without repair;
- wrong risk mode, nondeterministic result, or registry/magic mismatch.

No weak result may be rescued by accepting agreement weeks, always following
session or overnight flow, adding a volatility or magnitude threshold, moving
the entry clock, or disabling Friday close.

## Validation Plan

Q01 must prove:

1. synthetic weekday sequences accept only exact prior Monday-through-Friday
   history plus the preceding Friday anchor and reject holiday gaps;
2. opposed components with positive total map to BUY and negative total map
   to SELL, including cases where session and overnight dominate separately;
3. agreement states, exact equality, exact zero, invalid prices, and failed
   reconciliation remain flat;
4. all ten endpoints telescope to the completed Friday-to-Friday return and
   exclude the current Monday bar;
5. the persistent attempt prevents same-Monday retry after failure/restart;
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
| v1 | 2026-08-17 | initial WTI opposed-flow dominance extraction | G0 | APPROVED |
| v1-build | 2026-08-17 | deterministic V5 implementation and fixed-risk preset | Q01 | PASS |
| v1-q02-hold | 2026-08-17 | exact-path capacity gate found 7 running T1-T10 tester roots at the 7-terminal ceiling before any queue command | Q02 | NOT_ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-17 | APPROVED | `decisions/2026-08-17_wti_weekly_flow_dominance_g0.md` |
| Q01 Build Validation | 2026-08-17 | PASS | `framework/EAs/QM5_41033_wti-flow-dom/SPEC.md` |
| Q02 Baseline Screening | 2026-08-17 | NOT_ENQUEUED_CPU_CEILING | `docs/ops/evidence/2026-08-17_qm5_41033_wti_flowdom_q01_cpu_ceiling_stop.md` |

## Safety Boundary

This card authorizes a branch-only non-live build, strict Q01 validation, one
D1 `RISK_FIXED` backtest setfile, and one paced Q02 enqueue if CPU capacity
permits. It does not authorize a manual backtest, tester control, live/demo/
shadow/stress/optimization preset, AutoTrading, `T_Live`, a deploy or T_Live
manifest, portfolio-gate change, portfolio admission, or correlation waiver.
