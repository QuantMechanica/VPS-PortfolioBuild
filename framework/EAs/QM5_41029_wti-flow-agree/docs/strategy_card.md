---
card_schema_version: 2
type: strategy
strategy_id: WILLIAMS-MOP-WTI-WFLOW-2026_S01
variant_id: WILLIAMS-MOP-WTI-WFLOW-2026_S01
source_id: WILLIAMS-MOP-WTI-WFLOW-2026
ea_id: QM5_41029
slug: wti-flow-agree
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41029_wti-flow-agree_card.md
execution_contract_status: APPROVED
created: 2026-08-16
created_by: Research+Development
last_updated: 2026-08-16
g0_status: APPROVED
g0_decision: decisions/2026-08-16_wti_weekly_flow_agreement_g0.md
source_approval: decisions/2026-08-16_wti_weekly_flow_agreement_source_approval.md
source_author: "Larry R. Williams; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Larry R. Williams; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Williams (1999), Long-Term Secrets to Short-Term Trading, Wiley Trading; Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: practitioner_book
    citation: "Williams, L. R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading."
    location: "OWNER-supplied Tier-A extraction at strategy-seeds/sources/SRC03/source.md; Pro-Go close/open decomposition in raw/probe_pp15-30.txt, PDF page 18"
    quality_tier: A
    role: close_to_open_and_open_to_close_price_flow_decomposition
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence and retrieval hash in strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: own_return_sign_continuation_family_and_explicit_wti_membership
strategy_mechanic: exact-prior-monday-friday-wti-close-open-and-open-close-log-flow-sign-agreement-entry-next-monday-friday-flat
sources:
  - "[[sources/WILLIAMS-MOP-WTI-WFLOW-2026]]"
concepts:
  - "[[concepts/price-flow-decomposition]]"
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/weekly-flow-agreement]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, price-flow-decomposition, time-series-momentum, weekly-flow-agreement, weekly-entry, friday-close, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410290000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 15-30 completed WTI positions per full post-warm-up year after strict flow-sign agreement and holiday exclusions; Q02 must prove at least five/year or retire."
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
q02_status: NOT_ENQUEUED
review_focus: "Falsify an exact-calendar WTI weekly price-flow agreement sleeve outside the certified XAU/SP500/NDX/XNG book. Verify all ten completed close/open endpoints, strict component-sign agreement, no late/repeated Monday entry, and Friday flattening; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_weekday_sequence, normalized_energy_label, completed_close_open_endpoints, strict_flow_sign_agreement, monday_decision_clock, weekly_attempt_state, no_current_bar_leakage, no_late_restart_entry, risk_mode_dual, friday_close_enabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 OWNER-supplied Tier-A flow-decomposition extraction plus complete-read peer-reviewed WTI continuation lineage with disclosed conjunction risk; R2 exact sequence, endpoints, component sums, agreement, timing, retry, and lifecycle; R3 native XTI D1 only; R4 deterministic arithmetic without banned signal or trained logic; canonical dedup found one expected weekly family neighbor and manual review fixed all material boundaries."
---

# QM5_41029 WTI Weekly Flow-Agreement Continuation

## Hypothesis

A completed WTI week whose close-to-open flow and open-to-close session flow
both point in the same direction may reflect broader information agreement
than a close-to-close move concentrated in only one component. The candidate
sums those components separately across one exact completed Monday-through-
Friday week, enters on the next Monday only when both signs agree, and closes
by Friday.

This is a falsifiable price-flow and calendar translation. The sources do not
test this exact five-session agreement state, fixed Monday clock, WTI-only
continuous CFD, Friday lifecycle, or the QM portfolio.

## Source Traceability And Claim Boundary

The sole governed composite packet is
`strategy-seeds/sources/WILLIAMS-MOP-WTI-WFLOW-2026/source.md`, approved before
card extraction in
`decisions/2026-08-16_wti_weekly_flow_agreement_source_approval.md` at commit
`ed9953241`.

Williams supplies the two daily price-flow objects: prior close to current
open and current open to current close. His Pro-Go construction uses
fourteen-day averages, crossings, and divergences. Moskowitz, Ooi, and
Pedersen supply own-return-sign continuation and WTI membership in a
commodity-futures universe; their implementation uses rolled futures excess
returns, monthly horizons, volatility scaling, and diversified portfolios.

