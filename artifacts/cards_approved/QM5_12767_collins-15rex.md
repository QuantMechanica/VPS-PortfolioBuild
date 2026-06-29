---
ea_id: QM5_12767
slug: collins-15rex
type: strategy
strategy_id: SRC08_S03
source_id: SRC08
source_citation: "Collins, Art. Beating the Financial Futures Market: Combining Small Biases into Powerful Money Making Strategies. John Wiley & Sons, 2006, Chapter 25 and Appendix Table 25.4."
sources:
  - "[[sources/SRC08]]"
concepts:
  - "[[concepts/daily-range-expansion]]"
  - "[[concepts/volatility-expansion-continuation]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [volatility-expansion, range-breakout, trend-filter-ma, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12767_XTI_COLLINS_15REX_D1
period: D1
expected_trade_frequency: "D1 WTI 1.5x prior-range stop-entry under SMA(25) regime gate; estimate 12-24 trades/year after spread, range-sanity, news, and framework filters."
expected_trades_per_year_per_symbol: 18
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-29
expected_pf: 1.12
expected_dd_pct: 20.0
g0_approval_reasoning: "R1 PASS OWNER-approved Collins/Wiley book source; R2 PASS deterministic D1 SMA(25) gate, 1.5x prior-range stop entries, opposite hard stop, and max-hold exit; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
---

# Collins 1.5 Daily Range Expansion - WTI

## Source

- Source: [[sources/SRC08]]
- Primary citation: Art Collins, *Beating the Financial Futures Market:
  Combining Small Biases into Powerful Money Making Strategies*, John Wiley &
  Sons, 2006, Chapter 25 and Appendix Table 25.4.
- Local source path recorded in `strategy-seeds/sources/SRC08/source.md`.
- Short source anchor: "Table 25.4 1.5 Daily Range Expansion" (Appendix
  Table 25.4).

## Concept

Collins' 1.5 daily range expansion system is a structural continuation rule.
When the prior daily close is above a medium-term average, the next session
must expand far enough above its open before a long position is entered. When
the prior close is below the average, the next session must expand far enough
below its open before a short position is entered. The opposite side of the
same range-expansion band supplies the hard protective stop.

This card narrows the research draft to `XTIUSD.DWX` to add a crude-oil sleeve
that differs from the current index, gold, and natural-gas book.

This is deliberately different from:

- `QM5_12763_wti-ref-sqz-brk`: May-July refinery-utilization ramp,
  ATR-compression, rising trend, and channel-breakout long-only logic.
- `QM5_12757_abraham-xti-pb`: Abraham-style trend pullback logic.
- WTI EIA, hurricane, OPEC, futures-roll, inventory, refinery, expiry, and
  month-of-year sleeves: this card has no event, policy, roll, curve, or
  calendar trigger.
- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator, short-horizon pullback,
  adaptive PnL fitting, ML, grid, or martingale logic.
- XAU/XAG ratio or metal-only cards: this card is single-symbol WTI exposure.

## Markets And Timeframe

- Target symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: 18 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no external data,
  no CSV, no API, no futures curve, and no discretionary source feed.

## Entry Rules

- Evaluate only on a new D1 bar.
- Cancel unfilled same-magic stop orders before placing the next D1 order.
- Use the prior completed D1 bar:
  - `prior_range = high[1] - low[1]`.
  - `ma = SMA(close, strategy_sma_period)`.
- Skip if an open `XTIUSD.DWX` position already exists for this EA magic.
- Skip if spread exceeds `strategy_max_spread_points`.
- Skip if prior range is invalid, too small for broker stop distance, or above
  `strategy_abnormal_range_atr_cap * ATR(strategy_atr_period)`.
- Long setup: if `close[1] > ma[1]`, place a buy stop at current D1 open plus
  `strategy_range_mult * prior_range`.
- Short setup: if `close[1] < ma[1]`, place a sell stop at current D1 open minus
  `strategy_range_mult * prior_range`.
- No setup if the prior close equals the moving average.
- Pending stop entries expire after `strategy_pending_expiry_hours`.

## Exit Rules

- Long protective stop: current D1 open minus
  `strategy_range_mult * prior_range`.
- Short protective stop: current D1 open plus
  `strategy_range_mult * prior_range`.
- Close any open position after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.
- No take-profit, trailing stop, partial close, or reversal add in the baseline.

## Filters

- Host chart must be `XTIUSD.DWX` on D1.
- Magic slot must be 0.
- Parameter guard rejects non-positive range, SMA, ATR, expiry, and max-hold
  settings.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- One open position per magic/symbol.
- Unfilled pending orders are repriced once per new D1 bar.

## Parameters To Test

- name: strategy_range_mult
  default: 1.5
  sweep_range: [1.0, 1.25, 1.5, 2.0]
- name: strategy_sma_period
  default: 25
  sweep_range: [20, 25, 40, 50]
- name: strategy_atr_period
  default: 14
  sweep_range: [10, 14, 20]
- name: strategy_abnormal_range_atr_cap
  default: 5.0
  sweep_range: [3.0, 5.0, 8.0]
- name: strategy_pending_expiry_hours
  default: 24
  sweep_range: [18, 24, 30]
- name: strategy_max_hold_days
  default: 10
  sweep_range: [5, 10, 20]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]
- name: strategy_min_stop_points
  default: 10
  sweep_range: [5, 10, 20]

## Author Claims

Collins provides the published formula lineage for the 1.5 daily range
expansion system. The QM card does not import a performance claim into
validation; the edge must be tested by the Q02+ pipeline on Darwinex
`XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.12
- expected_dd_pct: 20
- expected_trade_frequency: 18 trades/year on D1.
- risk_class: medium-high for crude-oil volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: OWNER-approved Collins/Wiley book source.
- [x] R2 mechanical: fixed D1 SMA regime gate, prior-range stop entries,
  opposite hard stop, pending expiry, and time exit.
- [x] R3 testable: `XTIUSD.DWX` exists in the Darwinex symbol universe used by
  the framework.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  and one position per magic.
- [x] Non-duplicate: structural range-expansion stop-entry logic, not existing
  WTI event, roll, calendar, refinery, pullback, or RSI commodity logic.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, slot guard, parameter guard, spread cap,
  range sanity, broker-distance guard, and news blackout.
- trade_entry: SMA(25) regime gate plus next-open +/- 1.5 prior-range stop
  entry.
- trade_management: pending-order expiry/reprice plus one-position enforcement.
- trade_close: opposite-side hard stop and deterministic max-hold exit.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-29 | promoted SRC08_S03 for WTI commodity sleeve build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-29 | APPROVED | `artifacts/cards_approved/QM5_12767_collins-15rex.md` |
| P1 Build Validation | TBD | TBD | TBD |
| Q02 Baseline Screening | TBD | QUEUED_AFTER_BUILD | TBD |
