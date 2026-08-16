---
card_schema_version: 2
type: strategy
strategy_id: MOP-ZHAO-WTI-WDUAL-MOM-2026_S01
variant_id: MOP-ZHAO-WTI-WDUAL-MOM-2026_S01
source_id: MOP-ZHAO-WTI-WDUAL-MOM-2026
ea_id: QM5_41022
slug: wti-wdual-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41022_wti-wdual-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-16
created_by: Research+Development
last_updated: 2026-08-16
g0_status: APPROVED
g0_decision: decisions/2026-08-16_wti_week_dual_momentum_g0.md
source_approval: decisions/2026-08-16_wti_week_dual_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Shen Zhao; Yiyi Ding; Jianfeng Yu; Wenjin Kang"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Shen Zhao; Yiyi Ding; Jianfeng Yu; Wenjin Kang"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250; Zhao, Ding, Yu, and Kang (2026), Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity Markets, SSRN 6425598."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence and retrieval hash in strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: own_return_sign_continuation_family_and_explicit_wti_membership
  - type: academic_working_paper
    citation: "Zhao, S., Ding, Y., Yu, J., and Kang, W. (2026). Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity Markets."
    location: "SSRN 6425598; DOI 10.2139/ssrn.6425598; bounded accessible-material review in strategy-seeds/sources/28681f5d-aa78-584e-9698-750d1402e485/source.md"
    quality_tier: B
    role: bounded_weekly_commodity_continuation_context
strategy_mechanic: exact-prior-full-week-disjoint-opening-and-closing-segment-return-sign-agreement-entry-on-monday-with-friday-close
sources:
  - "[[sources/MOP-ZHAO-WTI-WDUAL-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/split-week-agreement]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/closed-price-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, time-series-momentum, split-week-agreement, weekly-entry, friday-close, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410220000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 20-35 completed WTI positions per full post-warm-up year after strict split-week sign agreement and holiday exclusions; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 28
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_HORIZON_AND_ACCESS_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING
q02_status: NOT_STARTED
review_focus: "Falsify an exact-calendar WTI split-week continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify the six-bar weekday sequence, disjoint opening/closing endpoints, strict agreement, no late or repeated Monday entry, and Friday flattening; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_weekday_sequence, disjoint_completed_price_endpoints, strict_dual_sign_agreement, monday_decision_clock, weekly_attempt_state, no_late_restart_entry, risk_mode_dual, friday_close_enabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 peer-reviewed complete-read WTI continuation lineage plus bounded weekly commodity context with disclosed access and split-week translation risks; R2 exact sequence, endpoints, agreement, timing, retry and lifecycle rules; R3 native XTI D1 only; R4 deterministic arithmetic without banned signal or trained logic; canonical dedup found only expected weekly family neighbors and manual review fixed their material boundaries."
---

# WTI Split-Week Dual-Segment Momentum

## Hypothesis

A WTI move that persists through both disjoint halves of a completed broker
week may carry into the following week more reliably than a move confined to
one half. The candidate measures the prior week's Friday-to-Tuesday opening
segment and Tuesday-to-Friday closing segment, enters on the following Monday
only when both signs agree, and closes by Friday.

This is a falsifiable short-horizon and calendar translation. The sources do
not test this exact split-week agreement state, fixed Monday clock, WTI-only
continuous CFD, Friday lifecycle, or the QM portfolio.

## Source Traceability And Claim Boundary

The sole governed composite packet is
`strategy-seeds/sources/MOP-ZHAO-WTI-WDUAL-MOM-2026/source.md`, approved before
card extraction in
`decisions/2026-08-16_wti_week_dual_momentum_source_approval.md` at commit
`354986d94`.

Moskowitz, Ooi, and Pedersen supply the own-completed-return-sign continuation
family and WTI membership in their commodity-futures universe. Their paper
uses rolled futures excess returns, monthly horizons, volatility scaling, and
diversified portfolios. Zhao, Ding, Yu, and Kang supply bounded accessible
context that a residual component of weekly commodity returns predicts the
next week positively; their full text was inaccessible and their actual
method uses investor-position information unavailable to this EA.