The exact week sequence, separate five-session log sums, strict agreement
gate, broker-calendar normalization, Monday opening grace, continuous-CFD
carrier, Friday close, hard stop, fixed-dollar risk, spread cap, and attempt
ledger are disclosed QM choices. No source return, alpha, coefficient,
significance, trade density, drawdown, cost, CFD equivalence, decorrelation,
or portfolio result transfers.

## Non-Duplicate Decision

The deterministic pre-allocation checker scanned 4,516 EA-registry rows and
612 root-card files. It found no exact match and raised one expected fuzzy
family match. Manual review fixes the load-bearing boundaries:

- `QM5_12784_progo-xti` compares fourteen-day signed-value averages of the two
  Williams flows, trades crosses on any D1 bar, and exits on opposite cross or
  time. This card compares the separate strict signs of two five-session log
  sums on an exact completed-week/next-Monday clock and exits Friday.
- `QM5_41022_wti-wdual-mom` splits a close-to-close prior week into disjoint
  early and late temporal segments. This card decomposes every session in the
  prior week by information time: close-to-open versus open-to-close.
- `QM5_41019_wti-wopen-mom` observes the current week's opening segment,
  enters Wednesday from that one sign, and exits Friday. This card observes a
  fully completed prior week, requires two-component agreement, and enters
  Monday.
- `QM5_13049_xti-1w-mom-vol` uses a five-D1 return threshold and a rolling
  realized-volatility percentile. This card has no magnitude or volatility
  gate and remains flat unless both price-flow components agree.
- `QM5_41028_wti-mgap-fade` fades one cross-month close-to-open gap for one
  session. This card follows agreement across ten prior-week components.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback across
  commodity carriers, not this exact-clock WTI decomposition.

