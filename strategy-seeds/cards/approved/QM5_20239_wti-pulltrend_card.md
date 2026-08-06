---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-PULLTREND-2026_S01
variant_id: MOP-WTI-PULLTREND-2026_S01
source_id: MOP-TSMOM-2012
ea_id: QM5_20239
slug: wti-pulltrend
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20239_wti-pulltrend_card.md
execution_contract_status: DRAFT
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
g0_status: APPROVED
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "Complete 23-page published paper; DOI https://doi.org/10.1016/j.jfineco.2011.11.003; governed packet strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: primary_trend_and_cadence
strategy_mechanic: monthly-wti-12m-pre-pullback-trend-following-after-opposite-1m-return
sources:
  - "[[sources/MOP-TSMOM-2012]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/trend-pullback-entry]]"
indicators:
  - "[[indicators/rolling-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, time-series-momentum, pullback-entry, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 202390000
period: D1
timeframe: D1
expected_trade_frequency: "Estimated 5-8 completed monthly WTI packages/year after fourteen consecutive completed month ends; Q02 must prove or retire density."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: NOT_STARTED
review_focus: "Falsify a direct WTI trend-pullback package: a non-overlapping twelve-month trend followed by one opposite completed month, then entry in the older trend direction. Q09 alone may establish realized decorrelation from XAU/SP500/NDX/XNG."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [consecutive_completed_months, nonoverlapping_intervals, opposite_sign_gate, trend_direction, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-06_qm5_20239_wti_pulltrend_g0.md: R1 complete peer-reviewed JFE paper packet with WTI in the source universe; R2 locked fourteen-month-end reconstruction, non-overlapping prior 12-month trend and newest one-month pullback, strict opposite-sign gate, trend-direction entry, persisted monthly attempt, ATR stop, monthly rollover, and stale exit; R3 registered XTIUSD.DWX D1 history; R4 deterministic native price arithmetic only. Deterministic dedup scanned 4,296 registry rows and 412 canonical cards with CLEAN exact/fuzzy result; manual mechanic review is clean. The pullback conjunction is a QM hypothesis and no source efficacy transfers."
---

# QM5_20239 WTI Pre-Pullback Trend

## Hypothesis

Slow WTI trends can reflect persistent supply, investment, hedging, inventory,
and risk-premium regimes. A single completed month against an established
trend may provide a lower-overlap entry clock than renewing a pure trend
position every month. This card therefore enters in a completed twelve-month
WTI trend only after the immediately following completed month moves the other
way.

The candidate creates direct crude-oil exposure distinct from the certified
XAU, SP500, NDX, and XNG book. It does not claim that crude exposure is
decorrelated, profitable, or suitable for the portfolio. Q02 owns density and
economics; unchanged Q09 alone may measure realized overlap after survival.

## Source Traceability And Claim Boundary

The governed packet is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`. It records a complete read
of Moskowitz, Ooi, and Pedersen (2012), a peer-reviewed *Journal of Financial
Economics* article, and identifies WTI as an explicit source commodity. The
paper supplies the own-return trend object and monthly formation/holding
cadence.

The paper does not test the card's non-overlapping newest-month counter-move
gate. That conjunction, the Darwinex continuous CFD, exact broker-month
reconstruction, fixed dollar risk, ATR hard stop, spread cap, and restart
ledger are transparent QM hypotheses. No source performance, volatility,
trade-count, cost, drawdown, or correlation statistic is imported.

## Non-Duplicate Decision

The canonical checker scanned 4,296 EA-registry rows and 412 cards and
returned `CLEAN`, with no exact identity and no fuzzy match above threshold.
Manual review resolves the nearest strategies:

- Pure WTI time-series-momentum EAs use one-, two-, three-, six-, nine-, or
  twelve-month return direction without requiring a separate adverse month.
  This card blocks when the newest month agrees with the old trend.
- `QM5_20229_wti-seas-rev1` and `QM5_20137_wti-seas-pb` enter a seasonal
  direction after an opposing month; this card has no seasonal state and
  derives direction solely from a preceding non-overlapping WTI trend.
- `QM5_12757_abraham-xti-pb` requires a D1 channel breakout and boundary
  retest, not completed monthly return intervals.
- WTI weekday, day-of-month, event, range, pure reversal, and oil/gas systems
  use different clocks and information objects.
- `QM5_12567_cum-rsi2-commodity` is an XNG short-horizon oscillator pullback.

The fourteen consecutive endpoints, exact twelve-month interval ending before
the newest month, separate one-month return, opposite-sign conjunction,
trend-following direction, and one consumed monthly attempt are jointly
load-bearing. Verdict: `CLEAN_AFTER_DETERMINISTIC_AND_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1.
- Magic slot: 0; allocated magic `202390000`.
- Decision clock: first processed D1 bar of each genuine broker-month
  transition.
- Formation: fourteen consecutive completed broker-month endpoints.
- Expected cadence: 5-8 completed packages/year after warm-up; retire below
  five per full post-warm-up year.
- Runtime data: native MT5 D1 time/close, ATR, spread, quotes, positions,
  deals, broker calendar, and contract metadata only.

## Formula

At the start of broker month `t`, define completed month-end closes in reverse
chronological order:

```text
M0  = close at the end of month t-1
M1  = close at the end of month t-2
M13 = close at the end of month t-14

older_trend = ln(M1 / M13)   // exact 12 completed months
pullback    = ln(M0 / M1)    // separate newest completed month
```

- `older_trend > 0` and `pullback < 0`: BUY WTI.
- `older_trend < 0` and `pullback > 0`: SELL WTI.
- Equal signs, exact zero, missing/nonconsecutive endpoints, nonpositive
  closes, or invalid arithmetic remain flat for the consumed month.

The intervals share only endpoint `M1` and have no overlapping returns.

## Rules

The rules below are the complete authorized Q02 baseline. Signal parameters
are locked; no direction, threshold, horizon, carrier, calendar, or retry
sweep is authorized.

## 4. Entry Rules

1. Require exact EA ID `20239`, `XTIUSD.DWX` D1, magic slot 0, and every
   baseline input locked to its declared value.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine broker-month transition.
3. Persist the current month as consumed before history, signal, spread,
   quote, news, stop, sizing, or order gates. A flat, rejected, failed,
   stopped, or blocked attempt cannot retry during that month.
4. Reject an owned position or any same-month entry deal for the magic.
5. Reconstruct exactly fourteen consecutive completed month-end closes from a
   bounded D1 buffer and require the newest endpoint to belong to the month
   immediately preceding the current month.
6. Calculate the two non-overlapping returns exactly as specified. BUY only
   after a positive older trend and negative pullback; SELL only after a
   negative older trend and positive pullback.
7. Require spread in `[0,1500]` points, a valid executable quote, completed
   `ATR(20,D1)`, valid stop geometry, and valid V5 fixed-risk sizing.
8. Open at most one market position with a frozen `3.5 * ATR(20,D1)` hard
   stop and no take-profit.

## 5. Exit Rules

1. Close the prior position on the first processed D1 bar of every new broker
   month before considering replacement risk.
2. Close after forty elapsed calendar days as a stale guard.
3. Close an unexpected wrong-side or wrong-symbol owned position immediately.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source cadence holds through weekends.
6. No intramonth signal reversal, target, trail, break-even, partial close,
   scale-in, grid, martingale, or pyramid is authorized.

## 6. Filters (No-Trade Module)

- Fail closed for wrong symbol, timeframe, EA ID, slot, unlocked input,
  invalid month key, non-boundary bar, consumed attempt, owned exposure,
  same-month entry history, missing or nonconsecutive endpoints, nonpositive
  close, invalid logarithm, non-opposite signs, excessive spread, invalid
  quote, unavailable ATR, or invalid stop.
- Both news axes are locked OFF for the native-price baseline. Lifecycle exits
  are processed before entry-only gates.
- Runtime may not read a futures curve, inventory release, volume, open
  interest, file, API, analyst input, trained output, or portfolio result.

## 7. Trade Management Rules

- Preserve the original broker stop; do not move it.
- Close older-month, wrong-side, wrong-symbol, or forty-day-stale exposure
  before evaluating a new entry.
- Maintain at most one position and one consumed attempt per broker month.
  Restart recovery combines a persistent marker with owned position and deal
  history; a future-dated tester marker is deleted at initialization.
- No randomness, adaptive fit, external state, grid, martingale, partial
  close, scale-in, or pyramiding.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_trend_months` | 12 | [12] | older non-overlapping trend interval |
| `strategy_pullback_months` | 1 | [1] | newest completed counter-move interval |
| `strategy_history_bars` | 500 | [500] | bounded D1 month-end reconstruction |
| `strategy_atr_period` | 20 | [20] | completed D1 risk estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

## Author Claims

The source documents time-series momentum across liquid futures and identifies
WTI in its commodity universe. It does not claim that the newest-month
counter-move improves WTI entries, that a continuous CFD reproduces futures,
or that this card diversifies the QM book. Q02 and later gates are the only
strategy evidence.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: WTI gaps and roll/basis effects can dominate
a slow signal; the skipped newest month may mark a real reversal rather than a
pullback; monthly packages carry weekend and financing risk; stop-outs reduce
density; and direct crude exposure may correlate with the incumbent book.

## Kill Criteria

- Retire on zero trades or fewer than five completed packages per full
  post-warm-up year.
- Fail on a nonconsecutive endpoint, overlapping interval, wrong sign,
  wrong-side entry, repeat monthly attempt, hold beyond forty days, missing
  hard stop, invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing trend or pullback horizons, signs,
  direction, thresholds, carrier, entry clock, stop, hold, spread cap, or
  retry policy.

## Strategy Allowability Check

- [x] R1: peer-reviewed named-author JFE source with DOI, complete-paper read,
  durable retrieval hash, and explicit WTI source membership.
- [x] R2: fixed completed-month endpoints, non-overlapping intervals, strict
  sign conjunction, persisted attempt, hard stop, rollover, and stale exit.
- [x] R3: registered `XTIUSD.DWX` D1 and native V5 execution state only.
- [x] R4: deterministic logarithm/calendar/ATR arithmetic; no prohibited
  trained model, banned indicator, external feed, grid, or martingale.
- [x] Dedup: deterministic CLEAN plus manual neighbor resolution.

## Framework Alignment

- no_trade: exact host/D1/EA/slot, locked input, news/Friday contract, and
  cheap parameter guards.
- trade_entry: monthly attempt persistence, fourteen endpoint reconstruction,
  two return signs, spread/quote/ATR/stop checks, and one market order.
- trade_management: older-month, wrong-side, wrong-symbol, and stale exits
  before entry-only gates.
- trade_close: broker hard stop, framework kill switch, and deterministic
  management closes.

## Safety Boundary

This card authorizes only research, build, strict compile, and non-live paced
pipeline handoff. It does not authorize a manual backtest; live, demo, shadow,
optimization, or stress setfile; AutoTrading; `T_Live`; deploy or T_Live
manifest; portfolio admission; portfolio-gate edit; or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-06 | initial source-bounded WTI pre-pullback trend card and strict build | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-06 | APPROVED | `decisions/2026-08-06_qm5_20239_wti_pulltrend_g0.md` |
| Q01 Build Validation | 2026-08-06 | PASS | strict compile/build: 0 errors, warnings, failures, or build warnings |
| Q02 Baseline Screening | - | NOT_STARTED | - |