The exact six-bar sequence, two disjoint price-only returns, strict agreement
gate, broker-calendar normalization, Monday opening grace, continuous-CFD
carrier, Friday close, hard stop, fixed-dollar risk, spread cap, and attempt
ledger are disclosed QM choices. No source return, alpha, coefficient,
significance, trade density, drawdown, cost, CFD equivalence, decorrelation,
or portfolio result transfers.

## Non-Duplicate Decision

The deterministic pre-allocation checker scanned 4,509 EA-registry rows and
605 root-card files. It found no exact match and raised two expected fuzzy
family matches. Manual review fixes the load-bearing boundaries:

- `QM5_41019_wti-wopen-mom` observes the current week's opening segment,
  enters Wednesday from that one sign, and exits Friday. This card observes
  the completed prior week's two segments, requires agreement, and enters the
  next Monday.
- `QM5_41020_wti-wclose-mom` observes only the prior closing segment, enters
  Monday, and exits Wednesday. This card additionally requires the disjoint
  prior opening segment to agree and holds through Friday.
- `QM5_41021_wti-mdual-mom` combines a complete broker month with its nested
  final five sessions and owns the next month's first five sessions. This
  card uses two disjoint within-week returns and an exact weekday sequence.
- `QM5_13049_xti-1w-mom-vol` uses a rolling five-D1 magnitude threshold,
  realized-volatility rank, any-new-day timing, and reversal/time exits. This
  card is exact-calendar, sign-only, and contains no magnitude or volatility
  filter.
- `QM5_21521_wti-flow-switch` uses tick-volume tails to choose continuation
  or reversal. This card reads no volume and stays flat on sign disagreement.
- `QM5_12965_wti-week-orb`, `QM5_13075_xti-inweek-brk`, and related weekly-
  range EAs trade highs, lows, levels, and breakout geometry. This card uses
  completed closes only and never creates a breakout level.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback across
  commodity carriers. This card is an exact-clock WTI continuation package
  without an oscillator or cross-carrier allocator.