Verdict:
`CLEAN_WTI_WEEKLY_OVERNIGHT_SESSION_FLOW_AGREEMENT_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Host and target: exact `XTIUSD.DWX`.
- Timeframe: D1; magic slot 0; magic `410290000`.
- Decision: first executable tick of an eligible broker Monday.
- Signal: same strict sign for the completed prior week's close-to-open and
  open-to-close log-return sums.
- Normal exit: framework Friday close at broker hour 21.
- Expected cadence: approximately 15-30 completed positions/year after
  agreement and holiday exclusions.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Rules

The rules below are the complete authorized baseline. No magnitude,
volatility, month, event, curve, volume, oscillator, range, breakout,
line-crossover, or external-data signal filter is authorized.

## 4. Entry Rules

1. Evaluate the entry path only on a new `XTIUSD.DWX` D1 bar.
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
   durable attempt exists, persist it before history validation, return
   calculation, news, spread, quote, ATR, sizing, or order gates. Never retry
   the Monday.
7. Compute elapsed time since executable session open as broker time minus the
   raw D1 label modulo one day. If elapsed time is negative or greater than
   180 minutes, consume the attempt flat and never backfill after restart.
8. For completed shifts 5 through 1, require positive finite `Open[shift]`,
   `Close[shift]`, and `Close[shift+1]`.
9. Compute
   `overnight_flow = sum(shift=5..1, log(Open[shift]/Close[shift+1]))` and
   `session_flow = sum(shift=5..1, log(Close[shift]/Open[shift]))`. The current
   Monday price enters neither sum.
10. BUY only when both sums are strictly positive. SELL only when both are
    strictly negative. Exact zero, invalid arithmetic, or disagreement
    consumes the week flat.
11. Require a valid completed-bar `ATR(20,D1)` and place one frozen hard stop
    at `3.0 * ATR`. Use no take-profit.
12. Require no owned position, a valid positive quote, and no genuinely
    positive spread wider than 1,500 points. A zero modeled `.DWX` spread is
    valid.
13. Use magic slot 0 only. Signal magnitude never scales risk. No pending
    order, second entry, scale-in, grid, martingale, or pyramid exists.

## 5. Exit Rules

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

## 6. Filters (No-Trade Module)

- Exact chart symbol: `XTIUSD.DWX`; exact period: D1.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes are OFF because the signal uses native completed prices and
  the fixed weekly lifecycle must not be altered by an event mode.
- Friday close is ON at broker hour 21 and is load-bearing.
- Entry spread must be finite and no greater than 1,500 points when genuinely
  positive; modeled zero spread is accepted.
- History, label normalization, weekday continuity, opening grace, quote,
  ATR, and risk sizing must all be valid.
- Failure at any fallible gate after attempt persistence consumes the current
  Monday. No same-week retry is allowed.

## 7. Trade Management Rules

- Own at most one `XTIUSD.DWX` position under magic `410290000`.
- Freeze the original broker hard stop; never widen, trail, or remove it.
- Run malformed/stale ownership repair on every tick before entry-only logic.
- Do not add to, pyramid, grid, hedge, partially close, or reverse an owned
  position.
- Persist the last attempted broker-Monday key in terminal global state so a
  restart cannot create a second weekly attempt.
- Recover entry timing from the owned position/deal record; never infer a new
  entry after attachment.

## Risk

- Backtest mode only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Risk budget applies to the one WTI position and is sized from the frozen
  stop distance through the V5 risk helper.
- Baseline stop: `3.0 * ATR(20,D1)` from completed data.
- No take-profit and no signal-magnitude sizing.
- Invalid stop distance, tick value, tick size, volume step, minimum volume,
  or computed lot size consumes the week without an order.
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

No parameter sweep, after-result threshold change, weekday substitution,
component resize, or lifecycle rescue is authorized by this card.

## Data Requirements

- Native `XTIUSD.DWX` D1 OHLC and tick timestamps from the registered factory
  history route.
- Native broker clock, symbol quote/properties, position state, deal history,
  and terminal global variables.
- No external market-data API, futures curve, COT positioning, EIA series,
  analyst forecast, CSV feed, or manually maintained event calendar.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact symbol/period, attempt, history, component sums, agreement, spread, ATR, sizing | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed and stale ownership repair | Trade Management | `Strategy_ManageOpenPosition` |
| Friday lifecycle | Trade Close | `Strategy_ExitSignal` returns false; framework Friday close owns the ordinary exit |
| kill switch, session ownership, risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | `Strategy_NewsFilterHook` returns false; both modes OFF |

## Kill Criteria

Retire rather than tune when any of the following occurs:

- fewer than five completed positions per full post-warm-up year at Q02;
- zero trades or nonpositive governed economics;
- a trade on a non-Monday entry clock or after the 180-minute grace;
- a holiday-shifted or nonconsecutive weekday sequence;
- current-bar price leakage into either component sum;
- entry when the two completed component signs disagree or equal zero;
- more than one attempt for an exact broker Monday;
- survival past the governed Friday/stale lifecycle without repair;
- wrong risk mode, nondeterministic result, or registry/magic mismatch.

No weak result may be rescued by dropping the agreement gate, changing
component endpoints, adding a volatility or magnitude filter, moving the
entry clock, or disabling Friday close.

## Validation Plan

Q01 must prove:

1. synthetic weekday sequences accept only exact prior Monday-through-Friday
   history plus the preceding Friday anchor and reject holiday gaps;
2. overnight-only, session-only, disagreement, equality, and invalid-price
   states remain flat unless both sums share one strict sign;
3. signal arithmetic uses all ten intended completed endpoints and excludes
   the current Monday bar;
4. the persistent attempt prevents same-Monday retry after every downstream
   failure and restart;
5. sizing uses fixed-dollar risk and the frozen completed-bar ATR stop;
6. Friday and stale repair paths remain reachable independently of entry
   gates;
7. strict compile, card lint, build checks, setfile schema, magic resolver,
   and static P1 validation pass.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-16 | initial WTI weekly flow-agreement extraction | G0 | APPROVED |
| v1-build | 2026-08-16 | deterministic V5 implementation and strict validation | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-16 | APPROVED | `decisions/2026-08-16_wti_weekly_flow_agreement_g0.md` |
| Q01 Build Validation | 2026-08-16 | PASS | `D:/QM/reports/framework/21/build_check_20260816_191153.json` |
| Q02 Baseline Screening | - | NOT_ENQUEUED | - |

## Safety Boundary

This card authorizes a non-live build, Q01 validation, one D1 backtest setfile,
and one paced Q02 enqueue. It does not authorize a manual backtest, tester
control, live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`, a
deploy or T_Live manifest, portfolio-gate change, portfolio admission, or
correlation waiver.