Verdict:
`CLEAN_WTI_DISJOINT_SPLIT_WEEK_AGREEMENT_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Host and target: exact `XTIUSD.DWX`.
- Timeframe: D1; magic slot 0; magic `410220000`.
- Decision: first executable tick of an eligible broker Monday.
- Signal: same strict sign for the completed prior week's opening and closing
  segments.
- Normal exit: framework Friday close at broker hour 21.
- Expected cadence: approximately 20-35 completed positions/year after
  agreement and holiday exclusions.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Rules

The rules below are the complete authorized baseline. No magnitude,
volatility, month, event, curve, volume, oscillator, range, breakout, or
external-data signal filter is authorized.

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
7. Compute elapsed time since the executable session open as broker time
   minus the raw D1 label modulo one day. If elapsed time is negative or
   greater than 180 minutes, consume the attempt flat and never backfill the
   week after a late restart.
8. Require positive finite closes at the preceding Friday, prior Tuesday,
   and prior Friday endpoints. Intervening Monday, Wednesday, and Thursday
   closes prove continuity but do not enter either return.
9. Compute
   `opening_return = log(PriorTuesdayClose / PrecedingFridayClose)` and
   `closing_return = log(PriorFridayClose / PriorTuesdayClose)`. The current
   Monday price enters neither return.
10. BUY only when both returns are strictly positive. SELL only when both are
    strictly negative. Exact zero, invalid arithmetic, or disagreement
    consumes the week flat.
11. Require a valid `ATR(20,D1)` from completed bars and place one frozen hard
    stop at `3.5 * ATR`. Use no take-profit.
12. Require no owned position, a valid positive quote, and no genuinely
    positive spread wider than 1,500 points. A zero modeled `.DWX` spread is
    valid.
13. Use magic slot 0 only. Signal magnitude never scales risk. No pending
    order, second entry, scale-in, grid, martingale, or pyramid exists.

## 5. Exit Rules

1. Framework Friday close is enabled and closes owned exposure at broker
   hour 21. Trade management and close logic remain reachable before every
   entry-only gate.
2. Close exposure that survives into a later broker week at its first
   observable D1 boundary. This is stale repair, not the ordinary exit.
3. Close after seven elapsed calendar days as a final stale guard.
4. Close owned exposure with invalid open time, volume, price, symbol, magic,
   or direction.
5. The frozen broker hard stop and framework kill switch remain
   authoritative.
6. No target, opposite-signal exit, trailing stop, break-even move, partial
   exit, discretionary close, or Friday-close override is authorized.

## 6. Filters (No-Trade Module)

- Exact chart symbol: `XTIUSD.DWX`; exact period: D1.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes are OFF because the signal uses only native completed prices
  and the fixed weekly lifecycle must not be altered by an event mode.
- Friday close is ON at broker hour 21 and is load-bearing.
- Entry spread must be finite and no greater than 1,500 points when genuinely
  positive; modeled zero spread is accepted.
- History, label normalization, weekday continuity, opening grace, quote,
  ATR, and risk sizing must all be valid.
- Failure at any fallible gate after attempt persistence consumes the current
  Monday. No same-week retry is allowed.

## 7. Trade Management Rules

- Own at most one `XTIUSD.DWX` position under magic `410220000`.
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
- Baseline stop: `3.5 * ATR(20,D1)` from completed data.
- No take-profit and no signal-magnitude sizing.
- Invalid stop distance, tick value, tick size, volume step, minimum volume,
  or computed lot size consumes the week without an order.
- This card creates no live, demo, shadow, stress, or optimization preset.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_atr_period` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_spread_points` | 1500 | entry cost guard |
| `strategy_entry_grace_minutes` | 180 | restart-safe Monday boundary |
| `strategy_max_hold_days` | 7 | stale repair only |
| `friday_close_enabled` | true | ordinary weekly exit |
| `friday_close_hour_broker` | 21 | ordinary exit clock |

No parameter sweep, after-result threshold change, weekday substitution,
segment resize, or lifecycle rescue is authorized by this card.

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
| exact symbol/period, attempt, history, agreement, spread, ATR, sizing | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed and stale ownership repair | Trade Management | `Strategy_ManageOpenPosition` |
| Friday/stale/time lifecycle | Trade Close | `Strategy_ExitSignal` and framework Friday close |
| kill switch, session ownership, risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | `Strategy_NewsFilterHook` returns true; both modes OFF |

## Kill Criteria

Retire rather than tune when any of the following occurs:

- fewer than five completed positions per full post-warm-up year at Q02;
- zero trades or nonpositive governed economics;
- a trade on a non-Monday entry clock or after the 180-minute grace;
- a holiday-shifted or nonconsecutive weekday sequence;
- current-bar price leakage into either signal;
- entry when the two completed segment signs disagree or equal zero;
- more than one attempt for an exact broker Monday;
- survival past the governed Friday/stale lifecycle without repair;
- wrong risk mode, nondeterministic result, or registry/magic mismatch.

No weak result may be rescued by dropping the agreement gate, changing
segment endpoints, adding a volatility or magnitude filter, moving the entry
clock, or disabling Friday close.

## Validation Plan

Q01 must prove:

1. synthetic weekday sequences accept only exact Friday-through-Friday
   history and reject holiday gaps;
2. opening-only, closing-only, disagreement, equality, and invalid-price
   states remain flat unless both signs agree;
3. signal arithmetic excludes the current Monday bar;
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
| v1 | 2026-08-16 | initial split-week dual-segment WTI extraction | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-16 | APPROVED | `decisions/2026-08-16_wti_week_dual_momentum_g0.md` |
| Q01 Build Validation | pending | NOT STARTED | build only after all deterministic prerequisites pass |
| Q02 Baseline Screening | pending | NOT STARTED | enqueue only after strict Q01 PASS |

## Safety Boundary

This card authorizes a non-live build, Q01 validation, one D1 backtest setfile,
and one paced Q02 enqueue. It does not authorize a manual backtest, tester
control, live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`, a
deploy or T_Live manifest, portfolio-gate change, portfolio admission, or
correlation waiver.
